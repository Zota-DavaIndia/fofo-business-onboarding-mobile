import 'package:material_ui/material_ui.dart';

import '../icons/app_icon.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'page.dart';
import 'widgets.dart';

/// Screen whose content is not built yet: title plus a left-aligned
/// message. Pass [onBack] when it's pushed over the tabs.
class ModulePlaceholder extends StatelessWidget {
  const ModulePlaceholder({super.key, required this.title, required this.icon, required this.message, this.onBack});

  final String title;
  final AppIconData icon;
  final String message;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return PageBody(
      children: [
        if (onBack != null) PageHeader(title, onBack: onBack) else Text(title, style: context.text.title),
        const SizedBox(height: Space.xxl),
        MessageBlock(icon: icon, title: 'Nothing here yet', body: message),
      ],
    );
  }
}
