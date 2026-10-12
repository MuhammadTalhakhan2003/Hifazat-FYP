// Forgot password screen: email -> 6-digit code -> new password
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hifazat_app/api/services/auth_service.dart';
import 'package:hifazat_app/widgets/auth_layout.dart';
import 'package:hifazat_app/widgets/form_fields.dart';

enum _ResetStep { email, code, newPassword }

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static const int _resendCooldownSeconds = 60; // Matches the backend cooldown

  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _password2Controller = TextEditingController();

  _ResetStep _step = _ResetStep.email;
  bool _isLoading = false;
  int _resendSecondsLeft = 0;
  Timer? _resendTimer;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _password2Controller.dispose();
    super.dispose();
  }

  String get _email => _emailController.text.trim();

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendSecondsLeft = _resendCooldownSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _resendSecondsLeft--);
      if (_resendSecondsLeft <= 0) timer.cancel();
    });
  }

  // Runs an API call with the loading spinner on, showing any error in a SnackBar.
  Future<bool> _run(Future<void> Function() action) async {
    setState(() => _isLoading = true);
    try {
      await action();
      return true;
    } catch (e) {
      if (mounted) _showMessage(AuthService.errorMessage(e), isError: true);
      return false;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendCode({bool isResend = false}) async {
    if (!isResend && !_formKey.currentState!.validate()) return;

    String message = '';
    final ok = await _run(() async {
      message = await _authService.requestPasswordReset(_email);
    });
    if (!ok || !mounted) return;

    _codeController.clear();
    _startResendCooldown();
    setState(() => _step = _ResetStep.code);
    _showMessage(isResend ? 'A new code has been sent.' : message);
  }

  Future<void> _verifyCode() async {
    if (!_formKey.currentState!.validate()) return;

    final ok = await _run(() => _authService.verifyPasswordResetCode(_email, _codeController.text));
    if (ok && mounted) setState(() => _step = _ResetStep.newPassword);
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    final ok = await _run(() => _authService.confirmPasswordReset(
          email: _email,
          code: _codeController.text,
          newPassword: _passwordController.text,
          newPassword2: _password2Controller.text,
        ));
    if (ok && mounted) {
      _showMessage('Password reset successful! Please log in with your new password.');
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = switch (_step) {
      _ResetStep.email => (
          'Forgot your password?',
          "Enter the email linked to your account and we'll send you a 6-digit code.",
        ),
      _ResetStep.code => (
          'Check your email',
          'Enter the 6-digit code we sent to $_email. It expires in 10 minutes.',
        ),
      _ResetStep.newPassword => (
          'Create a new password',
          "Choose a strong password you haven't used before.",
        ),
    };

    return AuthLayout(
      title: title,
      subtitle: subtitle,
      showBackButton: true,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStepIndicator(),
            const SizedBox(height: 24),
            ..._buildStepFields(),
            const SizedBox(height: 24),
            AuthSubmitButton(
              label: switch (_step) {
                _ResetStep.email => 'Send Code',
                _ResetStep.code => 'Verify Code',
                _ResetStep.newPassword => 'Reset Password',
              },
              isLoading: _isLoading,
              onPressed: switch (_step) {
                _ResetStep.email => _sendCode,
                _ResetStep.code => _verifyCode,
                _ResetStep.newPassword => _resetPassword,
              },
            ),
            const SizedBox(height: 12),
            ..._buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    const labels = ['Email', 'Code', 'New password'];
    final primary = Theme.of(context).colorScheme.primary;

    return Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < labels.length - 1 ? 8 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: i <= _step.index ? primary : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: i == _step.index ? FontWeight.w600 : FontWeight.normal,
                      color: i <= _step.index ? primary : Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _buildStepFields() {
    switch (_step) {
      case _ResetStep.email:
        return [
          CustomTextFormField(
            controller: _emailController,
            labelText: 'Email',
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            onFieldSubmitted: (_) => _sendCode(),
            validator: (value) {
              if (value!.trim().isEmpty) return 'Please enter your email';
              if (!RegExp(r'\S+@\S+\.\S+').hasMatch(value.trim())) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),
        ];
      case _ResetStep.code:
        return [
          TextFormField(
            controller: _codeController,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 12),
            decoration: InputDecoration(
              hintText: '------',
              counterText: '',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (value) =>
                value!.length != 6 ? 'Please enter the 6-digit code' : null,
            onFieldSubmitted: (_) => _verifyCode(),
          ),
        ];
      case _ResetStep.newPassword:
        return [
          PasswordFormField(
            controller: _passwordController,
            labelText: 'New Password',
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            onChanged: (_) => setState(() {}), // Refresh the strength bar
            validator: (value) =>
                value!.length < 8 ? 'Password must be at least 8 characters' : null,
          ),
          PasswordStrengthIndicator(password: _passwordController.text),
          const SizedBox(height: 16),
          PasswordFormField(
            controller: _password2Controller,
            labelText: 'Confirm New Password',
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _resetPassword(),
            validator: (value) =>
                value != _passwordController.text ? 'Passwords do not match' : null,
          ),
        ];
    }
  }

  List<Widget> _buildFooter() {
    switch (_step) {
      case _ResetStep.email:
      case _ResetStep.newPassword:
        return [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Back to Login'),
          ),
        ];
      case _ResetStep.code:
        return [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Didn't get the code?"),
              TextButton(
                onPressed: _resendSecondsLeft > 0 || _isLoading
                    ? null
                    : () => _sendCode(isResend: true),
                child: Text(_resendSecondsLeft > 0
                    ? 'Resend in ${_resendSecondsLeft}s'
                    : 'Resend Code'),
              ),
            ],
          ),
          TextButton(
            onPressed: _isLoading
                ? null
                : () => setState(() => _step = _ResetStep.email),
            child: const Text('Use a different email'),
          ),
        ];
    }
  }
}
