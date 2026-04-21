import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onerise_mobile/features/auth/auth_controller.dart';

/// Free-tier student registration. Same fields as the web app's
/// signup form — name, email, phone, privacy-consent required,
/// marketing-consent optional.
///
/// On success we pop back to the login screen and pre-fill the
/// email; caller taps "Отправить код" to finish the loop. We could
/// auto-trigger the OTP ourselves, but making the user explicitly
/// click "Отправить код" avoids a surprising second auto-action
/// right after account creation.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  bool _privacy = false;
  bool _marketing = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    if (name.isEmpty) {
      _toast('Введите имя');
      return;
    }
    if (!_isEmail(email)) {
      _toast('Введите корректный email');
      return;
    }
    if (!_privacy) {
      _toast('Нужно согласие на обработку персональных данных');
      return;
    }

    final ok = await ref.read(authControllerProvider.notifier).register(
          name: name,
          email: email,
          phone: _phone.text,
          privacyAccepted: _privacy,
        );
    if (!mounted) return;
    if (ok) {
      _toast('Готово! Теперь войдите с этим email');
      // Return the email back to the login screen so it's pre-filled.
      Navigator.of(context).pop<String>(email);
    }
  }

  bool _isEmail(String s) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(s);

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    // Surface repo errors as toasts.
    ref.listen<String?>(
      authControllerProvider.select((s) => s.error),
      (_, next) {
        if (next != null) _toast(next);
      },
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Регистрация')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              const Text(
                'Создайте бесплатный аккаунт, чтобы записываться на '
                'занятия с меткой FREE.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Имя',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _email,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phone,
                decoration: const InputDecoration(
                  labelText: 'Телефон (необязательно)',
                  border: OutlineInputBorder(),
                  hintText: '+7 900 123 45 67',
                ),
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => auth.loading ? null : _submit(),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                value: _privacy,
                onChanged: auth.loading
                    ? null
                    : (v) => setState(() => _privacy = v ?? false),
                title: const Text('Согласен на обработку персональных данных'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              CheckboxListTile(
                value: _marketing,
                onChanged: auth.loading
                    ? null
                    : (v) => setState(() => _marketing = v ?? false),
                title: const Text('Согласен получать новости и акции'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: auth.loading ? null : _submit,
                style:
                    FilledButton.styleFrom(padding: const EdgeInsets.all(14)),
                child: auth.loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Зарегистрироваться'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
