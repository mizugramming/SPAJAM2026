import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router.dart';
import 'theme.dart';
import 'mobile_viewport.dart';

class YohakuApp extends ConsumerWidget {
  const YohakuApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: '余白',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    locale: const Locale('ja'),
    supportedLocales: const [Locale('ja')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    builder: (context, child) =>
        MobileViewport(child: child ?? const SizedBox.shrink()),
    routerConfig: ref.watch(routerProvider),
  );
}
