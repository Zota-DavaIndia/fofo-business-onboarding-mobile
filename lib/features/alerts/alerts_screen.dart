import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../core/icons/app_icon.dart';
import '../../core/widgets/module_placeholder.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ModulePlaceholder(
      title: 'Alerts',
      icon: AppIcons.bell,
      message: 'New assignments, approvals and payment updates will show here.',
      onBack: () => context.pop(),
    );
  }
}
