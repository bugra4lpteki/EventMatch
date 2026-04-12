import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../events/services/mock_event_service.dart';
import '../../events/services/location_radar_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _aboutController;
  late TextEditingController _avatarUrlController;

  @override
  void initState() {
    super.initState();
    final user = context.read<MockEventService>().currentUser;
    _nameController = TextEditingController(text: user.name);
    _ageController = TextEditingController(text: user.age ?? '');
    _aboutController = TextEditingController(text: user.aboutMe ?? '');
    _avatarUrlController = TextEditingController(text: user.avatarUrl);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _aboutController.dispose();
    _avatarUrlController.dispose();
    super.dispose();
  }

  void _saveProfile() {
    if (_formKey.currentState!.validate()) {
      context.read<MockEventService>().updateCurrentUser(
        name: _nameController.text,
        age: _ageController.text,
        aboutMe: _aboutController.text,
        avatarUrl: _avatarUrlController.text,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil başarıyla güncellendi!'),
          backgroundColor: AppColors.secondary,
        ),
      );
    }
  }

  Widget _buildImage(String url) {
    if (url.startsWith('http')) {
      return Image.network(url, fit: BoxFit.cover);
    }
    return Image.asset(url, fit: BoxFit.cover);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profilim', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary, width: 2),
                      ),
                      child: ClipOval(
                        child: _avatarUrlController.text.isNotEmpty
                            ? _buildImage(_avatarUrlController.text)
                            : const Icon(Icons.person, size: 60, color: AppColors.primary),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                          onPressed: () {
                             ScaffoldMessenger.of(context).showSnackBar(
                               const SnackBar(content: Text('Fotoğraf yükleme özelliği yakında!'))
                             );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              _buildTextField(
                controller: _nameController,
                label: 'Ad Soyad',
                icon: Icons.person,
                validator: (v) => v == null || v.isEmpty ? 'Ad boş bırakılamaz' : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _ageController,
                label: 'Yaş',
                icon: Icons.cake,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _aboutController,
                label: 'Hakkımda',
                icon: Icons.info_outline,
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _avatarUrlController,
                label: 'Profil Resmi URL',
                icon: Icons.link,
                onChanged: (_) => setState(() {}), // Anlık fotoğrafı yenile
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 5,
                  shadowColor: AppColors.primary.withOpacity(0.5),
                ),
                child: const Text(
                  'PROFİLİ GÜNCELLE',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.white),
                ),
              ),
              const SizedBox(height: 32),
              const Text("Tercihler", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              Consumer<LocationRadarService>(
                builder: (context, radarService, child) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: SwitchListTile(
                      title: const Text('Yakındakiler Radarı', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Konumu izleyip yakındaki kullanıcıları bulur', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      value: radarService.isRadarActive,
                      activeColor: AppColors.primary,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (bool value) {
                        radarService.toggleRadar(value);
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: AppColors.textPrimary),
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        prefixIcon: maxLines == 1 ? Icon(icon, color: AppColors.primary) : null,
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }
}
