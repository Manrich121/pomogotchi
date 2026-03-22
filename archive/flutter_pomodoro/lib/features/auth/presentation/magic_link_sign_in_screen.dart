import 'package:flutter/material.dart';

class MagicLinkSignInScreen extends StatefulWidget {
  const MagicLinkSignInScreen({
    super.key,
    required this.onRequestMagicLink,
    required this.onVerifyEmailCode,
  });

  final Future<void> Function(String email) onRequestMagicLink;
  final Future<void> Function(String email, String code) onVerifyEmailCode;

  @override
  State<MagicLinkSignInScreen> createState() => _MagicLinkSignInScreenState();
}

class _MagicLinkSignInScreenState extends State<MagicLinkSignInScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isRequestingLink = false;
  bool _isVerifyingCode = false;
  bool _canEnterVerificationCode = false;
  String? _errorMessage;
  String? _statusMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _requestMagicLink() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }

    setState(() {
      _isRequestingLink = true;
      _errorMessage = null;
      _statusMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      await widget.onRequestMagicLink(email);
      if (!mounted) {
        return;
      }
      setState(() {
        _canEnterVerificationCode = true;
        _statusMessage =
            'Magic link sent to $email. Open it on this device or enter the 6-digit code from the email.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRequestingLink = false;
        });
      }
    }
  }

  Future<void> _verifyCode() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }

    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() {
        _errorMessage = 'Enter the 6-digit code from the email';
        _statusMessage = null;
      });
      return;
    }

    setState(() {
      _isVerifyingCode = true;
      _errorMessage = null;
      _statusMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      await widget.onVerifyEmailCode(email, code);
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = 'Verifying code for $email...';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isVerifyingCode = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Pomogotchi Sign In')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Sign in with email',
                      style: theme.textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Use the same email on macOS and iOS to sync one Pomogotchi account across both devices. You can finish sign-in from the magic link or the 6-digit code in the email.',
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        hintText: 'you@example.com',
                        border: OutlineInputBorder(),
                      ),
                      autofillHints: const [AutofillHints.email],
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (email.isEmpty) {
                          return 'Email is required';
                        }
                        if (!email.contains('@')) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _isRequestingLink || _isVerifyingCode
                          ? null
                          : _requestMagicLink,
                      child: Text(
                        _isRequestingLink
                            ? 'Sending magic link...'
                            : 'Send magic link',
                      ),
                    ),
                    if (_canEnterVerificationCode) ...[
                      const SizedBox(height: 24),
                      Text(
                        'Or enter the code from the email',
                        style: theme.textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _codeController,
                        decoration: const InputDecoration(
                          labelText: 'Email code',
                          hintText: '123456',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _verifyCode(),
                        validator: (value) {
                          final code = value?.trim() ?? '';
                          if (code.isEmpty) {
                            return null;
                          }
                          if (!RegExp(r'^\d{6}$').hasMatch(code)) {
                            return 'Enter the 6-digit code from the email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: _isRequestingLink || _isVerifyingCode
                            ? null
                            : _verifyCode,
                        child: Text(
                          _isVerifyingCode
                              ? 'Verifying code...'
                              : 'Verify code',
                        ),
                      ),
                    ],
                    if (_statusMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _statusMessage!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
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
