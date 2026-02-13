import 'package:example_template/common/theme.dart';
import 'package:flutter/material.dart';

final ValueNotifier<ThemeData> themeNotifier = ValueNotifier(
  AppTheme.lightTheme,
);
