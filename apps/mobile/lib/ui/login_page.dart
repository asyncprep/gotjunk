import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_localizations.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth
          .signInWithPassword(email: _email.text.trim(), password: _password.text);
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(t.appTitle, style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    Text(t.signInTitle, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 24),
                    if (_error != null) ...[
                      Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.username],
                      decoration: InputDecoration(labelText: t.email, border: const OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _password,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      onSubmitted: (_) => _signIn(),
                      decoration: InputDecoration(labelText: t.password, border: const OutlineInputBorder()),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _busy ? null : _signIn,
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                      child: Text(t.signIn),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
