import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _matchNotifications = true;
  bool _messageNotifications = true;
  bool _eventReminders = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _matchNotifications = prefs.getBool('notif_matches') ?? true;
      _messageNotifications = prefs.getBool('notif_messages') ?? true;
      _eventReminders = prefs.getBool('notif_events') ?? true;
      _soundEnabled = prefs.getBool('notif_sound') ?? true;
      _vibrationEnabled = prefs.getBool('notif_vibration') ?? true;
      _isLoading = false;
    });
  }

  Future<void> _updatePref(String key, bool value, Function(bool) updateState) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    if (!mounted) return;
    setState(() {
      updateState(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Bildirim Tercihleri',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 20),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              children: [
                _buildSectionHeader('ANLIK BİLDİRİMLER (PUSH)'),
                const SizedBox(height: 8),
                _buildGroupedCard([
                  _buildSwitchTile(
                    icon: Icons.favorite_rounded,
                    iconColor: AppColors.primary,
                    title: 'Yeni Eşleşmeler',
                    subtitle: 'Biriyle karşılıklı eşleştiğinde bildirim al',
                    value: _matchNotifications,
                    onChanged: (val) => _updatePref('notif_matches', val, (v) => _matchNotifications = v),
                  ),
                  _buildDivider(),
                  _buildSwitchTile(
                    icon: Icons.chat_bubble_rounded,
                    iconColor: const Color(0xFF38BDF8),
                    title: 'Yeni Mesajlar',
                    subtitle: 'Eşleştiğin kişilerden mesaj geldiğinde bildirim al',
                    value: _messageNotifications,
                    onChanged: (val) => _updatePref('notif_messages', val, (v) => _messageNotifications = v),
                  ),
                  _buildDivider(),
                  _buildSwitchTile(
                    icon: Icons.event_available_rounded,
                    iconColor: Colors.amber,
                    title: 'Etkinlik Hatırlatıcıları',
                    subtitle: 'Katılacağın etkinlikler yaklaşırken anımsatıcı al',
                    value: _eventReminders,
                    onChanged: (val) => _updatePref('notif_events', val, (v) => _eventReminders = v),
                  ),
                ]),

                const SizedBox(height: 24),

                _buildSectionHeader('SES VE TİTREŞİM'),
                const SizedBox(height: 8),
                _buildGroupedCard([
                  _buildSwitchTile(
                    icon: Icons.volume_up_rounded,
                    iconColor: Colors.purpleAccent,
                    title: 'Bildirim Sesleri',
                    subtitle: 'Bildirimler geldiğinde zil sesi çal',
                    value: _soundEnabled,
                    onChanged: (val) => _updatePref('notif_sound', val, (v) => _soundEnabled = v),
                  ),
                  _buildDivider(),
                  _buildSwitchTile(
                    icon: Icons.vibration_rounded,
                    iconColor: Colors.tealAccent,
                    title: 'Titreşim',
                    subtitle: 'Bildirimler ve eşleşmelerde titreşim uyarısı ver',
                    value: _vibrationEnabled,
                    onChanged: (val) => _updatePref('notif_vibration', val, (v) => _vibrationEnabled = v),
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
        color: AppColors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return Divider(color: Colors.white.withValues(alpha: 0.06), height: 1, indent: 56, endIndent: 16);
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: GoogleFonts.outfit(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 12),
      ),
      trailing: Switch(
        value: value,
        activeColor: AppColors.primary,
        onChanged: onChanged,
      ),
    );
  }
}
