import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import 'admin_panel_screen.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _error;

  // Admin kimlik bilgileri
  static const String _adminUsername = 'admin';
  static const String _adminPassword = 'eventmatch2024';

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    await Future.delayed(const Duration(milliseconds: 800));

    if (_usernameController.text.trim() == _adminUsername &&
        _passwordController.text == _adminPassword) {
      HapticFeedback.mediumImpact();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminPanelScreen()),
        );
      }
    } else {
      HapticFeedback.vibrate();
      setState(() {
        _isLoading = false;
        _error = 'Kullanıcı adı veya şifre hatalı.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.primary),
        title: Text('Yönetici Girişi',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 2),
                  ),
                  child: Icon(Icons.admin_panel_settings, size: 56, color: AppColors.primary),
                ),
                const SizedBox(height: 32),
                Text('Yönetim Paneli',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                Text('Bu alana yalnızca yetkililer erişebilir.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _usernameController,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Kullanıcı Adı',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                    prefixIcon: Icon(Icons.person, color: AppColors.primary),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Zorunlu alan' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Şifre',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                    prefixIcon: Icon(Icons.lock, color: AppColors.primary),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility : Icons.visibility_off,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Zorunlu alan' : null,
                  onFieldSubmitted: (_) => _login(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.error.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: AppColors.error, size: 18),
                        const SizedBox(width: 8),
                        Text(_error!, style: TextStyle(color: AppColors.error)),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 6,
                      shadowColor: AppColors.primary.withOpacity(0.4),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : Text('GİRİŞ YAP',
                            style: TextStyle(
                                color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
