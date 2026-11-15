import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/theme/app_theme.dart';
import 'router.dart';
import '../features/update/update_screen.dart';

class FieldApp extends ConsumerWidget {
  const FieldApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Davaindia Field Force',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: _systemBars(context),
        child: UpdateWatcher(navigatorKey: rootNavigatorKey, child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}

/// The system bars. Status bar: transparent, so the page colour runs behind the clock (Flutter would
/// otherwise put a 25% black band there on Android 14 and older), with icons that suit the theme.
/// Navigation bar: see-through where Android allows it, so the app's own bottom bar colour runs behind
/// the system buttons instead of a black strip; the card colour on older Android that ignores transparency.
SystemUiOverlayStyle _systemBars(BuildContext context) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    statusBarBrightness: dark ? Brightness.dark : Brightness.light, // iOS: the background, not the icons
    systemStatusBarContrastEnforced: false,
    systemNavigationBarColor: context.colors.card,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
    systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
  );
}
