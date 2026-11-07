import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../core/constants/api_constants.dart';
import '../../l10n/app_localizations.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final ApiService apiService;

  const ForgotPasswordScreen({super.key, required this.apiService});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  int _currentStep = 1; // 1: Enter email, 2: Enter code & new password
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Please enter your registered email address.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final resp = await widget.apiService.post(ApiConstants.forgotPassword, {'email': email});

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (resp.success) {
        // Pre-fill recovery code if returned for developer/tester convenience
        if (resp.data is Map && resp.data['recovery_code'] != null) {
          _codeController.text = resp.data['recovery_code'].toString();
        }
        setState(() {
          _currentStep = 2;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(resp.message.isNotEmpty
                ? resp.message
                : 'Verification code generated and sent!'),
            backgroundColor: const Color(0xFF0D6B4F),
          ),
        );
      } else {
        setState(() => _errorMessage = resp.message);
      }
    }
  }

  Future<void> _submitReset() async {
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (code.isEmpty) {
      setState(() => _errorMessage = 'Please enter the 6-digit verification code.');
      return;
    }
    if (password.length < 8) {
      setState(() => _errorMessage = 'Password must be at least 8 characters long.');
      return;
    }
    if (password != confirm) {
      setState(() => _errorMessage = 'Password confirmation does not match.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final resp = await widget.apiService.post(ApiConstants.resetPassword, {
      'email': email,
      'token': code,
      'password': password,
      'password_confirmation': confirm,
    });

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (resp.success) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.check_circle_outline, color: Color(0xFF0D6B4F), size: 48),
            title: const Text('Password Reset Successful'),
            content: const Text('Your account password has been updated. You can now log in with your new credentials.'),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D6B4F),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Proceed to Login'),
              ),
            ],
          ),
        );
      } else {
        setState(() => _errorMessage = resp.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentStep == 1 ? loc.t('forgot_password') : 'Reset Password'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: const Color(0xFF0D6B4F).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _currentStep == 1 ? Icons.lock_reset : Icons.shield_outlined,
                  size: 36,
                  color: const Color(0xFF0D6B4F),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _currentStep == 1
                  ? 'Recover Your Account'
                  : 'Create a New Secure Password',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            Text(
              _currentStep == 1
                  ? 'Enter your registered email address and we will generate a secure recovery code to reset your password.'
                  : 'Enter the 6-digit recovery code sent to ${_emailController.text} and your new password.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
            const SizedBox(height: 24),

            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

            if (_currentStep == 1) ...[
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: loc.t('email'),
                  hintText: 'e.g. yourname@example.com',
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                onSubmitted: (_) => _requestCode(),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _requestCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D6B4F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Send Verification Code', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ] else ...[
              TextField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: '6-Digit Verification Code',
                  hintText: 'e.g. 123456',
                  prefixIcon: Icon(Icons.pin_outlined),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  hintText: 'At least 8 characters',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  labelText: loc.t('confirm_password'),
                  hintText: 'Repeat new password',
                  prefixIcon: const Icon(Icons.lock_reset),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                onSubmitted: (_) => _submitReset(),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReset,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D6B4F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Reset Password & Complete', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _isSubmitting ? null : () => setState(() => _currentStep = 1),
                child: const Text('Back / Re-enter Email Address'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
