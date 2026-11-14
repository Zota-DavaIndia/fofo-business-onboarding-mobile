import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// The in-app logo: the official davaindia icon, then the "davaindia" word
/// with "FIELD FORCE" set under it in clay caps. [height] is the height of
/// the word; the icon spans the word and tagline together. Dark mode uses
/// the lettering with a lighter green and the lighter clay.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.height = 22});

  final double height;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final size = height * 0.355;
    return Semantics(
      label: 'Davaindia Field Force',
      image: true,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            dark ? 'assets/brand/icon-dark.png' : 'assets/brand/icon.png',
            height: height * 1.5,
            filterQuality: FilterQuality.medium,
          ),
          SizedBox(width: height * 0.3),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(
                dark ? 'assets/brand/wordmark-dark.png' : 'assets/brand/wordmark.png',
                height: height,
                filterQuality: FilterQuality.medium,
              ),
              SizedBox(height: height * 0.14),
              Padding(
                padding: EdgeInsets.only(left: height * 0.1),
                child: Text(
                  'FIELD FORCE',
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontFamily: AppText.family,
                    fontWeight: FontWeight.w600,
                    fontSize: size,
                    letterSpacing: size * 0.06,
                    height: 1,
                    color: context.colors.accent,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
