import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/form.dart';
import '../../core/widgets/submit.dart';
import '../../core/widgets/widgets.dart';

/// Change the signed-in user's password. The server signs out their other
/// phones; this one stays signed in.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordState();
}

class _ChangePasswordState extends ConsumerState<ChangePasswordScreen> with FormSubmit {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  final _err = <String, String>{};
  bool _show = false;

  @override
  void dispose() {
    for (final c in [_current, _next, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    _err.clear();
    final next = _next.text;
    if (_current.text.isEmpty) _err['current_password'] = 'Enter your current password.';
    if (next.length < 8 || !RegExp(r'[A-Za-z]').hasMatch(next) || !RegExp(r'\d').hasMatch(next)) {
      _err['password'] = 'At least 8 characters, with letters and numbers.';
    } else if (next == _current.text) {
      _err['password'] = 'Pick a password different from the current one.';
    }
    if (_confirm.text != next) _err['password_confirmation'] = "The two passwords don't match.";
    setState(() {});
    if (_err.isNotEmpty) return;
    submit(
      (api) => api.post<dynamic>(
        '/auth/change-password',
        body: {'current_password': _current.text, 'password': next, 'password_confirmation': _confirm.text},
      ),
      done: 'Password changed. Your other phones are signed out.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final toggle = TextLink(label: _show ? 'Hide' : 'Show', onTap: () => setState(() => _show = !_show));
    return FormPage(
      title: 'Change password',
      submitLabel: 'Change password',
      submitting: submitting,
      onSubmit: _save,
      children: [
        Text('Use at least 8 characters, with letters and numbers.', style: context.text.secondary),
        AppField(
          controller: _current,
          label: 'Current password',
          obscure: !_show,
          autofillHints: const [AutofillHints.password],
          errorText: _err['current_password'] ?? fieldError('current_password'),
        ),
        AppField(
          controller: _next,
          label: 'New password',
          obscure: !_show,
          autofillHints: const [AutofillHints.newPassword],
          errorText: _err['password'] ?? fieldError('password'),
        ),
        AppField(
          controller: _confirm,
          label: 'New password again',
          obscure: !_show,
          autofillHints: const [AutofillHints.newPassword],
          errorText: _err['password_confirmation'] ?? fieldError('password_confirmation'),
        ),
        Align(alignment: Alignment.centerLeft, child: toggle),
      ],
    );
  }
}
