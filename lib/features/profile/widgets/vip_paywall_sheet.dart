import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/ios_in_app_purchase_service.dart';
import '../../../core/utils/url_launcher_helper.dart';
import '../../events/services/mock_event_service.dart';

enum VipFeature {
  seeLikes,
  undoSwipe,
  venueBadge,
  mapBoost,
}

class VipPaywallSheet extends StatefulWidget {
  final VipFeature? highlightedFeature;

  const VipPaywallSheet({
    super.key,
    this.highlightedFeature,
  });

  static Future<void> show(BuildContext context, {VipFeature? initialFeature}) {
    HapticFeedback.mediumImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => VipPaywallSheet(highlightedFeature: initialFeature),
    );
  }

  @override
  State<VipPaywallSheet> createState() => _VipPaywallSheetState();
}

class _VipPaywallSheetState extends State<VipPaywallSheet> {
  int _selectedPlanIndex = 1; // 0: 1 Hafta, 1: 1 Ay (Popüler), 2: 3 Ay
  bool _isProcessing = false;

  final List<Map<String, dynamic>> _plans = [
    {
      'title': '1 HAFTA',
      'price': '₺89.99',
      'period': 'hafta',
      'days': 7,
      'isPopular': false,
    },
    {
      'title': '1 AY',
      'price': '₺199.99',
      'period': 'ay',
      'days': 30,
      'badge': '%40 TASARRUF',
      'isPopular': true,
    },
    {
      'title': '3 AY',
      'price': '₺449.99',
      'period': '3 ay',
      'days': 90,
      'badge': 'AVANTAJLI',
      'isPopular': false,
    },
  ];

  Future<void> _handlePurchase() async {
    setState(() => _isProcessing = true);
    HapticFeedback.heavyImpact();

    final selectedPlan = _plans[_selectedPlanIndex];
    final days = selectedPlan['days'] as int;

    String productId = IosInAppPurchaseService.vipMonthlyId;
    if (days == 7) productId = IosInAppPurchaseService.vipWeeklyId;
    if (days == 90) productId = IosInAppPurchaseService.vipQuarterlyId;

    // Apple StoreKit In-App Purchase akışı
    final success = await IosInAppPurchaseService().buyProduct(productId);

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (success) {
      final eventService = context.read<MockEventService>();
      await eventService.activateVip(days: days);

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.workspace_premium_rounded, color: Color(0xFFFBBF24), size: 24),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tebrikler! EventMatch VIP aktif edildi. Ayrıcalıkların tadını çıkarın! 👑',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1E1E2E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  /// Apple App Store Guideline 3.1.1 Zorunluluğu: Satın Alımları Geri Yükle
  Future<void> _handleRestore() async {
    setState(() => _isProcessing = true);
    HapticFeedback.lightImpact();

    final restored = await IosInAppPurchaseService().restorePurchases();

    if (!mounted) return;
    setState(() => _isProcessing = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          restored
              ? 'Satın alımlarınız başarıyla geri yüklendi! 🍏'
              : 'Aktif bir VIP aboneliği bulunamadı.',
        ),
        backgroundColor: AppColors.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Future<void> _handleCancel() async {
    HapticFeedback.lightImpact();
    final eventService = context.read<MockEventService>();
    await eventService.cancelVip();

    if (!mounted) return;
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('EventMatch VIP üyeliği sonlandırıldı.'),
        backgroundColor: AppColors.surface,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final eventService = context.watch<MockEventService>();
    final currentUser = eventService.currentUser;
    final hasVip = currentUser.hasActiveVip;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0F111A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle Bar
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),

            // Crown Icon with ambient glow
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFF59E0B), Color(0xFFD97706), Color(0xFF78350F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                size: 40,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 14),

            // Title
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFFFDE68A), Color(0xFFF59E0B), Color(0xFFFBBF24)],
              ).createShader(bounds),
              child: Text(
                'EventMatch VIP',
                style: GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Etkinliklerin ve Eşleşmelerin Ayrıcalıklı Dünyası',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 22),

            // If user already has active VIP
            if (hasVip) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.verified_rounded, color: Color(0xFFFBBF24), size: 30),
                    const SizedBox(height: 8),
                    Text(
                      'VIP Üyeliğiniz Şu Anda Aktif',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentUser.vipExpiryDate != null
                          ? 'Bitiş Tarihi: ${currentUser.vipExpiryDate!.day}.${currentUser.vipExpiryDate!.month}.${currentUser.vipExpiryDate!.year}'
                          : 'Sınırsız VIP Ayrıcalıkları Devrede',
                      style: GoogleFonts.outfit(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // 4 VIP Features List
            _buildFeatureTile(
              icon: Icons.visibility_rounded,
              iconColor: const Color(0xFF38BDF8),
              title: 'Seni Beğenenleri Gör',
              description: 'Seni beğenen tüm profillerin fotoğraflarını net gör ve beklemeden anında eşleş.',
              isHighlighted: widget.highlightedFeature == VipFeature.seeLikes,
            ),
            const SizedBox(height: 10),
            _buildFeatureTile(
              icon: Icons.replay_rounded,
              iconColor: const Color(0xFFF59E0B),
              title: 'Sınırsız Geri Alma (Undo)',
              description: 'Yanlışlıkla sola kaydırdığın profilleri tek dokunuşla desteye geri çağır.',
              isHighlighted: widget.highlightedFeature == VipFeature.undoSwipe,
            ),
            const SizedBox(height: 10),
            _buildFeatureTile(
              icon: Icons.local_fire_department_rounded,
              iconColor: const Color(0xFFEC4899),
              title: 'Mekan Sohbetinde VIP Rozeti',
              description: 'Konser ve mekan sohbetlerinde altın parlayan mesaj balonu ve 👑 VIP tacı ile parılda.',
              isHighlighted: widget.highlightedFeature == VipFeature.venueBadge,
            ),
            const SizedBox(height: 10),
            _buildFeatureTile(
              icon: Icons.bolt_rounded,
              iconColor: const Color(0xFFA855F7),
              title: '1 Saatlik Radar Boost',
              description: 'Etkinlik haritasında profilini 1 saat öne çıkar, civardaki tüm katılımcıların en başında görün.',
              isHighlighted: widget.highlightedFeature == VipFeature.mapBoost,
            ),

            const SizedBox(height: 24),

            if (!hasVip) ...[
              // Plan Selector
              Row(
                children: List.generate(_plans.length, (index) {
                  final plan = _plans[index];
                  final isSelected = _selectedPlanIndex == index;
                  final isPopular = plan['isPopular'] == true;

                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedPlanIndex = index);
                      },
                      child: Container(
                        margin: EdgeInsets.only(
                          right: index < _plans.length - 1 ? 8 : 0,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFF59E0B).withValues(alpha: 0.16)
                              : Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFF59E0B)
                                : Colors.white.withValues(alpha: 0.1),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            if (plan['badge'] != null)
                              Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  plan['badge'],
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              )
                            else
                              const SizedBox(height: 15),
                            Text(
                              plan['title'],
                              style: GoogleFonts.outfit(
                                color: isSelected ? const Color(0xFFFDE68A) : Colors.white70,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              plan['price'],
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              '/${plan['period']}',
                              style: GoogleFonts.outfit(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),

              // CTA Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _handlePurchase,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 8,
                    shadowColor: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                  ),
                  child: _isProcessing
                      ? const CircularProgressIndicator(color: Colors.black)
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.workspace_premium_rounded, color: Colors.black, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              'VIP Üyeliği Başlat',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ] else ...[
              // Cancel / Manage Plan button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: _handleCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    'VIP Üyeliğini İptal Et',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],

            // Apple App Store Guideline 3.1.1: Restore Purchases Button
            Center(
              child: TextButton.icon(
                onPressed: _isProcessing ? null : _handleRestore,
                icon: const Icon(Icons.restore_rounded, color: Color(0xFFFBBF24), size: 16),
                label: Text(
                  'Satın Alımları Geri Yükle',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFFFBBF24),
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Apple Guideline 3.1.2: Auto-renewable Subscriptions Disclosure
            Text(
              'Ödeme onaylandığında Apple Kimliği hesabınızdan tahsil edilecektir. Abonelik, mevcut dönemin bitiminden en az 24 saat önce iptal edilmediği sürece otomatik olarak yenilenir. Aboneliğinizi App Store Hesap Ayarları üzerinden dilediğiniz zaman yönetebilir veya iptal edebilirsiniz.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: Colors.white38,
                fontSize: 10,
                height: 1.3,
              ),
            ),

            const SizedBox(height: 10),

            // Apple Guideline 3.1.2: EULA and Privacy Policy Links
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => UrlLauncherHelper.launchURL('https://www.apple.com/legal/internet-services/itunes/dev/stdeula/'),
                  child: Text(
                    'Kullanım Şartları (EULA)',
                    style: GoogleFonts.outfit(
                      color: Colors.white60,
                      fontSize: 10.5,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const Text('  •  ', style: TextStyle(color: Colors.white30, fontSize: 10)),
                GestureDetector(
                  onTap: () => UrlLauncherHelper.launchURL('https://eventmatch.app/privacy'),
                  child: Text(
                    'Gizlilik Politikası',
                    style: GoogleFonts.outfit(
                      color: Colors.white60,
                      fontSize: 10.5,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required bool isHighlighted,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isHighlighted
            ? iconColor.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isHighlighted
              ? iconColor.withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.06),
          width: isHighlighted ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                      ),
                    ),
                    if (isHighlighted) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: iconColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'SEÇİLEN',
                          style: TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: GoogleFonts.outfit(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                    height: 1.3,
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
