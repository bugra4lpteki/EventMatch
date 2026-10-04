import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../admin/widgets/secret_admin_dialog.dart';
import '../../legal/screens/terms_and_permissions_screen.dart';
import '../../../core/utils/url_launcher_helper.dart';

class AboutSettingsScreen extends StatefulWidget {
  const AboutSettingsScreen({super.key});

  @override
  State<AboutSettingsScreen> createState() => _AboutSettingsScreenState();
}

class _AboutSettingsScreenState extends State<AboutSettingsScreen> {
  int _tapCount = 0;
  Timer? _tapTimer;

  void _handleSecretTap() {
    _tapCount++;
    _tapTimer?.cancel();
    _tapTimer = Timer(const Duration(seconds: 3), () {
      _tapCount = 0;
    });

    if (_tapCount >= 5) {
      _tapCount = 0;
      SecretAdminAuthHelper.showSecretPinDialog(context);
    }
  }

  void _showLegalModal(BuildContext context, String title, String contentText) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white10),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(
                    contentText,
                    style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 13, height: 1.6),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Hakkında', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 10),

            // App Brand Header Card (Gizli 5 tıklama ile admin paneline giriş)
            Center(
              child: GestureDetector(
                onTap: _handleSecretTap,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.45),
                        blurRadius: 25,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/images/app_logo.png',
                      width: 88,
                      height: 88,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _handleSecretTap,
              child: Text(
                'EventMatch',
                style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: _handleSecretTap,
              child: Text(
                'Sürüm v1.0.0 (Build 102)',
                style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 13),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Türkiye\'nin En Dinamik Sosyal Etkinlik Platformu',
              style: GoogleFonts.outfit(color: AppColors.primaryVariant, fontSize: 12, fontWeight: FontWeight.w600),
            ),

            const SizedBox(height: 36),

            // Zero Tolerance & Safety Notice Box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orangeAccent.withOpacity(0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.security_rounded, color: Colors.orangeAccent, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Sıfır Tolerans & 24 Saat Güvencesi',
                        style: GoogleFonts.outfit(
                          color: Colors.orangeAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'EventMatch, sakıncalı içeriklere (UGC) ve kötü niyetli kullanıcılara karşı sıfır tolerans politikası uygulamaktadır. Şikayet edilen içerikler en geç 24 saat içinde incelenir, ihlal yapan kullanıcılar platformdan ihraç edilir.',
                    style: GoogleFonts.outfit(
                      color: Colors.white70,
                      fontSize: 11.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Legal & Terms Grouped Card
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface.withOpacity(0.7),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.description_outlined, color: AppColors.primary),
                    title: Text('Kullanıcı Sözleşmesi (EULA)', style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 15)),
                    subtitle: Text('Sıfır tolerans ve topluluk kuralları', style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TermsAndPermissionsScreen(),
                      ),
                    ),
                  ),
                  Divider(color: Colors.white.withOpacity(0.06), height: 1, indent: 60),
                  ListTile(
                    leading: const Icon(Icons.open_in_browser_rounded, color: Colors.cyanAccent),
                    title: Text('Apple Standart EULA', style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 15)),
                    subtitle: Text('Apple Standart Lisans Sözleşmesi', style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11)),
                    trailing: const Icon(Icons.open_in_new_rounded, color: Colors.white38, size: 18),
                    onTap: () => UrlLauncherHelper.launchURL('https://www.apple.com/legal/internet-services/itunes/dev/stdeula/'),
                  ),
                  Divider(color: Colors.white.withOpacity(0.06), height: 1, indent: 60),
                  ListTile(
                    leading: Icon(Icons.shield_outlined, color: AppColors.primary),
                    title: Text('Gizlilik Politikası', style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 15)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TermsAndPermissionsScreen(),
                      ),
                    ),
                  ),
                  Divider(color: Colors.white.withOpacity(0.06), height: 1, indent: 60),
                  ListTile(
                    leading: const Icon(Icons.mail_outline_rounded, color: Colors.amberAccent),
                    title: Text('Uygunsuz İçerik Bildirimi & İletişim', style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 14)),
                    subtitle: Text('guvenlik@eventmatch.app', style: GoogleFonts.outfit(color: Colors.white54, fontSize: 11)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
                    onTap: () => UrlLauncherHelper.launchURL('mailto:guvenlik@eventmatch.app?subject=EventMatch%20Uygunsuz%20Icerik%20Bildirimi'),
                  ),
                  Divider(color: Colors.white.withOpacity(0.06), height: 1, indent: 60),
                  ListTile(
                    leading: Icon(Icons.code_rounded, color: AppColors.primary),
                    title: Text('Açık Kaynak Lisansları', style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 15)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
                    onTap: () {
                      showLicensePage(
                        context: context,
                        applicationName: 'EventMatch',
                        applicationVersion: '1.0.0',
                      );
                    },
                  ),
                ],
              ),
            ),

            const Spacer(),
            Text(
              'Designed & Built with ❤️ for EventMatch',
              style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
