import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String? initialEmail;
  final bool isFromRecoveryLink;

  const ForgotPasswordScreen({
    super.key,
    this.initialEmail,
    this.isFromRecoveryLink = false,
  });

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isCodeSent = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;
  String? _successMessage;

  Timer? _resendTimer;
  int _resendCountdown = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null && widget.initialEmail!.isNotEmpty) {
      _emailController.text = widget.initialEmail!;
    }
    if (widget.isFromRecoveryLink || Supabase.instance.client.auth.currentSession != null) {
      _isCodeSent = true;
      _successMessage = 'Kurtarma bağlantınız doğrulandı! Lütfen yeni şifrenizi belirleyin.';
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() {
      _resendCountdown = 60;
    });
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCountdown <= 1) {
        timer.cancel();
        setState(() {
          _resendCountdown = 0;
        });
      } else {
        setState(() {
          _resendCountdown--;
        });
      }
    });
  }

  Future<void> _handleSendResetLink() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _errorMessage = 'Lütfen geçerli bir e-posta adresi girin.';
        _successMessage = null;
      });
      return;
    }

    if (_resendCountdown > 0) {
      setState(() {
        _errorMessage = 'Yeni kod talep etmek için lütfen $_resendCountdown saniye bekleyin.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final authService = context.read<AuthService>();
    final error = await authService.sendPasswordResetEmail(email);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (error != null) {
        _errorMessage = error;
      } else {
        _isCodeSent = true;
        _startResendTimer();
        _successMessage = 'Şifre sıfırlama talebi gönderildi! Lütfen e-posta gelen kutunuzu (ve Spam klasörünü) kontrol edin.';
      }
    });
  }

  Future<void> _handleResetPassword() async {
    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (newPassword.length < 6) {
      setState(() {
        _errorMessage = 'Yeni şifreniz en az 6 karakter olmalıdır.';
      });
      return;
    }

    if (newPassword != confirmPassword) {
      setState(() {
        _errorMessage = 'Şifreler birbiriyle eşleşmiyor.';
      });
      return;
    }

    final hasRecoverySession = Supabase.instance.client.auth.currentSession != null;

    if (otp.isEmpty && !widget.isFromRecoveryLink && !hasRecoverySession) {
      setState(() {
        _errorMessage = 'Lütfen e-postanıza gelen 6 haneli kodu girin veya e-postanızdaki bağlantıya tıklayın.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final authService = context.read<AuthService>();
    String? error;

    if (hasRecoverySession && (widget.isFromRecoveryLink || otp.isEmpty)) {
      // E-postadaki linke tıklandıysa oturum zaten açılmıştır, şifreyi doğrudan güncelle
      error = await authService.updatePassword(newPassword);
    } else {
      // 6 Haneli OTP kodu veya bypass ile doğrulama yap ve şifreyi güncelle
      error = await authService.verifyOtpAndResetPassword(
        email: email,
        token: otp,
        newPassword: newPassword,
      );
    }

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (error != null) {
      setState(() {
        _errorMessage = error;
      });
    } else {
      // Success modal
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: Colors.green, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                'Şifreniz Güncellendi',
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: Text(
            'Şifreniz başarıyla değiştirildi. Yeni şifrenizle giriş yapabilirsiniz.',
            style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 14),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Giriş Yap',
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final hasRecoverySession = Supabase.instance.client.auth.currentSession != null || widget.isFromRecoveryLink;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background Gradient Orbs
          Positioned(
            top: -size.width * 0.3,
            right: -size.width * 0.2,
            child: Container(
              width: size.width * 0.9,
              height: size.width * 0.9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.35),
                    AppColors.primary.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -size.width * 0.3,
            left: -size.width * 0.2,
            child: Container(
              width: size.width * 0.85,
              height: size.width * 0.85,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.secondary.withOpacity(0.3),
                    AppColors.secondary.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
              child: Container(color: Colors.transparent),
            ),
          ),

          // Main Content
          SafeArea(
            child: Column(
              children: [
                // Top App Bar with back button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Şifre Kurtarma',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Lock Icon
                          Center(
                            child: Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(22),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.4),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Icon(
                                _isCodeSent ? Icons.mark_email_read_rounded : Icons.lock_reset_rounded,
                                color: Colors.white,
                                size: 38,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Title
                          Text(
                            _isCodeSent ? 'Yeni Şifre Belirleyin' : 'Şifrenizi mi Unuttunuz?',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            hasRecoverySession
                                ? 'E-postanızdaki bağlantı doğrulandı. Yeni şifrenizi belirleyin.'
                                : _isCodeSent
                                    ? 'E-postanıza gelen 6 haneli kodu veya e-postanızdaki sıfırlama bağlantısını kullanabilirsiniz.'
                                    : 'Hesabınıza kayıtlı e-posta adresinizi girin. Size sıfırlama bağlantısı ve kodu göndereceğiz.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Glass Container Form
                          ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Container(
                              padding: const EdgeInsets.all(22.0),
                              decoration: BoxDecoration(
                                color: AppColors.surface.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.08),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 25,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Error Message Box
                                  if (_errorMessage != null) ...[
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              _errorMessage!,
                                              style: GoogleFonts.outfit(color: Colors.redAccent, fontSize: 13),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],

                                  // Success Message Box
                                  if (_successMessage != null) ...[
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.check_circle_outline_rounded, color: Colors.greenAccent, size: 20),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              _successMessage!,
                                              style: GoogleFonts.outfit(color: Colors.greenAccent, fontSize: 13),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],

                                  // Email Field
                                  TextField(
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 15),
                                    decoration: InputDecoration(
                                      labelText: 'E-posta Adresi',
                                      prefixIcon: Icon(
                                        Icons.email_outlined,
                                        color: AppColors.primaryVariant,
                                        size: 22,
                                      ),
                                    ),
                                  ),

                                  if (!_isCodeSent) ...[
                                    const SizedBox(height: 24),
                                    // Send Code Button
                                    Container(
                                      height: 52,
                                      decoration: BoxDecoration(
                                        gradient: AppColors.primaryGradient,
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primary.withOpacity(0.4),
                                            blurRadius: 16,
                                            offset: const Offset(0, 5),
                                          ),
                                        ],
                                      ),
                                      child: ElevatedButton(
                                        onPressed: _isLoading ? null : _handleSendResetLink,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          shadowColor: Colors.transparent,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                        ),
                                        child: _isLoading
                                            ? const SizedBox(
                                                height: 22,
                                                width: 22,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2.5,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : Text(
                                                'Sıfırlama Bağlantısı ve Kodu Gönder',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white,
                                                ),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Center(
                                      child: TextButton(
                                        onPressed: () {
                                          setState(() {
                                            _isCodeSent = true;
                                            _errorMessage = null;
                                            _successMessage = null;
                                          });
                                        },
                                        child: Text(
                                          'Zaten bir kodum veya bağlantım var',
                                          style: GoogleFonts.outfit(
                                            color: AppColors.primaryVariant,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ] else ...[
                                    const SizedBox(height: 16),

                                    // OTP Code Field (If session is already verified from email link, show verified indicator)
                                    if (hasRecoverySession) ...[
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.blue.withOpacity(0.3)),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.link_rounded, color: Colors.blueAccent, size: 20),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                'E-posta bağlantısı aktif. Kod girmenize gerek yoktur.',
                                                style: GoogleFonts.outfit(color: Colors.blueAccent, fontSize: 13),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ] else ...[
                                      TextField(
                                        controller: _otpController,
                                        keyboardType: TextInputType.number,
                                        maxLength: 8,
                                        style: GoogleFonts.outfit(
                                          color: AppColors.textPrimary,
                                          fontSize: 18,
                                          letterSpacing: 4,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        decoration: InputDecoration(
                                          counterText: '',
                                          labelText: '6 Haneli Kurtarma Kodu',
                                          prefixIcon: Icon(
                                            Icons.pin_rounded,
                                            color: AppColors.primaryVariant,
                                            size: 22,
                                          ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 16),

                                    // New Password Field
                                    TextField(
                                      controller: _newPasswordController,
                                      obscureText: _obscurePassword,
                                      style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 15),
                                      decoration: InputDecoration(
                                        labelText: 'Yeni Şifre (en az 6 karakter)',
                                        prefixIcon: Icon(
                                          Icons.lock_outline_rounded,
                                          color: AppColors.primaryVariant,
                                          size: 22,
                                        ),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                            color: AppColors.textSecondary,
                                            size: 20,
                                          ),
                                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // Confirm Password Field
                                    TextField(
                                      controller: _confirmPasswordController,
                                      obscureText: _obscureConfirmPassword,
                                      style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 15),
                                      decoration: InputDecoration(
                                        labelText: 'Yeni Şifre Tekrar',
                                        prefixIcon: Icon(
                                          Icons.lock_outline_rounded,
                                          color: AppColors.primaryVariant,
                                          size: 22,
                                        ),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                            color: AppColors.textSecondary,
                                            size: 20,
                                          ),
                                          onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 24),

                                    // Submit Button
                                    Container(
                                      height: 52,
                                      decoration: BoxDecoration(
                                        gradient: AppColors.primaryGradient,
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primary.withOpacity(0.4),
                                            blurRadius: 16,
                                            offset: const Offset(0, 5),
                                          ),
                                        ],
                                      ),
                                      child: ElevatedButton(
                                        onPressed: _isLoading ? null : _handleResetPassword,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          shadowColor: Colors.transparent,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                        ),
                                        child: _isLoading
                                            ? const SizedBox(
                                                height: 22,
                                                width: 22,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2.5,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : Text(
                                                'Şifremi Güncelle',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white,
                                                ),
                                              ),
                                      ),
                                    ),

                                    const SizedBox(height: 14),

                                    // Tip Banner
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.amber.withOpacity(0.25)),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 18),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'E-postadaki mavi "Reset password" bağlantısına tıklayarak da doğrudan şifrenizi yenileyebilirsiniz.',
                                              style: GoogleFonts.outfit(color: Colors.amber.shade200, fontSize: 12.5),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 10),

                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        TextButton(
                                          onPressed: _isLoading
                                              ? null
                                              : () {
                                                  setState(() {
                                                    _isCodeSent = false;
                                                    _errorMessage = null;
                                                    _successMessage = null;
                                                  });
                                                },
                                          child: Text(
                                            'E-postayı Değiştir',
                                            style: GoogleFonts.outfit(
                                              color: AppColors.textMuted,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: (_isLoading || _resendCountdown > 0) ? null : _handleSendResetLink,
                                          child: Text(
                                            _resendCountdown > 0 ? 'Tekrar Gönder (${_resendCountdown}s)' : 'Tekrar Gönder',
                                            style: GoogleFonts.outfit(
                                              color: _resendCountdown > 0 ? AppColors.textMuted : AppColors.primaryVariant,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Back to login button
                          Center(
                            child: TextButton.icon(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.arrow_back_rounded, size: 18, color: Colors.white70),
                              label: Text(
                                'Giriş Ekranına Dön',
                                style: GoogleFonts.outfit(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
