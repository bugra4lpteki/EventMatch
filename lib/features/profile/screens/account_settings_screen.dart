import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../events/services/mock_event_service.dart';
import '../../auth/services/auth_service.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _bioController;
  String? _selectedAvatarPath;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<MockEventService>().currentUser;
    _nameController = TextEditingController(text: user.name);
    _usernameController = TextEditingController(text: user.username ?? '');
    _bioController = TextEditingController(text: user.aboutMe ?? '');
    if (user.avatarUrls.isNotEmpty) {
      _selectedAvatarPath = user.avatarUrls.first;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (pickedFile != null) {
      setState(() {
        _selectedAvatarPath = pickedFile.path;
      });
    }
  }

  Future<void> _saveAccountInfo() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final mockService = context.read<MockEventService>();
      final authService = context.read<AuthService>();
      final userId = authService.currentUserId ?? 'user_1';

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('${userId}_userName', _nameController.text.trim());
      await prefs.setString('${userId}_userUsername', _usernameController.text.trim());
      await prefs.setString('${userId}_userBio', _bioController.text.trim());

      if (_selectedAvatarPath != null) {
        await prefs.setString('${userId}_userAvatar', _selectedAvatarPath!);
      }

      // Update in memory & persistent storage via service
      await mockService.updateCurrentUser(
        name: _nameController.text.trim(),
        username: _usernameController.text.trim(),
        aboutMe: _bioController.text.trim(),
        avatarUrl: _selectedAvatarPath ?? mockService.currentUser.avatarUrl,
        avatarImages: _selectedAvatarPath != null ? [_selectedAvatarPath!] : mockService.currentUser.avatarUrls,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Hesap bilgileriniz başarıyla güncellendi!');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Güncelleme sırasında hata oluştu.', isError: true);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w500)),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Hesabım', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Avatar Edit Section
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.primaryGradient,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(3.0),
                        child: CircleAvatar(
                          backgroundColor: AppColors.surface,
                          backgroundImage: _selectedAvatarPath != null
                              ? (_selectedAvatarPath!.startsWith('http')
                                  ? NetworkImage(_selectedAvatarPath!)
                                  : FileImage(File(_selectedAvatarPath!)) as ImageProvider)
                              : null,
                          child: _selectedAvatarPath == null
                              ? Icon(Icons.person, size: 54, color: AppColors.primary)
                              : null,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.background, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Profil Fotoğrafını Değiştir',
                style: GoogleFonts.outfit(color: AppColors.primaryVariant, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 32),

              // Glass Card for Input Fields
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Column(
                  children: [
                    // Name Field
                    TextFormField(
                      controller: _nameController,
                      style: GoogleFonts.outfit(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'İsim Soyisim',
                        prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.primaryVariant),
                      ),
                      validator: (value) => value == null || value.trim().isEmpty ? 'İsim alanı boş bırakılamaz' : null,
                    ),
                    const SizedBox(height: 16),

                    // Username Field
                    TextFormField(
                      controller: _usernameController,
                      style: GoogleFonts.outfit(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Kullanıcı Adı',
                        prefixIcon: Icon(Icons.alternate_email_rounded, color: AppColors.primaryVariant),
                      ),
                      validator: (value) => value == null || value.trim().isEmpty ? 'Kullanıcı adı boş bırakılamaz' : null,
                    ),
                    const SizedBox(height: 16),

                    // Bio Field
                    TextFormField(
                      controller: _bioController,
                      maxLines: 3,
                      style: GoogleFonts.outfit(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Biyografi',
                        alignLabelWithHint: true,
                        prefixIcon: Icon(Icons.notes_rounded, color: AppColors.primaryVariant),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Save Button
              Container(
                width: double.infinity,
                height: 54,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveAccountInfo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text(
                          'KAYDET',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
