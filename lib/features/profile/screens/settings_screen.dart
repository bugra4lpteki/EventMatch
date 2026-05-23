import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/services/auth_service.dart';
import '../../auth/screens/login_screen.dart';
import 'themes_screen.dart';
import '../../admin/screens/admin_login_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Ayarlar', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.primary),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _buildSettingsTile(context, icon: Icons.person_outline, title: 'Hesabım'),
          _buildSettingsTile(context, icon: Icons.security, title: 'Güvenlik'),
          _buildSettingsTile(context, icon: Icons.palette_outlined, title: 'Temalar'),
          _buildSettingsTile(context, icon: Icons.lock_outline, title: 'Hesap Gizliliği'),
          _buildSettingsTile(context, icon: Icons.help_outline, title: 'Yardım'),
          _buildSettingsTile(context, icon: Icons.info_outline, title: 'Hakkında'),
          Divider(color: AppColors.surface, thickness: 1, height: 32),
          ListTile(
            leading: Icon(Icons.logout, color: AppColors.error),
            title: Text('Çıkış Yap', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
            onTap: () {
              _showLogoutDialog(context);
            },
          ),
          const Divider(color: Colors.transparent, height: 16),
          ListTile(
            leading: Icon(Icons.admin_panel_settings_outlined, color: AppColors.textSecondary),
            title: Text('Yönetici Girişi', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            trailing: Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 18),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile(BuildContext context, {required IconData icon, required String title}) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title, style: TextStyle(color: AppColors.textPrimary)),
      trailing: Icon(Icons.chevron_right, color: AppColors.textSecondary),
      onTap: () {
        if (title == 'Temalar') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ThemesScreen()),
          );
          return;
        }
        
        // Diğer sayfalar için placeholder
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$title ayarları henüz aktif değil.'),
            backgroundColor: AppColors.surface,
            duration: const Duration(seconds: 1),
          ),
        );
      },
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Çıkış Yap', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        content: Text('Hesabınızdan çıkış yapmak istediğinize emin misiniz?', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İPTAL', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              context.read<AuthService>().logout();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            child: Text('ÇIKIŞ YAP', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
