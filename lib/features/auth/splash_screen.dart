import 'package:material_ui/material_ui.dart';

import '../../core/theme/tokens.dart';
import '../../core/brand/logo.dart';

/// Shown while the saved session is being restored.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: Space.xxl),
          child: Align(alignment: Alignment.centerLeft, child: AppLogo(height: 48)),
        ),
      ),
    );
  }
}
