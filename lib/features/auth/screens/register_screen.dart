import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../../events/services/mock_event_service.dart';
import '../../../core/constants/app_colors.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  DateTime? _selectedDate;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('tr_TR', null);
  }

  String _formatDate(DateTime date) {
    try {
      return DateFormat('d MMMM yyyy', 'tr_TR').format(date);
    } catch (_) {
      return DateFormat('dd.MM.yyyy').format(date);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  int _calculateAge(DateTime birthDate) {
    DateTime currentDate = DateTime.now();
    int age = currentDate.year - birthDate.year;
    int month1 = currentDate.month;
    int month2 = birthDate.month;
    if (month2 > month1) {
      age--;
    } else if (month1 == month2) {
      int day1 = currentDate.day;
      int day2 = birthDate.day;
      if (day2 > day1) {
        age--;
      }
    }
    return age;
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showModernDatePicker() {
    DateTime tempDate = _selectedDate ??
        DateTime.now().subtract(const Duration(days: 365 * 20));
    int pickerKey = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.75),
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final int age = _calculateAge(tempDate);
            final bool isEligible = age >= 18;
            final int currentYear = DateTime.now().year;
            final List<int> quickAges = [18, 20, 22, 25, 28, 30, 35, 40];

            return Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 25,
                    spreadRadius: 5,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 14,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Handle Bar
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.textMuted.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Sheet Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            Icons.cake_rounded,
                            color: AppColors.primaryVariant,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Doğum Tarihinizi Seçin',
                                style: GoogleFonts.outfit(
                                  color: AppColors.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'EventMatch için 18 yaş ve üzeri olmalısınız',
                                style: GoogleFonts.outfit(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: AppColors.textMuted, size: 22),
                          onPressed: () => Navigator.pop(context),
                          splashRadius: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Live Date & Age Card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.background.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isEligible
                              ? AppColors.success.withOpacity(0.4)
                              : AppColors.error.withOpacity(0.4),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Seçilen Tarih',
                                  style: GoogleFonts.outfit(
                                    color: AppColors.textMuted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _formatDate(tempDate),
                                  style: GoogleFonts.outfit(
                                    color: AppColors.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isEligible
                                  ? AppColors.success.withOpacity(0.18)
                                  : AppColors.error.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isEligible
                                    ? AppColors.success.withOpacity(0.5)
                                    : AppColors.error.withOpacity(0.5),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isEligible
                                      ? Icons.check_circle_rounded
                                      : Icons.warning_amber_rounded,
                                  color: isEligible ? AppColors.success : AppColors.error,
                                  size: 15,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  isEligible
                                      ? '$age Yaşında (Uygun)'
                                      : '$age Yaşında (18+ Gerekli)',
                                  style: GoogleFonts.outfit(
                                    color: isEligible ? AppColors.success : AppColors.error,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Quick Year Jump Chips
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 2, bottom: 8),
                          child: Text(
                            'Hızlı Yıl Seçimi',
                            style: GoogleFonts.outfit(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: quickAges.map((targetAge) {
                              final targetYear = currentYear - targetAge;
                              final bool isSelected = tempDate.year == targetYear;

                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      setModalState(() {
                                        final maxDays = DateUtils.getDaysInMonth(targetYear, tempDate.month);
                                        final validDay = tempDate.day > maxDays ? maxDays : tempDate.day;
                                        tempDate = DateTime(targetYear, tempDate.month, validDay);
                                        pickerKey++;
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 180),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                      decoration: BoxDecoration(
                                        gradient: isSelected ? AppColors.primaryGradient : null,
                                        color: isSelected ? null : AppColors.surfaceLight,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected
                                              ? AppColors.primaryVariant
                                              : Colors.white.withOpacity(0.08),
                                          width: isSelected ? 1.5 : 1,
                                        ),
                                      ),
                                      child: Text(
                                        '$targetYear ($targetAge Yaş)',
                                        style: GoogleFonts.outfit(
                                          color: isSelected ? Colors.white : AppColors.textSecondary,
                                          fontSize: 12,
                                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Modern Cupertino Wheel Picker
                    Container(
                      height: 180,
                      decoration: BoxDecoration(
                        color: AppColors.background.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                      child: CupertinoTheme(
                        data: CupertinoThemeData(
                          brightness: Brightness.dark,
                          textTheme: CupertinoTextThemeData(
                            dateTimePickerTextStyle: GoogleFonts.outfit(
                              color: AppColors.textPrimary,
                              fontSize: 19,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        child: CupertinoDatePicker(
                          key: ValueKey(pickerKey),
                          mode: CupertinoDatePickerMode.date,
                          dateOrder: DatePickerDateOrder.dmy,
                          initialDateTime: tempDate,
                          minimumDate: DateTime(1940, 1, 1),
                          maximumDate: DateTime.now(),
                          onDateTimeChanged: (DateTime newDate) {
                            setModalState(() {
                              tempDate = newDate;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Confirm Action Button
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: isEligible ? AppColors.primaryGradient : null,
                        color: isEligible ? null : AppColors.surfaceLight,
                        boxShadow: isEligible
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.35),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          if (!isEligible) {
                            HapticFeedback.heavyImpact();
                            _showSnackBar(
                              'EventMatch\'e katılabilmek için en az 18 yaşında olmalısınız.',
                              isError: true,
                            );
                            return;
                          }

                          HapticFeedback.mediumImpact();
                          setState(() {
                            _selectedDate = tempDate;
                          });
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isEligible ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
                              color: isEligible ? Colors.white : AppColors.textMuted,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isEligible ? 'Tarihi Onayla & Devam Et' : 'En Az 18 Yaşında Olmalısınız',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isEligible ? Colors.white : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _register() async {
    if (_nameController.text.trim().isEmpty ||
        _usernameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty ||
        _selectedDate == null) {
      _showSnackBar('Lütfen tüm alanları doldurun.', isError: true);
      return;
    }

    final age = _calculateAge(_selectedDate!);
    if (age < 18) {
      _showSnackBar('EventMatch kullanabilmek için 18 yaşından büyük olmalısınız.', isError: true);
      return;
    }

    final cleanUsername = _usernameController.text.trim().toLowerCase().replaceAll('@', '');
    if (cleanUsername.length < 3) {
      _showSnackBar('Kullanıcı adı en az 3 karakter olmalıdır.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    final authService = context.read<AuthService>();
    
    try {
      final success = await authService.register(
        _nameController.text.trim(),
        _usernameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text,
        _selectedDate!,
      );

      if (success) {
        final prefs = await SharedPreferences.getInstance();
        final userId = authService.currentUserId ?? 'user_1';
        await prefs.setString('${userId}_userBirthDate', _selectedDate!.toIso8601String());
        await prefs.setString('${userId}_userName', _nameController.text.trim());
        await prefs.setString('${userId}_userUsername', _usernameController.text.trim());
        if (mounted) {
          context.read<MockEventService>().loadUserProfile();
          _showSnackBar('Kayıt başarılı! Aramıza hoş geldiniz.');
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
          _showSnackBar('Kayıt başarısız. Lütfen tekrar deneyin.', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar(e.toString().replaceAll('Exception: ', ''), isError: true);
      }
    }
  }

  void _loginWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      await context.read<AuthService>().signInWithGoogle();
    } catch (e) {
      if (mounted) {
        _showSnackBar(e.toString().replaceAll('Exception: ', ''), isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _loginWithApple() async {
    setState(() => _isLoading = true);
    try {
      await context.read<AuthService>().signInWithApple();
    } catch (e) {
      if (mounted) {
        _showSnackBar(e.toString().replaceAll('Exception: ', ''), isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final int? calculatedAge = _selectedDate != null ? _calculateAge(_selectedDate!) : null;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            // Ambient Background Orbs
            Positioned(
              top: -size.width * 0.2,
              left: -size.width * 0.2,
              child: Container(
                width: size.width * 0.85,
                height: size.width * 0.85,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.secondary.withOpacity(0.35),
                      AppColors.secondary.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -size.width * 0.3,
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
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                child: Container(color: Colors.transparent),
              ),
            ),

            // Content Body
            SafeArea(
              child: Column(
                children: [
                  // Top Glass Bar with Back Button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.surface.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white.withOpacity(0.1)),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                          ),
                          child: Text(
                            'YENİ HESAP',
                            style: GoogleFonts.outfit(
                              color: AppColors.primaryVariant,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 48), // Spacer to balance back button
                      ],
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 10),

                          // Header Avatar Badge
                          Center(
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [AppColors.secondary, AppColors.primary],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.secondary.withOpacity(0.4),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.person_add_alt_1_rounded,
                                color: Colors.white,
                                size: 36,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          Text(
                            'Aramıza Katıl',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Hesabını oluştur ve çevrendeki tüm harika etkinlikleri keşfetmeye başla.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Form Glass Container
                          ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: Container(
                              padding: const EdgeInsets.all(24.0),
                              decoration: BoxDecoration(
                                color: AppColors.surface.withOpacity(0.65),
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.08),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 30,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Name Field
                                  TextField(
                                    controller: _nameController,
                                    keyboardType: TextInputType.name,
                                    style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 15),
                                    decoration: InputDecoration(
                                      labelText: 'İsim Soyisim',
                                      prefixIcon: Icon(
                                        Icons.person_outline_rounded,
                                        color: AppColors.primaryVariant,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Username Field
                                  TextField(
                                    controller: _usernameController,
                                    keyboardType: TextInputType.text,
                                    style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 15),
                                    decoration: InputDecoration(
                                      labelText: 'Kullanıcı Adı',
                                      prefixIcon: Icon(
                                        Icons.alternate_email_rounded,
                                        color: AppColors.primaryVariant,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Date of Birth Picker Button
                                  GestureDetector(
                                    onTap: _showModernDatePicker,
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: AppColors.surface,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: _selectedDate != null 
                                              ? (calculatedAge != null && calculatedAge >= 18 
                                                  ? AppColors.primary.withOpacity(0.6) 
                                                  : AppColors.error.withOpacity(0.6))
                                              : Colors.white.withOpacity(0.06),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: _selectedDate != null
                                                  ? AppColors.primary.withOpacity(0.15)
                                                  : AppColors.surfaceLight,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Icon(
                                              _selectedDate != null ? Icons.cake_rounded : Icons.calendar_today_rounded,
                                              color: _selectedDate != null ? AppColors.primaryVariant : AppColors.textMuted,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Doğum Tarihi',
                                                  style: GoogleFonts.outfit(
                                                    color: AppColors.textSecondary,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  _selectedDate == null 
                                                      ? 'Gün / Ay / Yıl Seçin' 
                                                      : _formatDate(_selectedDate!),
                                                  style: GoogleFonts.outfit(
                                                    color: _selectedDate == null ? AppColors.textMuted : AppColors.textPrimary,
                                                    fontSize: 15,
                                                    fontWeight: _selectedDate == null ? FontWeight.w400 : FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (calculatedAge != null) ...[
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: calculatedAge >= 18 
                                                    ? AppColors.success.withOpacity(0.15) 
                                                    : AppColors.error.withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: calculatedAge >= 18 
                                                      ? AppColors.success.withOpacity(0.4) 
                                                      : AppColors.error.withOpacity(0.4),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    calculatedAge >= 18 ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                                                    color: calculatedAge >= 18 ? AppColors.success : AppColors.error,
                                                    size: 14,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '$calculatedAge Yaş',
                                                    style: GoogleFonts.outfit(
                                                      color: calculatedAge >= 18 ? AppColors.success : AppColors.error,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ] else ...[
                                            Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: AppColors.surfaceLight,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                Icons.expand_more_rounded,
                                                color: AppColors.textMuted,
                                                size: 20,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Email Field
                                  TextField(
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 15),
                                    decoration: InputDecoration(
                                      labelText: 'E-posta',
                                      prefixIcon: Icon(
                                        Icons.email_outlined,
                                        color: AppColors.primaryVariant,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Password Field
                                  TextField(
                                    controller: _passwordController,
                                    obscureText: _obscurePassword,
                                    style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 15),
                                    decoration: InputDecoration(
                                      labelText: 'Şifre',
                                      prefixIcon: Icon(
                                        Icons.lock_outline_rounded,
                                        color: AppColors.primaryVariant,
                                        size: 22,
                                      ),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                          color: AppColors.textSecondary,
                                          size: 22,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _obscurePassword = !_obscurePassword;
                                          });
                                        },
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 28),

                                  // Gradient Register Button
                                  Container(
                                    height: 54,
                                    decoration: BoxDecoration(
                                      gradient: AppColors.primaryGradient,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primary.withOpacity(0.4),
                                          blurRadius: 18,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      onPressed: _isLoading ? null : _register,
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
                                                color: Colors.white,
                                                strokeWidth: 2.5,
                                              ),
                                            )
                                          : Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  'KAYIT OL',
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: 1.1,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                const Icon(
                                                  Icons.check_rounded,
                                                  color: Colors.white,
                                                  size: 20,
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Social Sign-In Divider
                          Row(
                            children: [
                              Expanded(child: Divider(color: Colors.white.withOpacity(0.12), thickness: 1)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                child: Text(
                                  'veya sosyal hesap ile',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ),
                              Expanded(child: Divider(color: Colors.white.withOpacity(0.12), thickness: 1)),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // Social Auth Buttons Row
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _isLoading ? null : _loginWithGoogle,
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: AppColors.surface.withOpacity(0.5),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    side: BorderSide(color: Colors.white.withOpacity(0.1)),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  icon: const FaIcon(
                                    FontAwesomeIcons.google,
                                    size: 18,
                                    color: Color(0xFFEA4335),
                                  ),
                                  label: Text(
                                    'Google',
                                    style: GoogleFonts.outfit(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _isLoading ? null : _loginWithApple,
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: AppColors.surface.withOpacity(0.5),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    side: BorderSide(color: Colors.white.withOpacity(0.1)),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  icon: const FaIcon(
                                    FontAwesomeIcons.apple,
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                  label: Text(
                                    'Apple',
                                    style: GoogleFonts.outfit(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 28),

                          // Already have account Link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Zaten hesabın var mı?',
                                style: GoogleFonts.outfit(
                                  color: AppColors.textSecondary,
                                  fontSize: 15,
                                ),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: ShaderMask(
                                  shaderCallback: (bounds) => AppColors.primaryGradient.createShader(bounds),
                                  child: Text(
                                    'Giriş Yap',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

