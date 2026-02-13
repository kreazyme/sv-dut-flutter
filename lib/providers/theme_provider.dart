import 'package:example_template/common/theme.dart';
import 'package:flutter/material.dart';
import 'package:riverpod/legacy.dart';

final themeProvider = StateProvider<ThemeData>((ref) => AppTheme.lightTheme);
