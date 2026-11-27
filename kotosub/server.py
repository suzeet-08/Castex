import os, re, io, time, json, base64, zipfile, hashlib, threading
from urllib.parse import unquote, quote
from collections import OrderedDict, Counter
from concurrent.futures import ThreadPoolExecutor
import requests
from bs4 import BeautifulSoup
from fastapi import FastAPI, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

app = FastAPI(title="KotoSub AI Engine for Castex")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

CACHE_DIR = "/tmp/kotosub_castex_cache"
os.makedirs(CACHE_DIR, exist_ok=True)

HDRS = {
    "User-Agent": "Mozilla/5.0 (Linux; Android 14; POCO X8 Pro) AppleWebKit/537.36 Chrome/126.0 Mobile Safari/537.36"
}
SUB_EXTS = (".srt", ".ass", ".ssa", ".vtt")

MEM_CACHE = OrderedDict()
ENG_POOL_CACHE = OrderedDict()
ADDON_MODELS = []
GROQ_MODELS_CACHE = []
MAX_MEM_ITEMS = 250

STATE_GUARD = threading.Lock()
GH_WRITE_LOCK = threading.Lock()
JOB_EVENTS = {}
JOB_STATUS = {}
JOB_TIMING = {}
IN_PROGRESS = set()

GH_REPO_CACHE = None
COLAB_STATE = {"url": "", "model": "qwen2.5:7b", "checked_at": 0.0}

STOPWORDS = {
    "this", "that", "with", "from", "they", "them", "their", "there", "these",
    "those", "have", "has", "had", "will", "would", "could", "should", "into",
    "when", "what", "where", "which", "while", "about", "after", "before",
    "episode", "part", "story", "world", "power", "magic", "chapter", "black",
    "clover", "naruto", "shippuden", "anime", "begin", "begins", "final",
}

ADDON_LANG_RULES = {
    "hi": (
        "Translate these sequential anime/movie subtitles into natural, conversational Hinglish "
        "(Hindi written in English/Roman letters only, never Devanagari script). "
        "Keep lines crisp and easy to read. Keep character, attack, and place names intact."
    ),
    "bg": (
        "Translate these sequential anime/movie subtitles into natural, conversational Bangla script (বাংলা). "
        "Keep lines crisp and easy to read. Keep character, attack, and place names natural."
    ),
    "bn": (
        "Translate these sequential anime/movie subtitles into natural, conversational Banglish "
        "(Bengali written in English/Roman letters only, Kolkata tone, never Bengali script). "
        "Keep lines crisp and easy to read. Keep character, attack, and place names intact."
    ),
}


class DirectTranslateRequest(BaseModel):
    srt_content: str
    lang: str = "hi"
    stream_hash: str = ""


def decode_bytes(raw: bytes) -> str:
    if not raw:
        return ""
    for enc in ("utf-8-sig", "utf-8", "cp1252", "latin-1"):
        try:
            return raw.decode(enc)
        except Exception:
            continue
    return raw.decode("utf-8", errors="replace")


def clean_subtitle(filename: str, raw_bytes: bytes) -> bytes:
    text = decode_bytes(raw_bytes).lstrip("\ufeff").replace("\r\n", "\n").replace("\r", "\n")
    text = re.sub(r"<[^>]+>", "", text)
    text = re.sub(r"\{[^}]*\}", "", text)
    return text.encode("utf-8")


def wrap_line(text: str, width: int = 42) -> str:
    lines = []
    for raw_line in text.split("\n"):
        words = raw_line.split()
        if not words:
            continue
        cur = words[0]
        for w in words[1:]:
            if len(cur) + 1 + len(w) <= width:
                cur += " " + w
            else:
                lines.append(cur)
                cur = w
        lines.append(cur)
    return "\n".join(lines[:2]) if lines else text


def find_ep(files, target_ep: int):
    if target_ep is None:
        return None
    patterns = [
        re.compile(rf"(?:s\d+e|e|ep|episode[\s._-]*)0*{target_ep}(?:\b|_|\.|v)", re.I),
        re.compile(rf"(?:\s-\s|_)0*{target_ep}(?:\b|_|\.|v)", re.I),
    ]
    for pat in patterns:
        for f in files:
            if pat.search(os.path.basename(f)):
                return f
    return None


def get_github_config():
    global GH_REPO_CACHE
    token = os.environ.get("GITHUB_TOKEN", "").strip()
    if not token:
        return "", ""
    repo = os.environ.get("GITHUB_REPO", "").strip() or GH_REPO_CACHE
    if repo:
        return token, repo
    try:
        r = requests.get(
            "https://api.github.com/user",
            headers={"Authorization": f"Bearer {token}", "Accept": "application/vnd.github+json"},
            timeout=6,
        )
        if r.status_code == 200:
            login = r.json().get("login", "").strip()
            if login:
                GH_REPO_CACHE = f"{login}/Castex"
                return token, GH_REPO_CACHE
    except Exception:
        pass
    return token, ""


def gh_read_file(path):
    token, repo = get_github_config()
    if not token or not repo:
        return None
    try:
        r = requests.get(
            f"https://api.github.com/repos/{repo}/contents/{path}",
            headers={"Authorization": f"Bearer {token}", "Accept": "application/vnd.github.raw"},
            timeout=6,
        )
        if r.status_code == 200:
            return r.content
    except Exception:
        pass
    return None


def gh_write_file(path, content_bytes, message):
    token, repo = get_github_config()
    if not token or not repo:
        return False
    api_url = f"https://api.github.com/repos/{repo}/contents/{path}"
    headers = {"Authorization": f"Bearer {token}", "Accept": "application/vnd.github+json"}
    with GH_WRITE_LOCK:
        sha = None
        try:
            gr = requests.get(api_url, headers=headers, timeout=6)
            if gr.status_code == 200:
                sha = gr.json().get("sha")
        except Exception:
            pass

        payload = {
            "message": message,
            "content": base64.b64encode(content_bytes).decode("ascii"),
        }
        if sha:
            payload["sha"] = sha
        try:
            pr = requests.put(api_url, headers=headers, json=payload, timeout=10)
            return pr.status_code in (200, 201)
        except Exception:
            return False


def get_colab_endpoint():
    now = time.time()
    if now - COLAB_STATE["checked_at"] < 20.0:
        return COLAB_STATE["url"], COLAB_STATE["model"]

    url = os.environ.get("COLAB_API_URL", "").strip().rstrip("/")
    if not url:
        raw = gh_read_file("kotosub/colab_url.txt") or gh_read_file("colab_url.txt")
        if raw:
            url = raw.decode("utf-8", errors="ignore").strip().rstrip("/")

    model = COLAB_STATE["model"] or "qwen2.5:7b"
    if url.startswith("http"):
        try:
            r = requests.get(f"{url}/api/tags", timeout=3.5)
            if r.status_code == 200:
                models = [m.get("name") for m in (r.json().get("models") or []) if m.get("name")]
                if models:
                    model = models[0]
                COLAB_STATE.update({"url": url, "model": model, "checked_at": now})
                return url, model
        except Exception:
            pass

    COLAB_STATE.update({"url": "", "model": model, "checked_at": now})
    return "", model


def get_groq_keys():
    raw = os.environ.get("GROQ_API_KEY", "")
    return [k.strip() for k in raw.split(",") if k.strip()]


def get_gemini_keys():
    raw = os.environ.get("GEMINI_API_KEY", "")
    return [k.strip() for k in raw.split(",") if k.strip()]


def cache_get(key):
    if key in MEM_CACHE:
        MEM_CACHE.move_to_end(key)
        return MEM_CACHE[key]
    fpath = os.path.join(CACHE_DIR, f"{key}.srt")
    if os.path.exists(fpath):
        with open(fpath, "rb") as f:
            data = f.read()
        if data and b"-->" in data:
            MEM_CACHE[key] = data
            return data

    gh_data = gh_read_file(f"kotosub/cache/{key}.srt")
    if gh_data and b"-->" in gh_data:
        MEM_CACHE[key] = gh_data
        if len(MEM_CACHE) > MAX_MEM_ITEMS:
            MEM_CACHE.popitem(last=False)
        try:
            with open(fpath, "wb") as f:
                f.write(gh_data)
        except Exception:
            pass
        return gh_data
    return None


def cache_put(key, data):
    if not data or b"-->" not in data:
        return
    MEM_CACHE[key] = data
    MEM_CACHE.move_to_end(key)
    if len(MEM_CACHE) > MAX_MEM_ITEMS:
        MEM_CACHE.popitem(last=False)
    try:
        with open(os.path.join(CACHE_DIR, f"{key}.srt"), "wb") as f:
            f.write(data)
    except Exception:
        pass
    threading.Thread(
        target=gh_write_file,
        args=(f"kotosub/cache/{key}.srt", data, f"kotosub cache: {key}.srt"),
        daemon=True,
    ).start()


def get_groq_models(groq_key):
    global GROQ_MODELS_CACHE
    if GROQ_MODELS_CACHE:
        return GROQ_MODELS_CACHE
    preferred = [
        "llama-3.1-8b-instant",
        "meta-llama/llama-4-scout-17b-16e-instruct",
        "llama-3.3-70b-versatile",
    ]
    try:
        r = requests.get(
            "https://api.groq.com/openai/v1/models",
            headers={"Authorization": f"Bearer {groq_key}"},
            timeout=6,
        )
        if r.status_code == 200:
            bad = ("whisper", "tts", "guard", "orpheus", "playai", "embed", "vision", "compound")
            ids = [
                m.get("id", "")
                for m in (r.json().get("data") or [])
                if m.get("id") and not any(b in m.get("id", "").lower() for b in bad)
            ]
            ordered = [m for m in preferred if m in ids]
            if ordered:
                GROQ_MODELS_CACHE = ordered
                return GROQ_MODELS_CACHE
    except Exception:
        pass
    return preferred


def get_addon_models(gemini_key):
    global ADDON_MODELS
    if ADDON_MODELS:
        return ADDON_MODELS
    try:
        r = requests.get(
            f"https://generativelanguage.googleapis.com/v1beta/models?key={gemini_key}",
            timeout=8,
        )
        if r.status_code == 200:
            bad = (
                "image", "tts", "audio", "live", "embedding", "robotics",
                "computer", "vision", "veo", "imagen", "deep-research",
                "aqa", "pro", "1.5", "2.0", "2.5",
            )
            found = [
                m.get("name", "").replace("models/", "")
                for m in (r.json().get("models") or [])
                if "generateContent" in (m.get("supportedGenerationMethods") or [])
            ]
            found = [
                n for n in found
                if n.lower().startswith("gemini-")
                and "flash" in n.lower()
                and not any(b in n.lower() for b in bad)
            ]
            if found:
                ADDON_MODELS = found[:4]
                return ADDON_MODELS
    except Exception:
        pass
    return ["gemini-flash-lite-latest", "gemini-flash-latest"]


def strip_filler_loops(lines):
    if len(lines) < 8:
        return lines
    first_tokens = []
    for l in lines:
        parts = l.strip().split(None, 1)
        if len(parts) == 2 and parts[0].endswith(("!", ",", ":")):
            first_tokens.append(parts[0].lower())
    if not first_tokens:
        return lines
    word, count = Counter(first_tokens).most_common(1)[0]
    if count >= max(4, int(len(lines) * 0.22)):
        cleaned = []
        for l in lines:
            parts = l.strip().split(None, 1)
            if len(parts) == 2 and parts[0].lower() == word:
                cleaned.append(parts[1].strip())
            else:
                cleaned.append(l)
        return cleaned
    return lines


def parse_numbered_output(txt, lines):
    mapped = {}
    for m in re.finditer(r"^\[(\d+)\]\s*(.*)$", txt, re.M):
        mapped[int(m.group(1))] = m.group(2).replace(" // ", "\n").strip()
    if len(mapped) >= max(1, len(lines) // 2):
        return strip_filler_loops([mapped.get(i) or orig for i, orig in enumerate(lines)])
    return None


def unified_ai_batch(lines, lang, prefer_alt_groq=False):
    packed = "\n".join(f"[{i}] {l.replace(chr(10), ' // ')}" for i, l in enumerate(lines))
    rule = ADDON_LANG_RULES.get(lang, ADDON_LANG_RULES["hi"])
    prompt = (
        f"{rule}\n"
        f"RULES: Translate each numbered line naturally. Keep exact [0], [1], ... prefix and ' // ' breaks. "
        f"Never start lines with repetitive fillers like 'Dhatt!'. Output ONLY numbered lines.\n\n{packed}"
    )

    errs = []

    colab_url, colab_model = get_colab_endpoint()
    if colab_url:
        try:
            r = requests.post(
                f"{colab_url}/v1/chat/completions",
                headers={"Content-Type": "application/json"},
                json={
                    "model": colab_model,
                    "temperature": 0.2,
                    "messages": [{"role": "user", "content": prompt}],
                },
                timeout=(4, 45),
            )
            if r.status_code == 200:
                txt = r.json()["choices"][0]["message"]["content"].strip()
                parsed = parse_numbered_output(txt, lines)
                if parsed:
                    return parsed
                errs.append("colab:short")
            else:
                errs.append(f"colab:{r.status_code}")
                COLAB_STATE["checked_at"] = 0.0
        except Exception:
            errs.append("colab:offline")
            COLAB_STATE["checked_at"] = 0.0

    groq_keys = get_groq_keys()
    if groq_keys:
        g_models = list(get_groq_models(groq_keys[0]))
        if prefer_alt_groq and len(g_models) > 1:
            g_models = g_models[1:] + g_models[:1]
        for ki, g_key in enumerate(groq_keys):
            for g_model in g_models:
                short_m = g_model.split("/")[-1][:12]
                try:
                    r = requests.post(
                        "https://api.groq.com/openai/v1/chat/completions",
                        headers={"Authorization": f"Bearer {g_key}", "Content-Type": "application/json"},
                        json={
                            "model": g_model,
                            "temperature": 0.2,
                            "messages": [{"role": "user", "content": prompt}],
                        },
                        timeout=(5, 15),
                    )
                    if r.status_code != 200:
                        errs.append(f"g{ki+1}({short_m}):{r.status_code}")
                        continue
                    txt = r.json()["choices"][0]["message"]["content"].strip()
                    parsed = parse_numbered_output(txt, lines)
                    if parsed:
                        return parsed
                except Exception:
                    errs.append(f"g{ki+1}({short_m}):timeout")

    gemini_keys = get_gemini_keys()
    if gemini_keys:
        models = get_addon_models(gemini_keys[0])
        for gi, gem_key in enumerate(gemini_keys):
            for model in models:
                url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={gem_key}"
                payload = {
                    "contents": [{"parts": [{"text": prompt}]}],
                    "generationConfig": {"temperature": 0.25},
                }
                try:
                    r = requests.post(url, json=payload, timeout=(5, 14))
                    if r.status_code != 200:
                        errs.append(f"gem{gi+1}:{r.status_code}")
                        continue
                    cands = r.json().get("candidates") or []
                    if not cands:
                        continue
                    parts = cands[0].get("content", {}).get("parts") or []
                    txt = "".join(p.get("text", "") for p in parts if not p.get("thought")).strip()
                    parsed = parse_numbered_output(txt, lines)
                    if parsed:
                        return parsed
                except Exception:
                    errs.append(f"gem{gi+1}:timeout")

    raise RuntimeError(" | ".join(errs[-3:]) or "No AI server active")


def ass_to_srt(raw_bytes):
    text = decode_bytes(raw_bytes).lstrip("\ufeff").replace("\r\n", "\n").replace("\r", "\n")
    events = []
    for line in text.split("\n"):
        if not line.startswith("Dialogue:"):
            continue
        parts = line.split(",", 9)
        if len(parts) < 10:
            continue
        start_s, end_s = parts[1].strip(), parts[2].strip()
        body = parts[9]
        if re.search(r"\{\\p[1-9]", body):
            continue

        m1 = re.match(r"(\d+):(\d{2}):(\d{2})\.(\d{2})", start_s)
        m2 = re.match(r"(\d+):(\d{2}):(\d{2})\.(\d{2})", end_s)
        if not m1 or not m2:
            continue
        st = f"{int(m1.group(1)):02d}:{int(m1.group(2)):02d}:{int(m1.group(3)):02d},{int(m1.group(4))*10:03d}"
        en = f"{int(m2.group(1)):02d}:{int(m2.group(2)):02d}:{int(m2.group(3)):02d},{int(m2.group(4))*10:03d}"

        clean = body.replace("\\N", "\n").replace("\\n", "\n").replace("\\h", " ")
        clean = re.sub(r"\{[^}]*\}", "", clean).strip()
        if clean:
            events.append((st, en, clean))

    if not events:
        return b""
    events.sort(key=lambda x: x[0])
    blocks = [f"{i}\n{st} --> {en}\n{txt}" for i, (st, en, txt) in enumerate(events, 1)]
    return ("\n\n".join(blocks) + "\n").encode("utf-8")


def ensure_srt_bytes(raw_bytes):
    if not raw_bytes:
        return b""
    if b"-->" in raw_bytes:
        return raw_bytes
    if b"Dialogue:" in raw_bytes:
        return ass_to_srt(raw_bytes)
    return b""


def parse_stremio_id(raw_id):
    clean = unquote(raw_id).strip()
    if clean.endswith(".srt"):
        clean = clean[:-4]
    parts = clean.split(":")
    if parts[0].startswith("tt"):
        imdb_id = parts[0]
        season = int(parts[1]) if len(parts) >= 2 and parts[1].isdigit() else None
        ep = int(parts[2]) if len(parts) >= 3 and parts[2].isdigit() else None
        return {"kind": "imdb", "imdb": imdb_id, "season": season, "ep": ep, "raw": clean}
    if parts[0] == "kitsu" and len(parts) >= 2:
        kitsu_id = parts[1]
        ep = int(parts[2]) if len(parts) >= 3 and parts[2].isdigit() else 1
        return {"kind": "kitsu", "kitsu": kitsu_id, "season": 1, "ep": ep, "raw": clean}
    return {"kind": "unknown", "raw": clean}


def extract_keywords(text):
    words = re.findall(r"[a-zA-Z]{4,}", (text or "").lower())
    out = []
    for w in words:
        if w not in STOPWORDS and w not in out:
            out.append(w)
    return out[:14]


def resolve_kitsu_meta(kitsu_id, ep=None):
    title = ""
    is_movie = False
    imdb_id = None
    ep_kw = []
    try:
        r = requests.get(f"https://kitsu.io/api/edge/anime/{kitsu_id}", headers=HDRS, timeout=5)
        if r.status_code == 200:
            attrs = (r.json().get("data") or {}).get("attributes") or {}
            titles = attrs.get("titles") or {}
            title = titles.get("en") or titles.get("en_jp") or attrs.get("canonicalTitle") or ""
            is_movie = str(attrs.get("subtype", "")).lower() == "movie"
    except Exception:
        pass

    if ep is not None and not is_movie:
        try:
            er = requests.get(
                f"https://kitsu.io/api/edge/anime/{kitsu_id}/episodes?filter[number]={ep}",
                headers=HDRS,
                timeout=4,
            )
            if er.status_code == 200:
                edata = er.json().get("data") or []
                if edata:
                    eattrs = edata[0].get("attributes") or {}
                    ep_kw = extract_keywords(
                        f"{eattrs.get('canonicalTitle', '')} {eattrs.get('synopsis', '')}"
                    )
        except Exception:
            pass

    try:
        mr = requests.get(f"https://kitsu.io/api/edge/anime/{kitsu_id}/mappings", headers=HDRS, timeout=5)
        if mr.status_code == 200:
            for item in mr.json().get("data") or []:
                attrs = item.get("attributes") or {}
                if attrs.get("externalSite") == "imdb":
                    ext_id = str(attrs.get("externalId") or "").strip()
                    if ext_id.startswith("tt"):
                        imdb_id = ext_id
                        break
    except Exception:
        pass

    return title, is_movie, imdb_id, ep_kw


def fetch_cinemeta_context(imdb_id, media_type, season, ep):
    title = ""
    is_anime = False
    title_kw = []
    plot_kw = []
    res_season = season
    res_ep = ep
    try:
        meta_kind = "movie" if media_type == "movie" else "series"
        meta = requests.get(
            f"https://v3-cinemeta.strem.io/meta/{meta_kind}/{imdb_id}.json",
            headers=HDRS,
            timeout=5,
        ).json().get("meta") or {}
        title = meta.get("name") or ""
        genres = [g.lower() for g in (meta.get("genres") or [])]
        is_anime = ("animation" in genres or "anime" in genres)

        if meta_kind == "series" and ep is not None:
            vids = meta.get("videos") or []
            s = season or 1
            hit = None
            for v in vids:
                vs = v.get("season")
                ve = v.get("episode") if v.get("episode") is not None else v.get("number")
                if vs == s and ve == ep:
                    hit = v
                    break

            if not hit and s == 1:
                reg = [v for v in vids if (v.get("season") or 0) > 0]
                reg.sort(
                    key=lambda v: (
                        v.get("season", 0),
                        v.get("episode") if v.get("episode") is not None else v.get("number", 0),
                    )
                )
                if 1 <= ep <= len(reg):
                    hit = reg[ep - 1]
                    res_season = hit.get("season") or 1
                    res_ep = hit.get("episode") if hit.get("episode") is not None else hit.get("number", ep)

            if hit:
                ep_name = hit.get("name") or hit.get("title") or ""
                ep_desc = hit.get("overview") or hit.get("description") or ""
                title_kw = extract_keywords(ep_name)
                plot_kw = extract_keywords(ep_desc)
    except Exception:
        pass
    return title, is_anime, title_kw, plot_kw, res_season, res_ep


def download_and_extract_candidates(url, hint="", ep=None, alt_ep=None):
    try:
        r = requests.get(url, headers=HDRS, timeout=6)
        r.raise_for_status()
        content = r.content
    except Exception:
        return []

    try:
        with zipfile.ZipFile(io.BytesIO(content)) as zf:
            files = sorted(
                f for f in zf.namelist()
                if f.lower().endswith(SUB_EXTS)
                and "__MACOSX" not in f
                and not os.path.basename(f).startswith(".")
            )
            if not files:
                return []
            if len(files) == 1:
                srt = ensure_srt_bytes(zf.read(files[0]))
                return [(f"{hint} {files[0]}", srt)] if srt else []

            matched = []
            for target_ep in [x for x in (ep, alt_ep) if x is not None]:
                hit = find_ep(files, target_ep)
                if hit and hit not in matched:
                    matched.append(hit)
                pat = re.compile(rf"(?:e|ep|x|\b|_)0*{target_ep}(?:\b|_|\.|v)", re.I)
                for f in files:
                    if pat.search(os.path.basename(f)) and f not in matched:
                        matched.append(f)
                        if len(matched) >= 4:
                            break

            out = []
            for f in matched[:4]:
                srt = ensure_srt_bytes(zf.read(f))
                if srt:
                    out.append((f"{hint} {f}", srt))
            return out
    except zipfile.BadZipFile:
        srt = ensure_srt_bytes(content)
        return [(hint, srt)] if srt else []


def score_candidate(raw_bytes, label, valid_eps, title_kw, plot_kw, base_bonus=0):
    score = base_bonus
    lbl = (label or "").lower()

    if valid_eps:
        has_exact = any(
            re.search(rf"(?:e|ep|x|\b|_)0*{vep}(?:\b|_|\.|v)", lbl)
            for vep in valid_eps
        )
        other_eps = [
            int(m.group(1))
            for m in re.finditer(r"(?:e|ep|x|\s-\s)0*(\d{1,3})(?:\b|_|\.|v)", lbl)
            if m.group(1).isdigit()
        ]
        if has_exact:
            score += 45
        elif any(o not in valid_eps for o in other_eps):
            score -= 140

    sample = decode_bytes(raw_bytes[:16000]).lower()
    for kw in title_kw:
        if kw in sample:
            score += 25
    for kw in plot_kw:
        if kw in sample:
            score += 12
    return score


def fetch_opensubs_by_imdb(imdb_id, media_type, season, ep, abs_ep=None):
    items = []
    if media_type == "movie" or (season is None and ep is None):
        targets = [f"https://opensubtitles-v3.strem.io/subtitles/movie/{imdb_id}.json"]
    else:
        s = season or 1
        e = ep or 1
        targets = [f"https://opensubtitles-v3.strem.io/subtitles/series/{imdb_id}:{s}:{e}.json"]
        if abs_ep and (s != 1 or abs_ep != e):
            targets.append(f"https://opensubtitles-v3.strem.io/subtitles/series/{imdb_id}:1:{abs_ep}.json")

    seen = set()
    for t_url in targets:
        try:
            subs = requests.get(t_url, headers=HDRS, timeout=5).json().get("subtitles") or []
            en = [x for x in subs if x.get("url") and str(x.get("lang", "")).lower() in ("eng", "en", "english")]
            pool = en or [x for x in subs if x.get("url")]
            for x in pool[:8]:
                u = x["url"]
                if u not in seen:
                    seen.add(u)
                    items.append((u, json.dumps(x), 5))
        except Exception:
            pass
    return items


def fetch_subtitlecat(query, title, ep):
    results = []
    try:
        r = requests.get(f"https://www.subtitlecat.com/index.php?search={quote(query)}", headers=HDRS, timeout=5)
        if r.status_code != 200:
            return []
        soup = BeautifulSoup(r.text, "html.parser")
        for a in soup.select("table.sub-table a[href]")[:4]:
            href = a.get("href", "")
            if not href.startswith("http"):
                href = "https://www.subtitlecat.com/" + href.lstrip("/")
            sr = requests.get(href, headers=HDRS, timeout=5)
            ssoup = BeautifulSoup(sr.text, "html.parser")
            dl = ssoup.select_one("a.green-link[href$='.srt']")
            if dl and dl.get("href"):
                d_url = dl["href"]
                if not d_url.startswith("http"):
                    d_url = "https://www.subtitlecat.com/" + d_url.lstrip("/")
                results.append({"url": d_url, "name": a.get_text(strip=True)})
    except Exception:
        pass
    return results


def get_english_srt_variant(media_type, parsed, variant=0):
    pool_key = f"pool:{media_type}:{parsed['raw']}"
    if pool_key in ENG_POOL_CACHE:
        ENG_POOL_CACHE.move_to_end(pool_key)
        pool = ENG_POOL_CACHE[pool_key]
        if pool:
            return pool[min(variant, len(pool) - 1)]

    sources = []
    title = ""
    ep = parsed.get("ep")
    res_ep = ep
    title_kw = []
    plot_kw = []

    if parsed["kind"] == "imdb":
        imdb_id = parsed["imdb"]
        title, is_anime, title_kw, plot_kw, res_s, res_ep = fetch_cinemeta_context(
            imdb_id, media_type, parsed.get("season"), ep
        )
        for src in fetch_opensubs_by_imdb(imdb_id, media_type, res_s, res_ep, abs_ep=ep):
            sources.append(src)
        if title and is_anime and ep is not None:
            for item in fetch_subtitlecat(f"{title} {ep:02d}", title, ep)[:2]:
                sources.append((item["url"], item.get("name", ""), 0))

    elif parsed["kind"] == "kitsu":
        title, is_movie, imdb_id, kitsu_kw = resolve_kitsu_meta(parsed["kitsu"], ep)
        plot_kw.extend(kitsu_kw)
        res_s = None if is_movie else 1
        if imdb_id:
            _, _, c_tkw, c_pkw, res_s, res_ep = fetch_cinemeta_context(
                imdb_id, "movie" if is_movie else "series", None if is_movie else 1, None if is_movie else ep
            )
            title_kw.extend(c_tkw)
            plot_kw.extend(c_pkw)
            m_type = "movie" if is_movie else "series"
            for src in fetch_opensubs_by_imdb(imdb_id, m_type, res_s, res_ep, abs_ep=None if is_movie else ep):
                sources.append(src)

    if not sources and title:
        for item in fetch_subtitlecat(f"{title} {ep or ''}".strip(), title, ep)[:3]:
            sources.append((item["url"], item.get("name", ""), 0))

    valid_eps = {x for x in (ep, res_ep) if x is not None}
    scored_pool = []
    seen_hashes = set()
    seen_urls = set()
    for u, hint, bonus in sources[:12]:
        if u in seen_urls:
            continue
        seen_urls.add(u)
        for lbl, raw in download_and_extract_candidates(u, hint=hint, ep=ep, alt_ep=res_ep):
            if raw and b"-->" in raw:
                h = hashlib.md5(raw[:1024]).hexdigest()
                if h not in seen_hashes:
                    seen_hashes.add(h)
                    sc = score_candidate(raw, lbl, valid_eps, title_kw, plot_kw, base_bonus=bonus)
                    scored_pool.append((sc, raw))

    scored_pool.sort(key=lambda x: x[0], reverse=True)
    pool = [raw for _, raw in scored_pool]

    if pool:
        ENG_POOL_CACHE[pool_key] = pool
        if len(ENG_POOL_CACHE) > 50:
            ENG_POOL_CACHE.popitem(last=False)
        return pool[min(variant, len(pool) - 1)]
    return None


def fast_translate_srt(raw, lang):
    raw_srt = ensure_srt_bytes(raw)
    if not raw_srt:
        raise RuntimeError("Empty or unsupported subtitle format")

    cleaned_raw = clean_subtitle("sub.srt", raw_srt)
    text = decode_bytes(cleaned_raw).lstrip("\ufeff").replace("\r\n", "\n").replace("\r", "\n")
    blocks = re.split(r"\n{2,}", text)
    cues = []
    for bi, blk in enumerate(blocks):
        bl = blk.split("\n")
        ti = next((i for i, l in enumerate(bl) if "-->" in l), None)
        if ti is not None and ti + 1 < len(bl):
            body = "\n".join(bl[ti + 1:]).strip()
            if body:
                cues.append((bi, "\n".join(bl[:ti + 1]), body))
    if not cues:
        raise RuntimeError("No subtitle lines found")

    bodies = [c[2] for c in cues]
    if len(bodies) > 60:
        mid = (len(bodies) + 1) // 2
        tasks = [(0, bodies[:mid], lang), (1, bodies[mid:], lang)]
    else:
        tasks = [(0, bodies, lang)]

    with ThreadPoolExecutor(max_workers=2) as ex:
        results = list(ex.map(lambda t: unified_ai_batch(t[1], t[2], prefer_alt_groq=(t[0] == 1)), tasks))

    out = [line for batch_res in results for line in batch_res]
    for (bi, hdr, _), nb in zip(cues, out):
        wrapped = wrap_line(nb.strip())
        blocks[bi] = f"{hdr}\n{wrapped}"
    return ("\n\n".join(blocks) + "\n").lstrip("\ufeff").encode("utf-8")


def make_cache_key(lang, variant, media_type, raw_id):
    return hashlib.sha256(f"castex_v1:{lang}:{variant}:{media_type}:{raw_id}".encode()).hexdigest()[:24]


def run_translation_job(cache_key, media_type, parsed, lang, variant=0, extra_keys=None):
    t0 = time.time()
    try:
        JOB_STATUS[cache_key] = "Fetching English subtitle..."
        eng_raw = get_english_srt_variant(media_type, parsed, variant=variant)
        if not eng_raw:
            JOB_STATUS[cache_key] = "No English source subtitle found."
            return

        JOB_STATUS[cache_key] = "Translating with KotoSub AI..."
        translated = fast_translate_srt(eng_raw, lang)
        cache_put(cache_key, translated)
        for ek in (extra_keys or []):
            if ek != cache_key:
                cache_put(ek, translated)
        elapsed = round(time.time() - t0, 2)
        JOB_STATUS[cache_key] = f"Saved permanently in {elapsed}s"
        JOB_TIMING[cache_key] = elapsed
    except Exception as e:
        JOB_STATUS[cache_key] = f"Error: {str(e)[:75]}"
    finally:
        with STATE_GUARD:
            IN_PROGRESS.discard(cache_key)
            ev = JOB_EVENTS.get(cache_key)
            if ev:
                ev.set()


def start_job_if_needed(cache_key, media_type, parsed, lang, variant=0, extra_keys=None):
    if cache_get(cache_key):
        return None
    with STATE_GUARD:
        ev = JOB_EVENTS.get(cache_key)
        if cache_key not in IN_PROGRESS:
            ev = threading.Event()
            JOB_EVENTS[cache_key] = ev
            IN_PROGRESS.add(cache_key)
            threading.Thread(
                target=run_translation_job,
                args=(cache_key, media_type, parsed, lang, variant, extra_keys),
                daemon=True,
            ).start()
        return ev


@app.get("/")
def health():
    return {"status": "ok", "service": "KotoSub AI Engine (Castex + Stremio/Nuvio)"}


@app.get("/debug")
def debug_info():
    token, repo = get_github_config()
    colab_url, colab_model = get_colab_endpoint()
    return {
        "version": "kotosub-castex-v1",
        "github_cache_active": bool(token and repo),
        "github_repo": repo,
        "colab_online": bool(colab_url),
        "colab_url": colab_url,
        "colab_model": colab_model,
        "groq_keys_count": len(get_groq_keys()),
        "gemini_keys_count": len(get_gemini_keys()),
        "mem_cached": len(MEM_CACHE),
        "statuses": JOB_STATUS,
    }


@app.post("/translate_srt")
def translate_direct_stream_srt(req: DirectTranslateRequest):
    """Castex Direct In-Stream Sync Endpoint: translates embedded stream subtitles at 0.000s sync."""
    lang = req.lang if req.lang in ("hi", "bg", "bn") else "hi"
    raw_bytes = req.srt_content.encode("utf-8", errors="ignore")
    s_hash = req.stream_hash.strip() or hashlib.sha256(raw_bytes[:4096]).hexdigest()[:20]
    cache_key = f"stream_{lang}_{s_hash}"

    cached = cache_get(cache_key)
    if cached:
        return {"ok": True, "cached": True, "srt": cached.decode("utf-8", errors="replace")}

    try:
        translated = fast_translate_srt(raw_bytes, lang)
        cache_put(cache_key, translated)
        return {"ok": True, "cached": False, "srt": translated.decode("utf-8", errors="replace")}
    except Exception as e:
        return {"ok": False, "error": str(e)}


@app.get("/manifest.json")
def manifest():
    return {
        "id": "org.castex.kotosub.subs",
        "version": "1.0.0",
        "name": "KotoSub AI (Castex Engine)",
        "description": "Zero-delay Hinglish, Bangla & Banglish subtitles powered by Colab, Groq & Gemini",
        "resources": ["subtitles"],
        "types": ["movie", "series", "anime"],
        "idPrefixes": ["tt", "kitsu"],
        "catalogs": [],
    }


@app.get("/subtitles/{media_type}/{video_id}.json")
@app.get("/subtitles/{media_type}/{video_id}/{extra}.json")
def subtitles_handler(media_type: str, video_id: str, request: Request, extra: str = ""):
    parsed = parse_stremio_id(video_id)
    if parsed["kind"] == "unknown":
        return {"subtitles": []}

    ck_hi = make_cache_key("hi", 0, media_type, parsed["raw"])
    start_job_if_needed(ck_hi, media_type, parsed, "hi", variant=0)

    base_url = str(request.base_url).rstrip("/")
    if base_url.startswith("http://") and "onrender.com" in base_url:
        base_url = "https://" + base_url[len("http://"):]

    safe_id = quote(parsed["raw"], safe=":")
    return {
        "subtitles": [
            {
                "id": f"kotosub-hi0-{safe_id}",
                "url": f"{base_url}/srt/hi/0/{media_type}/{safe_id}.srt",
                "lang": "hin",
                "title": "Hinglish #1 [KotoSub AI]",
            },
            {
                "id": f"kotosub-hi1-{safe_id}",
                "url": f"{base_url}/srt/hi/1/{media_type}/{safe_id}.srt",
                "lang": "hin",
                "title": "Hinglish #2 [Alt Source]",
            },
            {
                "id": f"kotosub-bg0-{safe_id}",
                "url": f"{base_url}/srt/bg/0/{media_type}/{safe_id}.srt",
                "lang": "ben",
                "title": "Bangla [KotoSub AI]",
            },
            {
                "id": f"kotosub-bn0-{safe_id}",
                "url": f"{base_url}/srt/bn/0/{media_type}/{safe_id}.srt",
                "lang": "ben",
                "title": "Banglish [KotoSub AI]",
            },
        ]
    }


def _handle_srt_request(lang: str, variant: int, media_type: str, video_id: str):
    if lang not in ("hi", "bg", "bn"):
        return Response(content="Invalid language", status_code=400)

    parsed = parse_stremio_id(video_id)
    if parsed["kind"] == "unknown":
        return Response(content="Unsupported ID", status_code=404)

    cache_key = make_cache_key(lang, variant, media_type, parsed["raw"])

    cached = cache_get(cache_key)
    if cached:
        return Response(
            content=cached,
            media_type="application/x-subrip; charset=utf-8",
            headers={"Cache-Control": "public, max-age=86400"},
        )

    ev = start_job_if_needed(cache_key, media_type, parsed, lang, variant=variant)
    if ev:
        ev.wait(timeout=9.5)

    cached = cache_get(cache_key)
    if cached:
        return Response(
            content=cached,
            media_type="application/x-subrip; charset=utf-8",
            headers={"Cache-Control": "public, max-age=86400"},
        )

    status_msg = JOB_STATUS.get(cache_key, "Translating...")
    loading_srt = (
        f"1\n00:00:00,500 --> 00:00:25,000\n"
        f"[KotoSub AI] {status_msg} (Reload in 5s)\n"
    ).encode("utf-8")
    return Response(
        content=loading_srt,
        media_type="application/x-subrip; charset=utf-8",
        headers={"Cache-Control": "no-store, no-cache, must-revalidate, max-age=0"},
    )


@app.get("/srt/{lang}/{variant}/{media_type}/{video_id}.srt")
def serve_srt_variant(lang: str, variant: int, media_type: str, video_id: str):
    return _handle_srt_request(lang, variant, media_type, video_id)


@app.get("/srt/{lang}/{media_type}/{video_id}.srt")
def serve_srt_legacy(lang: str, media_type: str, video_id: str):
    return _handle_srt_request(lang, 0, media_type, video_id)
