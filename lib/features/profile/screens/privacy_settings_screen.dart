import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/content_filter_service.dart';
import '../../events/services/mock_event_service.dart';
import '../../auth/services/auth_service.dart';
import '../../events/services/moderation_service.dart';
import '../widgets/profile_verification_dialog.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  bool _hideEventActivity = false;
  bool _enableLocationSharing = true;
  bool _enableContentFilter = true;
  bool _showVerifiedBadge = true;

  @override
  void initState() {
    super.initState();
    _loadPrivacySettings();
  }

  Future<void> _loadPrivacySettings() async {
    final authService = context.read<AuthService>();
    final eventService = context.read<MockEventService>();
    final userId = authService.currentUserId ?? eventService.currentUser.id;
    final userName = eventService.currentUser.name;

    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;
    setState(() {
      _hideEventActivity = prefs.getBool('${userId}_privacy_hide_events') ??
                          prefs.getBool('${userName}_privacy_hide_events') ??
                          prefs.getBool('privacy_hide_events') ?? false;
      _enableLocationSharing = prefs.getBool('${userId}_privacy_location_sharing') ??
                               prefs.getBool('${userName}_privacy_location_sharing') ??
                               prefs.getBool('privacy_location_sharing') ?? true;
      _enableContentFilter = ContentFilterService.instance.isFilterEnabled;
      _showVerifiedBadge = prefs.getBool('${userId}_show_verified_badge') ??
                           prefs.getBool('${userName}_show_verified_badge') ??
                           prefs.getBool('show_verified_badge') ??
                           eventService.currentUser.showVerifiedBadge;
    });
  }

  Future<void> _updateSetting(String key, bool value, Function(bool) updateState) async {
    final authService = context.read<AuthService>();
    final eventService = context.read<MockEventService>();
    final userId = authService.currentUserId ?? eventService.currentUser.id;
    final userName = eventService.currentUser.name;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    await prefs.setBool('${userId}_$key', value);
    await prefs.setBool('${userName}_$key', value);

    if (!mounted) return;
    setState(() {
      updateState(value);
    });

    eventService.updatePrivacySettings(
      hideEvents: key == 'privacy_hide_events' ? value : null,
      locationSharing: key == 'privacy_location_sharing' ? value : null,
      showVerifiedBadge: key == 'show_verified_badge' ? value : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final eventService = context.watch<MockEventService>();
    final isUserVerified = eventService.currentUser.isVerified;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Hesap Gizliliği', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          Text(
            'Gizlilik İzinleri',
            style: GoogleFonts.outfit(color: AppColors.primaryVariant, fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              color: AppColors.surface.withOpacity(0.7),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              children: [
                _buildPrivacyTile(
                  icon: Icons.event_busy_rounded,
                  title: 'Etkinlik Katılımlarımı Gizle',
                  subtitle: 'Katıldığınız konser ve buluşmalar akışınızda gizlenir.',
                  value: _hideEventActivity,
                  onChanged: (val) => _updateSetting('privacy_hide_events', val, (v) => _hideEventActivity = v),
                ),
                Divider(color: Colors.white.withOpacity(0.06), height: 1, indent: 60),
                _buildPrivacyTile(
                  icon: Icons.location_on_rounded,
                  title: 'Konum Paylaşımı',
                  subtitle: 'Yakınınızdaki etkinlik severlerle eşleşmek için konum kullanılır.',
                  value: _enableLocationSharing,
                  onChanged: (val) => _updateSetting('privacy_location_sharing', val, (v) => _enableLocationSharing = v),
                ),
                Divider(color: Colors.white.withOpacity(0.06), height: 1, indent: 60),
                _buildPrivacyTile(
                  icon: Icons.verified_rounded,
                  iconColor: const Color(0xFF38BDF8),
                  title: 'Mavi Tik Rozetini Göster',
                  subtitle: isUserVerified
                      ? (_showVerifiedBadge
                          ? 'Mavi Tik onay rozetiniz profilinizde ve sohbetlerde herkese açıktır.'
                          : 'Mavi Tik onay rozetiniz gizlendi. Rozet profilinizde görünmez.')
                      : 'Doğrulanmış kullanıcı mavi tik rozetinizin görünürlüğünü yönetin (Doğrulamak için dokunun).',
                  value: _showVerifiedBadge && isUserVerified,
                  onChanged: (val) async {
                    HapticFeedback.lightImpact();
                    if (!isUserVerified) {
                      showProfileVerificationSheet(
                        context,
                        onVerified: () {
                          if (mounted) {
                            setState(() {
                              _showVerifiedBadge = true;
                            });
                          }
                        },
                      );
                      return;
                    }
                    await _updateSetting('show_verified_badge', val, (v) => _showVerifiedBadge = v);
                    await eventService.updatePrivacySettings(showVerifiedBadge: val);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              Icon(
                                val ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                color: const Color(0xFF38BDF8),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  val
                                      ? 'Mavi Tik rozetiniz artık herkese açık ve görünür.'
                                      : 'Mavi Tik rozetiniz profilinizde ve sohbetlerde gizlendi.',
                                ),
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
                  },
                ),
                Divider(color: Colors.white.withOpacity(0.06), height: 1, indent: 60),
                _buildPrivacyTile(
                  icon: Icons.verified_user_outlined,
                  title: 'Akıllı Argo & Küfür Filtresi',
                  subtitle: 'Mesajlardaki uygunsuz sözcükleri akıllıca gizler (***). Kapatılırsa sansür uygulanmaz.',
                  value: _enableContentFilter,
                  onChanged: (val) async {
                    HapticFeedback.lightImpact();
                    await ContentFilterService.instance.setFilterEnabled(val);
                    if (mounted) {
                      setState(() {
                        _enableContentFilter = val;
                      });
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          // Engellenen Kullanıcılar
          Padding(
            padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
            child: Text(
              'ENGELLENEN KULLANICILAR',
              style: GoogleFonts.outfit(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
          ),
          ListenableBuilder(
            listenable: ModerationService(),
            builder: (context, _) {
              final moderation = ModerationService();
              final blockedIds = moderation.blockedUserIds.toList();
              return Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: blockedIds.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(
                          child: Text(
                            'Henüz engellediğiniz bir kullanıcı bulunmuyor.',
                            style: TextStyle(color: Colors.white54, fontSize: 13),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: blockedIds.length,
                        separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                        itemBuilder: (context, index) {
                          final id = blockedIds[index];
                          final storedName = moderation.getBlockedUserName(id);

                          return FutureBuilder<String>(
                            future: storedName.isNotEmpty ? Future.value(storedName) : moderation.resolveUserName(id),
                            initialData: storedName.isNotEmpty ? storedName : 'Kullanıcı',
                            builder: (context, snapshot) {
                              final displayName = (snapshot.data != null && snapshot.data!.isNotEmpty)
                                  ? snapshot.data!
                                  : 'Kullanıcı';
                              return ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.block, color: Colors.redAccent, size: 18),
                                ),
                                title: Text(
                                  displayName,
                                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  '@${id.length > 8 ? id.substring(0, 8) : id}',
                                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                                ),
                                trailing: TextButton(
                                  onPressed: () async {
                                    HapticFeedback.lightImpact();
                                    await moderation.unblockUser(id);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('$displayName kullanıcısının engeli kaldırıldı.'),
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  },
                                  child: const Text(
                                    'Engeli Kaldır',
                                    style: TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
              );
            },
          ),

          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              'Gizlilik tercihlerinizi dilediğiniz zaman değiştirebilirsiniz. Bazı kısıtlamalar etkinlik önerilerini etkileyebilir.',
              style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyTile({
    required IconData icon,
    Color? iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final effectiveColor = iconColor ?? AppColors.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: effectiveColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: effectiveColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 12, height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: value,
            activeColor: effectiveColor,
            activeTrackColor: effectiveColor.withValues(alpha: 0.3),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
