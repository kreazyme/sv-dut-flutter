import 'package:example_template/gen/i18n/locale.dart';
import 'package:example_template/pages/splash/splash_page.dart';
import 'package:example_template/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(ProviderScope(child: TranslationProvider(child: const MyApp())));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context, ref) {
    final theme = ref.watch(themeProvider);
    return MaterialApp(
      title: 'Example Template',
      navigatorObservers: [_CustomNavigatorObserver()],
      locale: TranslationProvider.of(context).flutterLocale,
      supportedLocales: AppLocaleUtils.supportedLocales,
      localizationsDelegates: [...GlobalMaterialLocalizations.delegates],
      theme: theme,
      home: const SplashPage(),
    );
  }
}

class _CustomNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    print('Navigated to ${route.settings.name}');
    // FirebaseAnalytics.instance.logScreenView(
    //   screenName: route.settings.name ?? 'unknown',
    // );
  }
}
