import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/app_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = true;
  bool _submitted = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitted = true);
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (username.isEmpty || password.isEmpty) return;

    final state = context.read<AppState>();
    await state.login(username: username, password: password, rememberMe: _rememberMe);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;

    final usernameError = _submitted && _usernameController.text.trim().isEmpty
        ? 'Enter your Dexcom username'
        : null;
    final passwordError =
        _submitted && _passwordController.text.isEmpty ? 'Enter your password' : null;

    final viewInsets = MediaQuery.viewInsetsOf(context);
    const horizontalPadding = 20.0;
    const verticalPadding = 20.0;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.primary.withValues(alpha: 0.35),
                    scheme.secondary.withValues(alpha: 0.15),
                    const Color(0xFF0B0F14),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final minContentHeight = (constraints.maxHeight - verticalPadding * 2)
                    .clamp(0.0, double.infinity);
                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        verticalPadding,
                        horizontalPadding,
                        verticalPadding + viewInsets.bottom,
                      ),
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: minContentHeight),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Dexcom Follow',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .displaySmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Sign in to view your latest glucose reading.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(color: scheme.onSurface.withValues(alpha: 0.75)),
                            ),
                            const SizedBox(height: 18),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    TextField(
                                      controller: _usernameController,
                                      keyboardType: TextInputType.emailAddress,
                                      autofillHints: const [AutofillHints.username],
                                      decoration: InputDecoration(
                                        labelText: 'Username',
                                        errorText: usernameError,
                                        prefixIcon: const Icon(Icons.person_outline),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: _passwordController,
                                      obscureText: _obscurePassword,
                                      autofillHints: const [AutofillHints.password],
                                      decoration: InputDecoration(
                                        labelText: 'Password',
                                        errorText: passwordError,
                                        prefixIcon: const Icon(Icons.lock_outline),
                                        suffixIcon: IconButton(
                                          tooltip: _obscurePassword
                                              ? 'Show password'
                                              : 'Hide password',
                                          onPressed: () => setState(
                                            () => _obscurePassword = !_obscurePassword,
                                          ),
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_outlined
                                                : Icons.visibility_off_outlined,
                                          ),
                                        ),
                                      ),
                                      onSubmitted: (_) => _submit(),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Switch(
                                          value: _rememberMe,
                                          onChanged: (v) => setState(() => _rememberMe = v),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Remember login on this device (insecure)',
                                            style: Theme.of(context).textTheme.bodyMedium,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    if (state.error != null) ...[
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: scheme.errorContainer.withValues(alpha: 0.55),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: Text(
                                          state.error!,
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                color: scheme.onErrorContainer,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                    ],
                                    FilledButton.icon(
                                      onPressed:
                                          state.phase == AppPhase.initializing ? null : _submit,
                                      icon: const Icon(Icons.login),
                                      label: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        child: Text(
                                          state.phase == AppPhase.initializing
                                              ? 'Signing in…'
                                              : 'Sign in',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextButton.icon(
                                      onPressed: () => state.logout(clearSaved: true),
                                      icon: const Icon(Icons.delete_outline),
                                      label: const Text('Clear saved login'),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Server: EU/International',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            color: scheme.onSurface.withValues(alpha: 0.65),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

