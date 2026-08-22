import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../events/services/mock_event_service.dart';
import '../../auth/services/auth_service.dart';
import '../../events/services/moderation_service.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  bool _isPrivateProfile = false;
  bool _hideEventActivity = false;
  bool _hideLastSeen = false;
  bool _enableLocationSharing = true;

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
      _isPrivateProfile = prefs.getBool('${userId}_privacy_private_profile') ??
                          prefs.getBool('${userName}_privacy_private_profile') ??
                          prefs.getBool('privacy_private_profile') ?? false;
      _hideEventActivity = prefs.getBool('${userId}_privacy_hide_events') ??
                          prefs.getBool('${userName}_privacy_hide_events') ??
                          prefs.getBool('privacy_hide_events') ?? false;
      _hideLastSeen = prefs.getBool('${userId}_privacy_hide_last_seen') ??
                      prefs.getBool('${userName}_privacy_hide_last_seen') ??
                      prefs.getBool('privacy_hide_last_seen') ?? false;
      _enableLocationSharing = prefs.getBool('${userId}_privacy_location_sharing') ??
                               prefs.getBool('${userName}_privacy_location_sharing') ??
                               prefs.getBool('privacy_location_sharing') ?? true;
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
      privateProfile: key == 'privacy_private_profile' ? value : null,
      hideEvents: key == 'privacy_hide_events' ? value : null,
      hideLastSeen: key == 'privacy_hide_last_seen' ? value : null,
      locationSharing: key == 'privacy_location_sharing' ? value : null,
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  icon: Icons.visibility_off_rounded,
                  title: 'Gizli Profil',
                  subtitle: 'Profiliniz sadece katıldığınız etkinlikteki kişiler tarafından görülebilir.',
                  value: _isPrivateProfile,
                  onChanged: (val) => _updateSetting('privacy_private_profile', val, (v) => _isPrivateProfile = v),
                ),
                Divider(color: Colors.white.withOpacity(0.06), height: 1, indent: 60),
                _buildPrivacyTile(
                  icon: Icons.event_busy_rounded,
                  title: 'Etkinlik Katılımlarımı Gizle',
                  subtitle: 'Katıldığınız konser ve buluşmalar akışınızda gizlenir.',
                  value: _hideEventActivity,
                  onChanged: (val) => _updateSetting('privacy_hide_events', val, (v) => _hideEventActivity = v),
                ),
                Divider(color: Colors.white.withOpacity(0.06), height: 1, indent: 60),
                _buildPrivacyTile(
                  icon: Icons.access_time_rounded,
                  title: 'Son Görülme ve Çevrimiçi',
                  subtitle: 'Diğer kullanıcılar ne zaman aktif olduğunuzu göremez.',
                  value: _hideLastSeen,
                  onChanged: (val) => _updateSetting('privacy_hide_last_seen', val, (v) => _hideLastSeen = v),
                ),
                Divider(color: Colors.white.withOpacity(0.06), height: 1, indent: 60),
                _buildPrivacyTile(
                  icon: Icons.location_on_rounded,
                  title: 'Konum Paylaşımı',
                  subtitle: 'Yakınınızdaki etkinlik severlerle eşleşmek için konum kullanılır.',
                  value: _enableLocationSharing,
                  onChanged: (val) => _updateSetting('privacy_location_sharing', val, (v) => _enableLocationSharing = v),
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
              final blockedIds = ModerationService().blockedUserIds.toList();
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
                              'Engellenen Kullanıcı (#$id)',
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            trailing: TextButton(
                              onPressed: () async {
                                await ModerationService().unblockUser(id);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Kullanıcının engeli kaldırıldı.')),
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
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
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
            activeColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withOpacity(0.3),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
