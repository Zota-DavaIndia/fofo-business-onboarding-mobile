import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../auth/session.dart';
import '../network/api_client.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'form.dart';
import 'widgets.dart';

/// Asks the server for a one-time customer sign-in code (`POST
/// …/partner-code`, field OTP driver only) and shows it to read out.
Future<void> showPartnerCode(BuildContext context, WidgetRef ref, String path, {required String name}) async {
  try {
    final res = await ref.read(apiClientProvider).post<Map<String, dynamic>>(path);
    if (!context.mounted) return;
    final code = '${res.data['code']}';
    final expires =
        DateTime.tryParse('${res.data['expires_at']}')?.toLocal() ??
        DateTime.now().add(Duration(seconds: (res.data['expires_in'] as num?)?.toInt() ?? 900));
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: context.colors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet))),
      builder: (_) => _CodeSheet(code: code, expires: expires, name: name),
    );
  } on ApiException catch (e) {
    if (context.mounted) showSaveError(context, e);
  }
}

class _CodeSheet extends StatefulWidget {
  const _CodeSheet({required this.code, required this.expires, required this.name});

  final String code;
  final DateTime expires;
  final String name;

  @override
  State<_CodeSheet> createState() => _CodeSheetState();
}

class _CodeSheetState extends State<_CodeSheet> {
  late final Timer _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = widget.expires.difference(DateTime.now());
    final over = left.isNegative;
    final mm = left.inMinutes.clamp(0, 99).toString().padLeft(2, '0');
    final ss = (left.inSeconds % 60).clamp(0, 59).toString().padLeft(2, '0');
    final spaced = widget.code.split('').join(' ');
    return SheetBody(
      title: 'Sign-in code for ${widget.name}',
      footer: over
          ? null
          : AppButton(
              label: 'Copy code',
              kind: ButtonKind.secondary,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: widget.code));
                showSaved(context, 'Code copied');
              },
            ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(over ? '— — — — — —' : spaced, style: context.text.number.copyWith(fontSize: 40, letterSpacing: 2)),
              const SizedBox(height: Space.sm),
              Text(
                over ? 'This code has expired. Ask for a new one.' : 'Read it out. Works once, for $mm:$ss more.',
                style: context.text.secondary.copyWith(color: over ? context.colors.danger : null),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
