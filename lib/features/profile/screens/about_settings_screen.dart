import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../admin/widgets/secret_admin_dialog.dart';

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
                  child: const Icon(
                    Icons.confirmation_number_rounded,
                    color: Colors.white,
                    size: 44,
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
                    title: Text('Kullanıcı Sözleşmesi', style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 15)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
                    onTap: () {
                      _showLegalModal(
                        context,
                        'Kullanıcı Sözleşmesi (EULA)',
                        'EventMatch Son Kullanıcı Lisans Sözleşmesi (EULA) & Kullanım Şartları:\n\n'
                        '1. Sıfır Tolerans Politikası (UGC): EventMatch platformunda taciz edici, hakaret içeren, müstehcen, nefret söylemi barındıran veya yasadışı hiçbir kullanıcı içeriğine veya davranışına tolerans gösterilmez (Zero Tolerance Policy).\n\n'
                        '2. Moderasyon & Şikayet İnceleme: Kullanıcılar tarafından şikayet edilen veya uygunsuz bulunan içerik ve hesaplar, moderasyon ekibimiz tarafından en geç 24 saat içerisinde incelenir, gerekli görüldüğünde içerik kaldırılır ve ilgili hesap kalıcı olarak engellenir/yasaklanır.\n\n'
                        '3. Engelleme & Güvenlik: Her kullanıcı, rahatsızlık duyduğu diğer kullanıcıları anında engelleme ve şikayet etme hakkına ve aracına sahiptir. Engellenen kullanıcılar birbirlerinin profillerini ve mesajlarını göremez.\n\n'
                        '4. Etkinlik Kuralları: Etkinlik oluşturucuları ve katılımcıları topluluk kurallarına uymakla yükümlüdür.\n\n'
                        '5. Yaş Sınırı: Hizmetlerimizden faydalanmak için en az 18 yaşında olmanız gerekmektedir.\n\n'
                        'Tüm hakları saklıdır. © 2026 EventMatch Inc.',
                      );
                    },
                  ),
                  Divider(color: Colors.white.withOpacity(0.06), height: 1, indent: 60),
                  ListTile(
                    leading: Icon(Icons.shield_outlined, color: AppColors.primary),
                    title: Text('Gizlilik Politikası', style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 15)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
                    onTap: () {
                      _showLegalModal(
                        context,
                        'Gizlilik Politikası',
                        'EventMatch KVKK ve Kişisel Verilerin Korunması Politikası:\n\n'
                        '1. Veri Toplama: EventMatch hesabınız oluşturulurken verdiğiniz isim, kullanıcı adı, e-posta ve tercih ettiğiniz etkinlik kategorileri veritabanımızda güvenle saklanır.\n\n'
                        '2. Konum İzinleri: Konum bilginiz yalnızca etrafınızdaki etkinlikleri listelemek ve yakınlarınızdaki kullanıcıları önermek için kullanılır, 3. taraflarla paylaşılmaz.\n\n'
                        '3. Veri Güvenliği: Tüm parola ve kimlik verileri Supabase endüstri standardı şifreleme yöntemleri (SSL/TLS) ile korunmaktadır.\n\n'
                        '4. Veri Silme Talebi: Ayarlar sayfasından "Hesabımı Sil" seçeneği ile tüm kişisel verilerinizi kalıcı olarak silebilirsiniz.',
                      );
                    },
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
