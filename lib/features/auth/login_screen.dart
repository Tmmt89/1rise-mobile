import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onerise_mobile/features/auth/auth_controller.dart';
import 'package:onerise_mobile/features/auth/register_screen.dart';

/// Two-step OTP login.
///
///   Step 1 — email input → `/api/auth/request-otp`.
///   Step 2 — 6-digit code → `/api/auth/verify-otp` → sets cookie
///            → redirect handled by the router's auth guard.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  _Step _step = _Step.email;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim();
    if (!_looksLikeEmail(email)) {
      _toast('Введите корректный email');
      return;
    }
    await ref.read(authControllerProvider.notifier).requestOtp(email);
    final err = ref.read(authControllerProvider).error;
    if (err == null) {
      setState(() => _step = _Step.code);
    }
  }

  Future<void> _verifyCode() async {
    final ok = await ref.read(authControllerProvider.notifier).verifyOtp(
          email: _emailCtrl.text.trim(),
          code: _codeCtrl.text.trim(),
        );
    if (!ok) return;
    // Router's redirect on the state change takes us home — nothing
    // to do here.
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  bool _looksLikeEmail(String s) =>
      // Raw-string regex — `$` is the anchor, NOT literal. The earlier
      // version had `\$` which demanded a literal `$` at the end of
      // the email, rejecting every real address. This regex matches
      // the permissive RFC-5321-ish "one @, at least one dot in the
      // domain" shape everyone actually uses.
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(s);

  /// Open the registration sheet. On success the register screen
  /// pops the email back to us — we pre-fill the email field and
  /// leave the user on "Отправить код" so they finish the OTP.
  Future<void> _openRegister() async {
    final email = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
    if (email != null && mounted) {
      setState(() {
        _emailCtrl.text = email;
        _step = _Step.email;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    // Surface repo errors as toasts once per change.
    ref.listen<String?>(
      authControllerProvider.select((s) => s.error),
      (_, next) {
        if (next != null) _toast(next);
      },
    );

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Rise Speaking Club',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _step == _Step.email
                    ? 'Введите email, мы пришлём код для входа'
                    : 'Введите 6-значный код из письма',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 32),
              if (_step == _Step.email) ...[
                TextField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => auth.loading ? null : _sendCode(),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: auth.loading ? null : _sendCode,
                  child: auth.loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Отправить код'),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Ещё нет аккаунта?',
                      style: TextStyle(color: Colors.black54),
                    ),
                    TextButton(
                      onPressed: auth.loading ? null : _openRegister,
                      child: const Text('Зарегистрироваться'),
                    ),
                  ],
                ),
              ] else ...[
                TextField(
                  controller: _codeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Код',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  autofillHints: const [AutofillHints.oneTimeCode],
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => auth.loading ? null : _verifyCode(),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: auth.loading ? null : _verifyCode,
                  child: auth.loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Войти'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: auth.loading
                      ? null
                      : () => setState(() => _step = _Step.email),
                  child: const Text('Другой email'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum _Step { email, code }
