import 'package:flutter/widgets.dart';

import '../../core/icons/app_icon.dart';
import '../../core/widgets/module_placeholder.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModulePlaceholder(
      title: 'Onboarding',
      icon: AppIcons.store,
      message: 'Partners you are onboarding, and what each one is waiting for, will show here.',
    );
  }
}
