import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_localizations.dart';
import 'quick_signin.dart';

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

  final _passwordFocus = FocusNode();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _signIn() => _signInWith(_email.text.trim(), _password.text);

  void _quick(QuickAccount account) {
    _email.text = account.email;
    if (account.password != null) {
      _signInWith(account.email, account.password!);
    } else {
      _password.clear();
      _passwordFocus.requestFocus();
    }
  }

  Future<void> _signInWith(String email, String password) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(email: email, password: password);
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
                      focusNode: _passwordFocus,
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
                    if (quickAccounts.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text(t.quickTitle, style: Theme.of(context).textTheme.titleSmall),
                      Text(t.quickHint, style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final a in quickAccounts)
                          OutlinedButton(onPressed: _busy ? null : () => _quick(a), child: Text(a.label)),
                      ]),
                    ],
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
