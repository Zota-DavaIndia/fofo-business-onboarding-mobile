import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/auth/login_id.dart';
import '../../core/auth/session.dart';
import '../../core/brand/logo.dart';
import '../../core/icons/app_icon.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/page.dart';
import '../../core/widgets/widgets.dart';
import '../tracking/track_session.dart';
import '../../core/widgets/toast.dart';

enum _Step { identify, password, otp }

/// One sign-in box for everyone. An email goes straight to the password
/// step. A mobile number is checked with `/auth/start`: staff get the
/// password step, people who made an enquiry get a one-time code.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _id = TextEditingController();
  final _password = TextEditingController();
  final _otp = TextEditingController();
  _Step _step = _Step.identify;
  LoginId? _loginId;
  bool _busy = false;
  bool _showPassword = false;
  ApiException? _error;
  String? _blockedDeviceId;
  Timer? _resendTimer;
  int _resendIn = 0;

  @override
  void dispose() {
    _id.dispose();
    _password.dispose();
    _otp.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() task) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await task();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _fieldError(String field, String message) {
    setState(
      () => _error = ApiException(
        message,
        fieldErrors: {
          field: [message],
        },
      ),
    );
  }

  Future<void> _continue() async {
    final id = LoginId.parse(_id.text);
    if (id == null) {
      _fieldError('id', 'Enter a valid email or a 10-digit mobile number.');
      return;
    }
    _loginId = id;
    if (id.field == 'email') {
      setState(() => _step = _Step.password);
      return;
    }
    await _run(() async {
      try {
        final res = await ref
            .read(apiClientProvider)
            .post<Map<String, dynamic>>('/auth/start', body: {'mobile': id.value});
        if (!mounted) return;
        if (res.data['next'] == 'otp') {
          setState(() => _step = _Step.otp);
          _startResendTimer();
        } else {
          setState(() => _step = _Step.password);
        }
      } on ApiException catch (e) {
        if (e.status == 404) {
          throw ApiException("We don't have an enquiry or an account for this number.");
        }
        rethrow;
      }
    });
  }

  Future<void> _signIn() async {
    if (_password.text.isEmpty) {
      _fieldError('password', 'Enter your password.');
      return;
    }
    await _run(() async {
      try {
        await ref.read(sessionProvider.notifier).login(id: _loginId!, password: _password.text);
      } on ApiException catch (e) {
        if (e.code != 'device_not_approved') rethrow;
        final device = await ref.read(secureStoreProvider).deviceId();
        if (mounted) setState(() => _blockedDeviceId = device);
      }
    });
  }

  Future<void> _verify() async {
    final code = _otp.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      _fieldError('otp', 'Enter the 6-digit code.');
      return;
    }
    await _run(() => ref.read(trackSessionProvider.notifier).verify(mobile: _loginId!.value, otp: code));
  }

  Future<void> _resend() async {
    await _run(() async {
      await ref.read(trackSessionProvider.notifier).resend(_loginId!.value);
      _startResendTimer();
      if (mounted) showToast(context, 'Code sent again', kind: ToastKind.success);
    });
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendIn = 30);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendIn--);
      if (_resendIn <= 0) t.cancel();
    });
  }

  void _back() {
    _resendTimer?.cancel();
    setState(() {
      _step = _Step.identify;
      _password.clear();
      _otp.clear();
      _error = null;
    });
  }

  void _clearError(String _) {
    if (_error != null) setState(() => _error = null);
  }

  String get _shownId {
    final id = _loginId;
    if (id == null) return '';
    if (id.field == 'mobile') return '${id.value.substring(0, 5)} ${id.value.substring(5)}';
    return id.value;
  }

  @override
  Widget build(BuildContext context) {
    final blocked = _blockedDeviceId;
    if (blocked != null) {
      return _DeviceBlocked(deviceId: blocked, onBack: () => setState(() => _blockedDeviceId = null));
    }
    final generalError = _error != null && _error!.fieldErrors.isEmpty ? _error!.message : null;

    final (button, onPressed) = switch (_step) {
      _Step.identify => ('Continue', _continue),
      _Step.password => ('Sign in', _signIn),
      _Step.otp => ('Verify', _verify),
    };

    return PageBody(
      bottom: ActionBar(
        children: [AppButton(label: button, loading: _busy, onPressed: onPressed)],
      ),
      children: [
        const SizedBox(height: Space.xxl),
        const AppLogo(height: 28),
        const SizedBox(height: Space.xxl),
        ...switch (_step) {
          _Step.identify => _identify(context),
          _Step.password => _passwordStep(context),
          _Step.otp => _otpStep(context),
        },
        if (generalError != null) Text(generalError, style: context.text.label.copyWith(color: context.colors.danger)),
      ],
    );
  }

  List<Widget> _identify(BuildContext context) => [
    Text('Sign in', style: context.text.title),
    Text('Enter your email or mobile number to continue.', style: context.text.secondary),
    const SizedBox(height: Space.sm),
    AppField(
      controller: _id,
      label: 'Email or mobile',
      hint: 'name@example.com or 98450 12345',
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.go,
      onSubmitted: (_) => _continue(),
      autofillHints: const [AutofillHints.username],
      onChanged: _clearError,
      errorText: _error?.fieldError('id') ?? _error?.fieldError('mobile'),
    ),
  ];

  Widget _who(BuildContext context) => Container(
    padding: const EdgeInsets.only(left: Space.lg, right: Space.md),
    constraints: const BoxConstraints(minHeight: Sizes.field),
    decoration: BoxDecoration(color: context.fieldFill, borderRadius: BorderRadius.circular(Radii.field)),
    child: Row(
      children: [
        Expanded(child: Text(_shownId, style: context.text.bodyStrong)),
        TextLink(label: 'Change', onTap: _back),
      ],
    ),
  );

  List<Widget> _passwordStep(BuildContext context) => [
    Text('Sign in', style: context.text.title),
    Text('Enter the password for this account.', style: context.text.secondary),
    const SizedBox(height: Space.xs),
    _who(context),
    const SizedBox(height: Space.sm),
    AppField(
      controller: _password,
      label: 'Password',
      hint: '••••••••',
      obscure: !_showPassword,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _signIn(),
      autofillHints: const [AutofillHints.password],
      onChanged: _clearError,
      errorText: _error?.fieldError('password') ?? _error?.fieldError('email'),
      trailing: IconTile(
        AppIcons.eye,
        background: Colors.transparent,
        color: _showPassword ? context.colors.accent : context.colors.textTertiary,
        semanticLabel: _showPassword ? 'Hide password' : 'Show password',
        onTap: () => setState(() => _showPassword = !_showPassword),
      ),
    ),
    Text('Forgot your password? Ask Dava India to reset it.', style: context.text.label),
  ];

  List<Widget> _otpStep(BuildContext context) => [
    Text('Enter the code', style: context.text.title),
    Text('Use the 6-digit sign-in code for this number.', style: context.text.secondary),
    _who(context),
    const SizedBox(height: Space.sm),
    AppField(
      controller: _otp,
      label: 'Code',
      hint: '••••••',
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _verify(),
      autofillHints: const [AutofillHints.oneTimeCode],
      onChanged: _clearError,
      errorText: _error?.fieldError('otp'),
    ),
    if (_resendIn > 0)
      Text('You can ask for a new code in $_resendIn s.', style: context.text.label)
    else
      TextLink(label: 'Send a new code', onTap: _resend),
  ];
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
          body: 'Send this device ID to Dava India. Once it is approved, sign in again.',
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
                  showToast(context, 'Device ID copied', kind: ToastKind.success);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
