import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session.dart';
import '../../core/icons/app_icon.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/page.dart';
import '../../core/widgets/widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _showPassword = false;
  ApiException? _error;
  String? _blockedDeviceId;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = ApiException('Enter your email and password.'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(sessionProvider.notifier).login(email: _email.text, password: _password.text);
    } on ApiException catch (e) {
      if (e.code == 'device_not_approved') {
        final id = await ref.read(secureStoreProvider).deviceId();
        if (mounted) setState(() => _blockedDeviceId = id);
      } else if (mounted) {
        setState(() => _error = e);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _clearError(String _) {
    if (_error != null) setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    final blocked = _blockedDeviceId;
    if (blocked != null) {
      return _DeviceBlocked(deviceId: blocked, onBack: () => setState(() => _blockedDeviceId = null));
    }

    final generalError = _error != null && _error!.fieldErrors.isEmpty ? _error!.message : null;

    return PageBody(
      bottom: ActionBar(
        children: [AppButton(label: 'Sign in', loading: _busy, onPressed: _submit)],
      ),
      children: [
        const SizedBox(height: Space.xxl),
        const Wordmark(size: 26),
        const SizedBox(height: Space.xxl),
        Text('Sign in', style: context.text.title),
        Text('Use the account your admin set up for you.', style: context.text.secondary),
        const SizedBox(height: Space.sm),
        AppField(
          controller: _email,
          label: 'Email',
          hint: 'name@example.com',
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          onChanged: _clearError,
          errorText: _error?.fieldError('email'),
        ),
        AppField(
          controller: _password,
          label: 'Password',
          obscure: !_showPassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          autofillHints: const [AutofillHints.password],
          onChanged: _clearError,
          errorText: _error?.fieldError('password'),
          trailing: IconTile(
            AppIcons.eye,
            background: Colors.transparent,
            color: _showPassword ? context.colors.accent : context.colors.textTertiary,
            semanticLabel: _showPassword ? 'Hide password' : 'Show password',
            onTap: () => setState(() => _showPassword = !_showPassword),
          ),
        ),
        if (generalError != null) Text(generalError, style: context.text.label.copyWith(color: context.colors.danger)),
        Text('Forgot your password? Ask your admin to reset it.', style: context.text.label),
      ],
    );
  }
}

class _DeviceBlocked extends StatelessWidget {
  const _DeviceBlocked({required this.deviceId, required this.onBack});

  final String deviceId;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return PageBody(
      bottom: ActionBar(
        children: [AppButton(label: 'Try again', kind: ButtonKind.secondary, onPressed: onBack)],
      ),
      children: [
        const SizedBox(height: Space.xxl),
        const MessageBlock(
          icon: AppIcons.lock,
          title: 'This phone needs approval',
          body: 'Send this device ID to your admin. Once they approve it, sign in again.',
        ),
        GroupedList(
          children: [
            ListRow(
              title: deviceId,
              subtitle: 'Device ID',
              trailing: IconTile(
                AppIcons.copy,
                semanticLabel: 'Copy device ID',
                onTap: () {
                  Clipboard.setData(ClipboardData(text: deviceId));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Device ID copied')));
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
