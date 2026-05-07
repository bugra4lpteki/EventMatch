import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../core/constants/app_colors.dart';
import '../../events/services/mock_event_service.dart';
import '../../events/models/event_model.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _aboutController;
  late TextEditingController _tagsController;
  List<TextEditingController> _socialControllers = [];
  
  String? _selectedGender;
  List<String> _avatarPaths = [];
  List<String> _selectedPastEvents = [];
  
  @override
  void initState() {
    super.initState();
    final user = context.read<MockEventService>().currentUser;
    _nameController = TextEditingController(text: user.name);
    _ageController = TextEditingController(text: user.age ?? '');
    _aboutController = TextEditingController(text: user.aboutMe ?? '');
    _tagsController = TextEditingController(text: user.tags.join(', '));
    _socialControllers = user.socialLinks.map((link) => TextEditingController(text: link)).toList();
    _selectedGender = user.gender;
    if (user.avatarUrls.isNotEmpty) {
      _avatarPaths = List.from(user.avatarUrls);
    } else if (user.avatarUrl.isNotEmpty) {
      _avatarPaths = [user.avatarUrl];
    }
    _selectedPastEvents = List.from(user.pastEvents);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _aboutController.dispose();
    _tagsController.dispose();
    for (var controller in _socialControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage(int index) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        if (index < _avatarPaths.length) {
          _avatarPaths[index] = pickedFile.path;
        } else {
          _avatarPaths.add(pickedFile.path);
        }
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _avatarPaths.removeAt(index);
    });
  }

  void _saveProfile() {
    if (_formKey.currentState!.validate()) {
      final tags = _tagsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      context.read<MockEventService>().updateCurrentUser(
        name: _nameController.text,
        age: _ageController.text,
        gender: _selectedGender,
        aboutMe: _aboutController.text,
        socialLinks: _socialControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList(),
        avatarUrl: _avatarPaths.isNotEmpty ? _avatarPaths.first : '',
        avatarUrls: _avatarPaths,
        tags: tags,
        pastEvents: _selectedPastEvents,
      );
      Navigator.pop(context);
    }
  }

  void _selectPastEvents() {
    final allEvents = context.read<MockEventService>().getAdminEvents();
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: const Text('Geçmiş Etkinlikleri Seç', style: TextStyle(color: Colors.white)),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: ListView.builder(
                  itemCount: allEvents.length,
                  itemBuilder: (context, index) {
                    final event = allEvents[index];
                    final isSelected = _selectedPastEvents.contains(event.id);
                    return CheckboxListTile(
                      activeColor: AppColors.primary,
                      checkColor: Colors.black,
                      title: Text(event.title, style: const TextStyle(color: Colors.white)),
                      subtitle: Text(event.category, style: TextStyle(color: AppColors.textSecondary)),
                      value: isSelected,
                      onChanged: (val) {
                        setDialogState(() {
                          if (val == true) {
                            _selectedPastEvents.add(event.id);
                          } else {
                            _selectedPastEvents.remove(event.id);
                          }
                        });
                        setState(() {});
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('TAMAM', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profili Düzenle', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveProfile,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 3 Avatar Slots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  final hasImage = index < _avatarPaths.length;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: GestureDetector(
                      onTap: () => _pickImage(index),
                      child: Stack(
                        children: [
                          Container(
                            width: 80,
                            height: 100,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: hasImage
                                ? (_avatarPaths[index].startsWith('http') || kIsWeb
                                    ? Image.network(_avatarPaths[index], fit: BoxFit.cover)
                                    : Image.file(File(_avatarPaths[index]), fit: BoxFit.cover))
                                : const Icon(Icons.add_a_photo, color: Colors.grey, size: 30),
                            ),
                          ),
                          if (hasImage)
                            Positioned(
                              top: -5,
                              right: -5,
                              child: GestureDetector(
                                onTap: () => _removeImage(index),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, size: 16, color: Colors.white),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 30),
              
              // İsim
              _buildLabel('İsim'),
              _buildTextField(_nameController, 'İsminiz'),
              
              // Yaş
              _buildLabel('Yaş'),
              _buildTextField(_ageController, 'Yaşınız', keyboardType: TextInputType.number),
              
              // Cinsiyet
              _buildLabel('Cinsiyet'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    dropdownColor: AppColors.surface,
                    value: _selectedGender,
                    hint: const Text('Cinsiyet Seçin', style: TextStyle(color: Colors.grey)),
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                    items: ['Kadın', 'Erkek', 'Belirtmek İstemiyorum'].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value, style: const TextStyle(color: Colors.white)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedGender = val;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Biyografi
              _buildLabel('Hakkımda (Max 500 karakter)'),
              _buildTextField(_aboutController, 'Kendinizden bahsedin', maxLines: 4, maxLength: 500),
              
              // Sosyal Medya
              _buildLabel('Sosyal Bağlantılar (En fazla 5)'),
              ..._socialControllers.asMap().entries.map((entry) {
                int index = entry.key;
                TextEditingController controller = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildTextField(controller, 'Bağlantı URL\'si veya K.Adı'),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                          onPressed: () {
                            setState(() {
                              _socialControllers[index].dispose();
                              _socialControllers.removeAt(index);
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                );
              }),
              if (_socialControllers.length < 5)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: Icon(Icons.add, color: AppColors.primary),
                    label: Text('Bağlantı Ekle', style: TextStyle(color: AppColors.primary)),
                    onPressed: () {
                      setState(() {
                        _socialControllers.add(TextEditingController());
                      });
                    },
                  ),
                ),
              const SizedBox(height: 20),
              
              // Hobiler
              _buildLabel('Hobiler (Virgülle ayırın)'),
              _buildTextField(_tagsController, 'Örn: Müzik, Tiyatro, Doğa'),
              
              // Geçmiş Etkinlikler
              _buildLabel('Geçmiş Etkinlikler'),
              GestureDetector(
                onTap: _selectPastEvents,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedPastEvents.isEmpty ? 'Etkinlik Seç' : '${_selectedPastEvents.length} etkinlik seçildi',
                        style: const TextStyle(color: Colors.white),
                      ),
                      const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {int maxLines = 1, TextInputType? keyboardType, int? maxLength}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey),
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          counterStyle: const TextStyle(color: Colors.grey),
        ),
      ),
    );
  }
}
