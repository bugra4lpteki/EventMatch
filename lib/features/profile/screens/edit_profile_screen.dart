import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../core/constants/app_colors.dart';
import '../../events/services/mock_event_service.dart';
import '../widgets/image_scale_dialog.dart';

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
  List<dynamic> _avatarImages = [];
  List<String> _selectedPastEvents = [];
  List<String> _selectedPlannedEvents = [];
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
    final validUrls = user.avatarUrls
        .where((u) => u.isNotEmpty && u != 'assets/images/user_avatar.jpg')
        .toList();
    if (validUrls.isNotEmpty) {
      _avatarImages = List.from(validUrls);
    } else if (user.avatarUrl.isNotEmpty && user.avatarUrl != 'assets/images/user_avatar.jpg') {
      _avatarImages = [user.avatarUrl];
    } else {
      _avatarImages = [];
    }
    _selectedPastEvents = List.from(user.pastEvents);
    _selectedPlannedEvents = List.from(user.plannedEvents);
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
    if (pickedFile != null && mounted) {
      final croppedFile = await ImageScaleDialog.show(context, pickedFile);
      if (croppedFile != null && mounted) {
        setState(() {
          if (index < _avatarImages.length) {
            _avatarImages[index] = croppedFile;
          } else if (_avatarImages.length < 3) {
            _avatarImages.add(croppedFile);
          }
        });
      }
    }
  }

  void _showPhotoOptions(int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.photo_library, color: AppColors.primary),
                title: Text('Galeriden Değiştir', style: TextStyle(color: AppColors.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(index);
                },
              ),
              ListTile(
                leading: Icon(Icons.crop_rotate, color: AppColors.primary),
                title: Text('Kırp ve Ölçeklendir', style: TextStyle(color: AppColors.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  _editImageScale(index);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Fotoğrafı Kaldır', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  _removeImage(index);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editImageScale(int index) async {
    final currentImage = _avatarImages[index];
    final croppedFile = await ImageScaleDialog.show(context, currentImage);
    if (croppedFile != null && mounted) {
      setState(() {
        _avatarImages[index] = croppedFile;
      });
    }
  }

  void _removeImage(int index) async {
    final image = _avatarImages[index];
    if (image is String && image.startsWith('http')) {
      setState(() => _isLoading = true);
      try {
        await context.read<MockEventService>().deleteUploadedPhoto(image);
        setState(() {
          _avatarImages.removeAt(index);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fotoğraf başarıyla silindi.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fotoğraf silinemedi: $e'), backgroundColor: AppColors.error),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } else {
      setState(() {
        _avatarImages.removeAt(index);
      });
    }
  }

  void _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final eventService = context.read<MockEventService>();
        final currentUserId = eventService.currentUser.id;
        final newUsername = _usernameController.text.trim().toLowerCase().replaceAll('@', '');
        
        if (newUsername.isNotEmpty && newUsername != (eventService.currentUser.username ?? '').toLowerCase().replaceAll('@', '')) {
          final isTaken = await eventService.isUsernameTaken(newUsername, excludeUserId: currentUserId);
          if (isTaken) {
            if (mounted) {
              setState(() => _isLoading = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Bu kullanıcı adı zaten alınmış. Lütfen başka bir kullanıcı adı seçin.'),
                  backgroundColor: AppColors.error,
                ),
              );
            }
            return;
          }
        }

        final tags = _tagsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        
        await eventService.updateCurrentUser(
          name: _nameController.text.trim(),
          username: newUsername.isNotEmpty ? newUsername : _usernameController.text.trim(),
          city: _cityController.text,
          gender: _selectedGender,
          aboutMe: _aboutController.text,
          socialLinks: _socialControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList(),
          avatarUrl: _avatarImages.isNotEmpty
              ? (_avatarImages.first is String ? _avatarImages.first as String : '')
              : '',
          avatarImages: _avatarImages,
          tags: tags,
          plannedEvents: _selectedPlannedEvents,
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



  static const List<String> _turkiyeSehirleri = [
    'Adana', 'Adıyaman', 'Afyonkarahisar', 'Ağrı', 'Aksaray', 'Amasya', 'Ankara', 'Antalya', 'Ardahan', 'Artvin',
    'Aydın', 'Balıkesir', 'Bartın', 'Batman', 'Bayburt', 'Bilecik', 'Bingöl', 'Bitlis', 'Bolu', 'Burdur',
    'Bursa', 'Çanakkale', 'Çankırı', 'Çorum', 'Denizli', 'Diyarbakır', 'Düzce', 'Edirne', 'Elazığ', 'Erzincan',
    'Erzurum', 'Eskişehir', 'Gaziantep', 'Giresun', 'Gümüşhane', 'Hakkari', 'Hatay', 'Iğdır', 'Isparta', 'İstanbul',
    'İzmir', 'Kahramanmaraş', 'Karabük', 'Karaman', 'Kars', 'Kastamonu', 'Kayseri', 'Kilis', 'Kırıkkale', 'Kırklareli',
    'Kırşehir', 'Kocaeli', 'Konya', 'Kütahya', 'Malatya', 'Manisa', 'Mardin', 'Mersin', 'Muğla', 'Muş',
    'Nevşehir', 'Niğde', 'Ordu', 'Osmaniye', 'Rize', 'Sakarya', 'Samsun', 'Şanlıurfa', 'Siirt', 'Sinop',
    'Sivas', 'Şırnak', 'Tekirdağ', 'Tokat', 'Trabzon', 'Tunceli', 'Uşak', 'Van', 'Yalova', 'Yozgat',
    'Zonguldak'
  ];

  void _showCityPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredCities = _turkiyeSehirleri.where((sehir) {
              final query = searchQuery.toLowerCase();
              return sehir.toLowerCase().contains(query) ||
                     sehir.toLowerCase().replaceAll('i', 'ı').replaceAll('ı', 'i').contains(query);
            }).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Text(
                        'Şehir Seçiniz',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Şehir Ara...',
                          hintStyle: TextStyle(color: AppColors.textSecondary),
                          prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                        ),
                        style: TextStyle(color: AppColors.textPrimary),
                        onChanged: (val) {
                          setDialogState(() {
                            searchQuery = val;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: filteredCities.length,
                          itemBuilder: (context, index) {
                            final sehir = filteredCities[index];
                            final isSelected = _cityController.text == sehir;
                            return ListTile(
                              title: Text(
                                sehir,
                                style: TextStyle(
                                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              trailing: isSelected 
                                  ? Icon(Icons.check, color: AppColors.primary) 
                                  : null,
                              onTap: () {
                                setState(() {
                                  _cityController.text = sehir;
                                });
                                Navigator.pop(context);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
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
                      final item = _avatarImages.removeAt(oldIndex);
                      _avatarImages.insert(newIndex, item);
                    });
                  },
                  children: [
                    for (int index = 0; index < _avatarImages.length; index++)
                      Padding(
                        key: ValueKey(_avatarImages[index]),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            GestureDetector(
                              onTap: () => _showPhotoOptions(index),
                              child: Container(
                                width: 80,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: _buildAvatarPreview(_avatarImages[index]),
                                ),
                              ),
                            ),
                            // Edit / Scale Button
                            Positioned(
                              bottom: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => _editImageScale(index),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.7),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.primary, width: 1),
                                  ),
                                  child: Icon(Icons.crop_rotate, size: 12, color: AppColors.primary),
                                ),
                              ),
                            ),
                            Positioned(
                              top: -4,
                              right: -4,
                              child: GestureDetector(
                                onTap: () => _removeImage(index),
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.85),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white24, width: 1),
                                  ),
                                  child: const Icon(Icons.close, size: 12, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (_avatarImages.length < 3)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: Icon(Icons.add_a_photo, color: AppColors.primary),
                    label: Text('Fotoğraf Ekle', style: TextStyle(color: AppColors.primary)),
                    onPressed: () => _pickImage(_avatarImages.length),
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
              _buildTextField(
                _cityController,
                'Yaşadığınız Şehir',
                readOnly: true,
                onTap: _showCityPicker,
              ),
              
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
              
              const SizedBox(height: 30),
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

  Widget _buildTextField(TextEditingController controller, String hint, {int maxLines = 1, TextInputType? keyboardType, int? maxLength, bool readOnly = false, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        keyboardType: keyboardType,
        readOnly: readOnly,
        onTap: onTap,
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

  Widget _buildAvatarPreview(dynamic imageItem) {
    Widget fallback = Container(
      color: AppColors.surface,
      child: Center(
        child: Icon(Icons.person, color: AppColors.primary, size: 36),
      ),
    );

    if (imageItem is String) {
      final str = imageItem.trim();
      if (str.isEmpty || str == 'assets/images/user_avatar.jpg') {
        return fallback;
      }
      if (str.startsWith('http')) {
        return Image.network(
          str,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback,
        );
      } else if (str.startsWith('assets/')) {
        return Image.asset(
          str,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback,
        );
      } else {
        try {
          final file = File(str);
          if (file.existsSync()) {
            return Image.file(
              file,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback,
            );
          }
        } catch (_) {}
        return fallback;
      }
    } else if (imageItem is XFile) {
      if (kIsWeb) {
        return Image.network(
          imageItem.path,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback,
        );
      } else {
        return Image.file(
          File(imageItem.path),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback,
        );
      }
    }
    return fallback;
  }
}
