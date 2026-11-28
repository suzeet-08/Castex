import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'castex_core.dart';
import 'castex_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enable high-refresh-rate (90Hz/120Hz) touch input resampling for ultra-smooth scrolling
  GestureBinding.instance.resamplingEnabled = true;

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final controller = CastexController();
  await controller.init();
  runApp(CastexApp(controller: controller));
}
