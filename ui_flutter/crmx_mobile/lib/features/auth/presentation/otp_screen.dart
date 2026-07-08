import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../domain/auth_state.dart';
import 'auth_controller.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({
    required this.phoneNumber,
    super.key,
  });

  final String phoneNumber;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _otpController = TextEditingController();
  bool _isLoading = false;
  bool _canResend = false;
  int _resendCountdown = AppConfig.otpResendDelay.inSeconds;

  @override
  void initState() {
    super.initState();
    _startResendCountdown();
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  void _startResendCountdown() {
    setState(() {
      _canResend = false;
      _resendCountdown = AppConfig.otpResendDelay.inSeconds;
    });

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _resendCountdown > 0) {
        setState(() {
          _resendCountdown--;
        });
        _startResendCountdown();
      } else if (mounted) {
        setState(() {
          _canResend = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next is Authenticated) {
        // Successfully authenticated, pop back to app (will be handled by app.dart)
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else if (next is AuthError) {
        // Show error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.message),
            backgroundColor: Colors.red,
          ),
        );
      }

      // Update loading state
      setState(() {
        _isLoading = next is Authenticating;
      });
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify OTP'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Icon
              const Icon(
                Icons.message,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: 24),

              // Title
              const Text(
                'Enter Verification Code',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Phone number display
              Text(
                'We sent a code to ${widget.phoneNumber}',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // OTP input
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: AppConfig.otpLength,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                ),
                decoration: const InputDecoration(
                  hintText: '000000',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
                enabled: !_isLoading,
                onChanged: (value) {
                  if (value.length == AppConfig.otpLength) {
                    _handleVerifyOtp();
                  }
                },
              ),
              const SizedBox(height: 24),

              // Verify button
              FilledButton(
                onPressed: _isLoading ? null : _handleVerifyOtp,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Verify',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
              const SizedBox(height: 16),

              // Resend OTP
              TextButton(
                onPressed: _canResend && !_isLoading ? _handleResendOtp : null,
                child: Text(
                  _canResend
                      ? 'Resend OTP'
                      : 'Resend OTP in $_resendCountdown seconds',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleVerifyOtp() async {
    if (_otpController.text.length != AppConfig.otpLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter ${AppConfig.otpLength}-digit OTP'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await ref.read(authControllerProvider.notifier).verifyOtp(
          phoneNumber: widget.phoneNumber,
          otp: _otpController.text,
        );
  }

  Future<void> _handleResendOtp() async {
    await ref.read(authControllerProvider.notifier).sendOtp(widget.phoneNumber);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OTP resent successfully'),
          backgroundColor: Colors.green,
        ),
      );
      _startResendCountdown();
    }
  }
}
