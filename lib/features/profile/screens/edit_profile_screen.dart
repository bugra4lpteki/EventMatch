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
  late TextEditingController _usernameController;
  late TextEditingController _cityController;
  late TextEditingController _aboutController;
  late TextEditingController _tagsController;
  List<TextEditingController> _socialControllers = [];
  
  String? _selectedGender;
  List<String> _avatarPaths = [];
  List<String> _selectedPastEvents = [];
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    final user = context.read<MockEventService>().currentUser;
    _nameController = TextEditingController(text: user.name);
    _usernameController = TextEditingController(text: user.username ?? '');
    _cityController = TextEditingController(text: user.city ?? '');
    _aboutController = TextEditingController(text: user.aboutMe ?? '');
    _tagsController = TextEditingController(text: user.tags.join(', '));
    _socialControllers = user.socialLinks.map((link) => TextEditingController(text: link)).toList();
    _selectedGender = ['Kadın', 'Erkek', 'Belirtmek İstemiyorum'].contains(user.gender) ? user.gender : null;
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
    _usernameController.dispose();
    _cityController.dispose();
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
    if (pickedFile != null && _avatarPaths.length < 3) {
      setState(() {
        _avatarPaths.add(pickedFile.path);
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _avatarPaths.removeAt(index);
    });
  }

  void _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final tags = _tagsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        
        await context.read<MockEventService>().updateCurrentUser(
          name: _nameController.text,
          username: _usernameController.text,
          city: _cityController.text,
          gender: _selectedGender,
          aboutMe: _aboutController.text,
          socialLinks: _socialControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList(),
          avatarUrl: _avatarPaths.isNotEmpty ? _avatarPaths.first : '',
          avatarUrls: _avatarPaths,
          tags: tags,
          pastEvents: _selectedPastEvents,
        );
        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  void _selectPastEvents() {
    final allEvents = context.read<MockEventService>().getAdminEvents();
    showDialog(
      context: context,
      builder: (context) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredEvents = allEvents.where((e) {
              return e.title.toLowerCase().contains(searchQuery) ||
                     e.category.toLowerCase().contains(searchQuery);
            }).toList();

            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: Text('Geçmiş Etkinlikleri Seç', style: TextStyle(color: AppColors.textPrimary)),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Etkinlik Ara...',
                        hintStyle: TextStyle(color: AppColors.textSecondary),
                        prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                      ),
                      style: TextStyle(color: AppColors.textPrimary),
                      onChanged: (val) {
                        setDialogState(() {
                          searchQuery = val.toLowerCase();
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredEvents.length,
                        itemBuilder: (context, index) {
                          final event = filteredEvents[index];
                          final isSelected = _selectedPastEvents.contains(event.id);
                          return CheckboxListTile(
                            activeColor: AppColors.primary,
                            checkColor: Colors.black,
                            title: Text(event.title, style: TextStyle(color: AppColors.textPrimary)),
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
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('TAMAM', style: TextStyle(color: AppColors.textPrimary)),
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
        title: Text('Profili Düzenle', style: TextStyle(color: AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        actions: [
          _isLoading 
            ? const Center(child: Padding(padding: EdgeInsets.only(right: 16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
            : IconButton(
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
              // Profil Fotoğrafları (Max 3, Sürükle-Bırak)
              _buildLabel('Profil Fotoğrafları (Sürükleyip sıralayabilirsiniz)'),
              SizedBox(
                height: 120,
                child: ReorderableListView(
                  scrollDirection: Axis.horizontal,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (oldIndex < newIndex) {
                        newIndex -= 1;
                      }
                      final item = _avatarPaths.removeAt(oldIndex);
                      _avatarPaths.insert(newIndex, item);
                    });
                  },
                  children: [
                    for (int index = 0; index < _avatarPaths.length; index++)
                      Padding(
                        key: ValueKey(_avatarPaths[index]),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        child: Stack(
                          clipBehavior: Clip.none,
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
                                child: _avatarPaths[index].startsWith('http') || kIsWeb
                                    ? Image.network(_avatarPaths[index], fit: BoxFit.cover)
                                    : Image.file(File(_avatarPaths[index]), fit: BoxFit.cover),
                              ),
                            ),
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
                  ],
                ),
              ),
              if (_avatarPaths.length < 3)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: Icon(Icons.add_a_photo, color: AppColors.primary),
                    label: Text('Fotoğraf Ekle', style: TextStyle(color: AppColors.primary)),
                    onPressed: () => _pickImage(_avatarPaths.length),
                  ),
                ),
              const SizedBox(height: 30),
              
              // İsim
              _buildLabel('İsim'),
              _buildTextField(_nameController, 'İsminiz'),

              // Kullanıcı Adı
              _buildLabel('Kullanıcı Adı'),
              _buildTextField(_usernameController, 'Kullanıcı Adı'),
              
              // Yaş (Sadece Gösterim)
              _buildLabel('Yaş'),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    context.read<MockEventService>().currentUser.age ?? 'Belirtilmedi',
                    style: TextStyle(color: AppColors.textPrimary.withOpacity(0.7), fontSize: 16),
                  ),
                ),
              ),

              // Şehir
              _buildLabel('Şehir'),
              _buildTextField(_cityController, 'Yaşadığınız Şehir'),
              
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
                    icon: Icon(Icons.arrow_drop_down, color: AppColors.textPrimary),
                    items: ['Kadın', 'Erkek', 'Belirtmek İstemiyorum'].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value, style: TextStyle(color: AppColors.textPrimary)),
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
                        style: TextStyle(color: AppColors.textPrimary),
                      ),
                      Icon(Icons.arrow_forward_ios, color: AppColors.textPrimary, size: 16),
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
        style: TextStyle(color: AppColors.textPrimary),
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
