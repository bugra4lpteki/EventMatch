import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../services/auth_service.dart';

class TwoFactorVerificationScreen extends StatefulWidget {
  final String email;
  final VoidCallback onSuccess;
  final VoidCallback? onCancel;

  const TwoFactorVerificationScreen({
    super.key,
    required this.email,
    required this.onSuccess,
    this.onCancel,
  });

  @override
  State<TwoFactorVerificationScreen> createState() => _TwoFactorVerificationScreenState();
}

class _TwoFactorVerificationScreenState extends State<TwoFactorVerificationScreen> {
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorMessage;
  int _secondsRemaining = 60;
  Timer? _countdownTimer;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    setState(() {
      _secondsRemaining = 60;
      _canResend = false;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        if (mounted) setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
        if (mounted) setState(() => _canResend = true);
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _codeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _maskEmail(String email) {
    if (!email.contains('@')) return email;
    final parts = email.split('@');
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 2) {
      return '$name***@$domain';
    }
    return '${name[0]}***${name[name.length - 1]}@$domain';
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.length < 6) {
      setState(() => _errorMessage = 'Lütfen 6 haneli doğrulama kodunu girin.');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    final authService = context.read<AuthService>();
    final isValid = await authService.verifyTwoFactorCode(code);

    if (!mounted) return;

    if (isValid) {
      HapticFeedback.mediumImpact();
      widget.onSuccess();
    } else {
      HapticFeedback.vibrate();
      setState(() {
        _isVerifying = false;
        _errorMessage = 'Doğrulama kodu hatalı veya süresi dolmuş. Lütfen e-postanızı kontrol edip tekrar deneyin.';
      });
    }
  }

  Future<void> _resendCode() async {
    if (!_canResend || _isResending) return;

    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    final authService = context.read<AuthService>();
    final error = await authService.sendTwoFactorCode(email: widget.email);

    if (!mounted) return;

    setState(() {
      _isResending = false;
    });

    if (error != null) {
      setState(() {
        _errorMessage = error;
      });
    } else {
      _startTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.mark_email_read_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Yeni doğrulama kodu ${widget.email} adresine gönderildi. Lütfen gelen kutunuzu kontrol edin.',
                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF38BDF8),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void _handleCancel() {
    final authService = context.read<AuthService>();
    authService.cancelTwoFactor();
    if (widget.onCancel != null) {
      widget.onCancel!();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleCancel();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF08080C),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            tooltip: 'Giriş Ekranına Dön',
            onPressed: _handleCancel,
          ),
          title: Text(
            'Güvenlik Doğrulaması',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 24),

                        // Glowing Shield Icon
                        Center(
                          child: Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF38BDF8).withValues(alpha: 0.25),
                                  AppColors.primary.withValues(alpha: 0.2),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              border: Border.all(
                                color: const Color(0xFF38BDF8).withValues(alpha: 0.5),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF38BDF8).withValues(alpha: 0.25),
                                  blurRadius: 24,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.verified_user_rounded,
                              size: 46,
                              color: Color(0xFF38BDF8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Title
                        Text(
                          '2 Adımlı Doğrulama',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),

                        // Instructions with masked email
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: GoogleFonts.outfit(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                                height: 1.5,
                              ),
                              children: [
                                const TextSpan(text: 'Hesap güvenliğiniz için '),
                                TextSpan(
                                  text: _maskEmail(widget.email),
                                  style: const TextStyle(
                                    color: Color(0xFF38BDF8),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const TextSpan(
                                  text: ' adresinize 6 haneli bir doğrulama kodu gönderildi.\nLütfen gelen kutunuzu (ve gereksiz/spam klasörünü) kontrol edin.',
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 36),

                        // OTP Code Input Box
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _errorMessage != null
                                  ? AppColors.error
                                  : const Color(0xFF38BDF8).withValues(alpha: 0.5),
                              width: 1.8,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (_errorMessage != null ? AppColors.error : const Color(0xFF38BDF8))
                                    .withValues(alpha: 0.12),
                                blurRadius: 18,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _codeController,
                            focusNode: _focusNode,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 16,
                            ),
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: InputDecoration(
                              counterText: '',
                              hintText: '••••••',
                              hintStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.2),
                                letterSpacing: 16,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                            ),
                            onChanged: (val) {
                              if (_errorMessage != null) {
                                setState(() => _errorMessage = null);
                              }
                              if (val.length == 6) {
                                _verifyCode();
                              }
                            },
                          ),
                        ),

                        // Error Banner if invalid
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: GoogleFonts.outfit(color: AppColors.error, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Resend countdown or button
                        Center(
                          child: _canResend
                              ? TextButton.icon(
                                  onPressed: _isResending ? null : _resendCode,
                                  icon: _isResending
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38BDF8)),
                                        )
                                      : const Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF38BDF8)),
                                  label: Text(
                                    'Kodu Tekrar Gönder',
                                    style: GoogleFonts.outfit(
                                      color: const Color(0xFF38BDF8),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.schedule_rounded, size: 16, color: AppColors.textSecondary),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Kodu tekrar gönder ($_secondsRemaining saniye)',
                                      style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 13),
                                    ),
                                  ],
                                ),
                        ),

                        const Spacer(),

                        const SizedBox(height: 24),

                        // Verify & Login Button
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF38BDF8), Color(0xFF0284C7)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
                                  blurRadius: 18,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _isVerifying ? null : _verifyCode,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: _isVerifying
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                    )
                                  : Text(
                                      'Doğrula ve Giriş Yap',
                                      style: GoogleFonts.outfit(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Cancel Button
                        TextButton(
                          onPressed: _handleCancel,
                          child: Text(
                            'Giriş Yapmaktan Vazgeç',
                            style: GoogleFonts.outfit(
                              color: AppColors.textSecondary,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
