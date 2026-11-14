import 'package:flutter/widgets.dart';

import '../../core/icons/app_icon.dart';
import '../../core/widgets/module_placeholder.dart';

class VisitsScreen extends StatelessWidget {
  const VisitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModulePlaceholder(
      title: 'Visits',
      icon: AppIcons.visit,
      message: 'Your visit plan for the day, with the map and check-in, will show here.',
    );
  }
}
