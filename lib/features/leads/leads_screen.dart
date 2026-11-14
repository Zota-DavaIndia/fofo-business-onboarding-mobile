import 'package:flutter/widgets.dart';

import '../../core/icons/app_icon.dart';
import '../../core/widgets/module_placeholder.dart';

class LeadsScreen extends StatelessWidget {
  const LeadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModulePlaceholder(
      title: 'Leads',
      icon: AppIcons.leads,
      message: 'Leads assigned to you will show here, with search and filters.',
    );
  }
}
