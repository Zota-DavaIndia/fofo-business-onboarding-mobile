import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/page.dart';

/// Shown while the saved session is being restored.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: Space.xxl),
          child: Align(alignment: Alignment.centerLeft, child: Wordmark(size: 32)),
        ),
      ),
    );
  }
}
