import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../screens/terms_and_permissions_screen.dart';

/// Kayıt öncesinde gösterilen, kullanıcının izinleri ve koşulları
/// kabul etmesini gerektiren kompakt onay widget'ı.
/// 
/// Kullanım:
/// ```dart
/// final accepted = await UserConsentWidget.show(context);
/// if (accepted == true) { /* kayıt işlemi */ }
/// ```
class UserConsentWidget {
  /// Bottom sheet olarak gösterir, [true] dönerse kullanıcı kabul etmiştir.
  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (ctx) => const _ConsentSheet(),
    );
  }
}

class _ConsentSheet extends StatefulWidget {
  const _ConsentSheet();

  @override
  State<_ConsentSheet> createState() => _ConsentSheetState();
}

class _ConsentSheetState extends State<_ConsentSheet>
    with SingleTickerProviderStateMixin {
  bool _acceptedTerms = false;
  bool _acceptedPrivacy = false;
  bool _acceptedAge = false;
  bool _acceptedCommunity = false;

  bool get _canProceed =>
      _acceptedTerms && _acceptedPrivacy && _acceptedAge && _acceptedCommunity;

  late AnimationController _animController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _openFullTerms() async {
    final accepted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const TermsAndPermissionsScreen(isOnboarding: true),
      ),
    );
    if (accepted == true && mounted) {
      setState(() {
        _acceptedTerms = true;
        _acceptedPrivacy = true;
        _acceptedAge = true;
        _acceptedCommunity = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnim,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.2),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Handle ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Başlık ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Column(
                children: [
                  // İkon + Başlık
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.verified_user_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hesap Oluşturmadan Önce',
                              style: GoogleFonts.outfit(
                                color: AppColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Aşağıdaki koşulları onaylamanız gerekmektedir',
                              style: GoogleFonts.outfit(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── Tam Belgeleri Gör Butonu ─────────────────────────────
                  GestureDetector(
                    onTap: _openFullTerms,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withOpacity(0.15),
                            AppColors.secondary.withOpacity(0.08),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.open_in_new_rounded,
                              color: AppColors.primaryVariant, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tüm Belgeler & İzinler',
                                  style: GoogleFonts.outfit(
                                    color: AppColors.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  'EULA · Gizlilik · İzin Merkezi · Topluluk Kuralları',
                                  style: GoogleFonts.outfit(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Oku',
                              style: GoogleFonts.outfit(
                                color: AppColors.primaryVariant,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),

            // ── Onay Kutuları ───────────────────────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.background.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Column(
                children: [
                  _ConsentCheckbox(
                    value: _acceptedAge,
                    icon: Icons.cake_rounded,
                    iconColor: const Color(0xFFEC4899),
                    label: '18 yaşında veya daha büyüğüm',
                    sublabel: 'Yaşımı yanlış beyan etmeyeceğimi taahhüt ediyorum',
                    onChanged: (v) => setState(() => _acceptedAge = v!),
                    isFirst: true,
                  ),
                  _buildConsentDivider(),
                  _ConsentCheckbox(
                    value: _acceptedTerms,
                    icon: Icons.gavel_rounded,
                    iconColor: const Color(0xFF8B5CF6),
                    label: 'Kullanım Koşullarını (EULA) okudum ve kabul ediyorum',
                    sublabel: 'Platformun kural ve yükümlülüklerini anladım',
                    onChanged: (v) => setState(() => _acceptedTerms = v!),
                  ),
                  _buildConsentDivider(),
                  _ConsentCheckbox(
                    value: _acceptedPrivacy,
                    icon: Icons.shield_rounded,
                    iconColor: const Color(0xFF06B6D4),
                    label: 'Gizlilik Politikası\'nı okudum ve kabul ediyorum',
                    sublabel: 'Kişisel verilerimin nasıl işlendiğini anladım',
                    onChanged: (v) => setState(() => _acceptedPrivacy = v!),
                  ),
                  _buildConsentDivider(),
                  _ConsentCheckbox(
                    value: _acceptedCommunity,
                    icon: Icons.people_rounded,
                    iconColor: const Color(0xFF10B981),
                    label: 'Topluluk Kurallarına uymayı kabul ediyorum',
                    sublabel: 'Saygılı ve güvenli bir ortam için kural ihlali yapmayacağım',
                    onChanged: (v) => setState(() => _acceptedCommunity = v!),
                    isLast: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Aksiyon Butonları ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Row(
                children: [
                  // İptal
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: AppColors.error.withOpacity(0.4)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        'İptal',
                        style: GoogleFonts.outfit(
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Devam Et
                  Expanded(
                    flex: 2,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: _canProceed
                            ? AppColors.primaryGradient
                            : LinearGradient(
                                colors: [
                                  AppColors.textMuted.withOpacity(0.25),
                                  AppColors.textMuted.withOpacity(0.15),
                                ],
                              ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: _canProceed
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.5),
                                  blurRadius: 18,
                                  offset: const Offset(0, 5),
                                ),
                              ]
                            : [],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _canProceed
                            ? () => Navigator.pop(context, true)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: Icon(
                          _canProceed
                              ? Icons.check_circle_rounded
                              : Icons.lock_outline_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        label: Text(
                          'Devam Et',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
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

  Widget _buildConsentDivider() {
    return Divider(
      color: Colors.white.withOpacity(0.05),
      height: 1,
      indent: 16,
      endIndent: 16,
    );
  }
}

// ── Tekil onay kutusu bileşeni ─────────────────────────────────────────────
class _ConsentCheckbox extends StatelessWidget {
  final bool value;
  final IconData icon;
  final Color iconColor;
  final String label;
  final String sublabel;
  final ValueChanged<bool?> onChanged;
  final bool isFirst;
  final bool isLast;

  const _ConsentCheckbox({
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.sublabel,
    required this.onChanged,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.vertical(
        top: isFirst ? const Radius.circular(20) : Radius.zero,
        bottom: isLast ? const Radius.circular(20) : Radius.zero,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: value ? iconColor.withOpacity(0.06) : Colors.transparent,
          borderRadius: BorderRadius.vertical(
            top: isFirst ? const Radius.circular(20) : Radius.zero,
            bottom: isLast ? const Radius.circular(20) : Radius.zero,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // İkon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(value ? 0.2 : 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            // Metin
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.outfit(
                      color: value ? Colors.white : AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sublabel,
                    style: GoogleFonts.outfit(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Checkbox
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: value ? iconColor : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: value ? iconColor : Colors.white.withOpacity(0.2),
                  width: 1.5,
                ),
                boxShadow: value
                    ? [
                        BoxShadow(
                          color: iconColor.withOpacity(0.4),
                          blurRadius: 8,
                          spreadRadius: 0,
                        )
                      ]
                    : [],
              ),
              child: value
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 14)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
