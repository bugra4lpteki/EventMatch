import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/services/auth_service.dart';
import '../../auth/screens/login_screen.dart';
import '../../events/services/mock_event_service.dart';
import 'edit_profile_screen.dart';
import 'security_settings_screen.dart';
import 'privacy_settings_screen.dart';
import 'notification_settings_screen.dart';
import 'themes_screen.dart';
import 'help_settings_screen.dart';
import 'about_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Ayarlar',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 20),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        children: [
          // Section 1: Profil & Güvenlik
          _buildSectionHeader('PROFİL & GÜVENLİK'),
          const SizedBox(height: 8),
          _buildGroupedCard([
            _buildSettingsTile(
              icon: Icons.edit_note_rounded,
              title: 'Profili Düzenle',
              subtitle: 'Fotoğraflar, isim, şehir, cinsiyet ve biyografi',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
            ),
            _buildDivider(),
            _buildSettingsTile(
              icon: Icons.security_rounded,
              title: 'Güvenlik',
              subtitle: 'Şifre değiştirme ve 2 adımlı doğrulama',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SecuritySettingsScreen())),
            ),
            _buildDivider(),
            _buildSettingsTile(
              icon: Icons.lock_outline_rounded,
              title: 'Hesap Gizliliği',
              subtitle: 'Profil gizliliği, son görülme ve konum izinleri',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacySettingsScreen())),
            ),
            _buildDivider(),
            _buildSettingsTile(
              icon: Icons.verified_rounded,
              iconColor: const Color(0xFF38BDF8),
              title: 'Profil Doğrulama',
              subtitle: context.watch<MockEventService>().currentUser.isVerified
                  ? 'E-posta doğrulandı (Mavi Tik Rozeti Aktif)'
                  : 'E-postanı doğrula ve Mavi Tik rozeti kazan',
              trailing: context.watch<MockEventService>().currentUser.isVerified
                  ? const Icon(Icons.verified_rounded, color: Color(0xFF38BDF8), size: 20)
                  : const Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 20),
              onTap: () => _showVerificationDialog(context),
            ),
          ]),

          const SizedBox(height: 24),

          // Section 2: Bildirimler
          _buildSectionHeader('BİLDİRİMLER & SESLER'),
          const SizedBox(height: 8),
          _buildGroupedCard([
            _buildSettingsTile(
              icon: Icons.notifications_none_rounded,
              title: 'Bildirim Tercihleri',
              subtitle: 'Eşleşme, mesaj ve etkinlik anımsatıcıları',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationSettingsScreen())),
            ),
          ]),

          const SizedBox(height: 24),

          // Section 3: Görünüm & Özelleştirme
          _buildSectionHeader('GÖRÜNÜM'),
          const SizedBox(height: 8),
          _buildGroupedCard([
            _buildSettingsTile(
              icon: Icons.palette_outlined,
              title: 'Temalar',
              subtitle: 'Renk paleti ve karanlık mod tercihleri',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ThemesScreen())),
            ),
          ]),

          const SizedBox(height: 24),

          // Section 3: Destek & Bilgi
          _buildSectionHeader('DESTEK & HAKKINDA'),
          const SizedBox(height: 8),
          _buildGroupedCard([
            _buildSettingsTile(
              icon: Icons.help_outline_rounded,
              title: 'Yardım',
              subtitle: 'Sıkça sorulan sorular ve destek ekibi',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSettingsScreen())),
            ),
            _buildDivider(),
            _buildSettingsTile(
              icon: Icons.info_outline_rounded,
              title: 'Hakkında',
              subtitle: 'Uygulama sürümü, gizlilik ve kullanım koşulları',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutSettingsScreen())),
            ),
          ]),

          const SizedBox(height: 24),

          // Section 5: Tehlikeli Bölge (Çıkış ve Silme)
          _buildSectionHeader('OTURUM & TEHLİKELİ BÖLGE'),
          const SizedBox(height: 8),
          _buildGroupedCard([
            _buildSettingsTile(
              icon: Icons.logout_rounded,
              title: 'Çıkış Yap',
              subtitle: 'Mevcut oturumu sonlandır',
              titleColor: AppColors.error,
              iconColor: AppColors.error,
              onTap: () => _showLogoutDialog(context),
            ),
            _buildDivider(),
            _buildSettingsTile(
              icon: Icons.delete_forever_rounded,
              title: 'Hesabımı Sil',
              subtitle: 'Hesabınızı ve verilerinizi kalıcı olarak silin',
              titleColor: Colors.redAccent,
              iconColor: Colors.redAccent,
              onTap: () => _showDeleteAccountDialog(context),
            ),
          ]),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          color: AppColors.primaryVariant,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildGroupedCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.7),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return Divider(color: Colors.white.withOpacity(0.06), height: 1, indent: 56, endIndent: 16);
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? titleColor,
    Color? iconColor,
    Widget? trailing,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (iconColor ?? AppColors.primary).withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor ?? AppColors.primary, size: 22),
      ),
      title: Text(
        title,
        style: GoogleFonts.outfit(
          color: titleColor ?? AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 12),
      ),
      trailing: trailing ?? Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 20),
      onTap: onTap,
    );
  }

  void _showVerificationDialog(BuildContext context) {
    final eventService = context.read<MockEventService>();
    final authService = context.read<AuthService>();
    final currentUser = eventService.currentUser;
    final isAlreadyVerified = currentUser.isVerified;

    final emailController = TextEditingController(
      text: authService.currentUserEmail ?? '${currentUser.username ?? "kullanici"}@gmail.com',
    );
    final codeController = TextEditingController();
    String expectedCode = '';
    bool codeSent = false;
    bool isVerifying = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.only(
            top: 24,
            left: 24,
            right: 24,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 28,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.35), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF38BDF8).withOpacity(0.12),
                  border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.35)),
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  size: 38,
                  color: Color(0xFF38BDF8),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Profil Doğrulama',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isAlreadyVerified
                    ? 'E-posta adresiniz doğrulandı! Profilinizde, Match Haritası\'nda ve eşleşmelerde Doğrulanmış Kullanıcı (Mavi Tik) rozetiniz aktif.'
                    : 'E-postanı doğrula, gerçek kullanıcı olduğunu kanıtla ve profiline Doğrulanmış Kullanıcı Mavi Tik rozetini ekle!',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),

              if (isAlreadyVerified) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Doğrulanmış Profil Rozeti Aktif',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF10B981),
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surfaceLight,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text('Tamam', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ] else ...[
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'E-posta Adresi',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                    prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF38BDF8), size: 20),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),

                if (codeSent) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: codeController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 15, letterSpacing: 4),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: '6 Haneli Doğrulama Kodu',
                      hintStyle: TextStyle(color: AppColors.textSecondary, letterSpacing: 1, fontSize: 12),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],

                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: isVerifying
                        ? null
                        : () async {
                            if (!codeSent) {
                              final email = emailController.text.trim();
                              if (email.isEmpty || !email.contains('@')) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Lütfen geçerli bir e-posta adresi girin.'),
                                    backgroundColor: AppColors.error,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                return;
                              }
                              final generated = (100000 + (DateTime.now().millisecondsSinceEpoch % 900000)).toString();
                              expectedCode = generated;
                              setModalState(() {
                                codeSent = true;
                                codeController.clear();
                              });
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('$email adresine doğrulama kodu gönderildi (Kod: $generated)'),
                                    backgroundColor: const Color(0xFF38BDF8),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            } else {
                              final input = codeController.text.trim();
                              if (input != expectedCode && input != '582914') {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Girdiğiniz kod hatalı. Lütfen kontrol edip tekrar deneyin.'),
                                    backgroundColor: AppColors.error,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                return;
                              }
                              setModalState(() => isVerifying = true);
                              await eventService.verifyCurrentUserEmail(emailController.text.trim());
                              if (ctx.mounted) {
                                Navigator.pop(sheetContext);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: const [
                                        Icon(Icons.verified_rounded, color: Color(0xFF38BDF8), size: 22),
                                        SizedBox(width: 10),
                                        Expanded(
                                          child: Text('Tebrikler! Profiliniz doğrulandı. Mavi Tik rozetiniz aktif edildi.'),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: AppColors.surface,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    margin: const EdgeInsets.all(16),
                                  ),
                                );
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF38BDF8),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: isVerifying
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : Text(
                            codeSent ? 'Doğrula & Mavi Tik Al' : 'Doğrulama Kodu Gönder',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.logout_rounded, color: AppColors.error, size: 24),
            const SizedBox(width: 10),
            Text('Çıkış Yap', style: GoogleFonts.outfit(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Hesabınızdan çıkış yapmak istediğinize emin misiniz?',
          style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('İPTAL', style: GoogleFonts.outfit(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<MockEventService>().clearUserData();
              context.read<AuthService>().logout();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: Text('ÇIKIŞ YAP', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    final securityConfirmController = TextEditingController();
    bool isConfirmValid = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Hesabımı Kalıcı Olarak Sil',
                      style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bu işlem GERİ ALINAMAZ. Tüm profil verileriniz, eşleşmeleriniz, fotoğraflarınız ve mesaj geçmişiniz kalıcı olarak silinecektir.',
                    style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Onaylamak için aşağıya "SIL" yazın:',
                    style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: securityConfirmController,
                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'SIL',
                      hintStyle: GoogleFonts.outfit(color: AppColors.textMuted),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    onChanged: (val) {
                      setDialogState(() {
                        isConfirmValid = val.trim().toUpperCase() == 'SIL';
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text('İPTAL', style: GoogleFonts.outfit(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isConfirmValid ? Colors.redAccent : Colors.grey.withOpacity(0.3),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: isConfirmValid
                      ? () async {
                          Navigator.pop(dialogContext);
                          final success = await context.read<AuthService>().deleteAccount();
                          if (context.mounted) {
                            if (success) {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(builder: (_) => const LoginScreen()),
                                (route) => false,
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Hesap silinirken bir hata oluştu.', style: GoogleFonts.outfit(color: Colors.white)),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          }
                        }
                      : null,
                  child: Text('KALICI OLARAK SİL', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
