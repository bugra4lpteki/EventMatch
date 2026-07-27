import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../core/constants/app_colors.dart';
import '../../events/services/mock_event_service.dart';

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
      _avatarImages = List.from(user.avatarUrls);
    } else if (user.avatarUrl.isNotEmpty) {
      _avatarImages = [user.avatarUrl];
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
    if (pickedFile != null && _avatarImages.length < 3) {
      setState(() {
        _avatarImages.add(pickedFile);
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
        final tags = _tagsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        
        await context.read<MockEventService>().updateCurrentUser(
          name: _nameController.text,
          username: _usernameController.text,
          city: _cityController.text,
          gender: _selectedGender,
          aboutMe: _aboutController.text,
          socialLinks: _socialControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList(),
          avatarUrl: _avatarImages.isNotEmpty
              ? (_avatarImages.first is String ? _avatarImages.first as String : '')
              : '',
          avatarImages: _avatarImages,
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
                                child: _avatarImages[index] is String
                                    ? Image.network(_avatarImages[index] as String, fit: BoxFit.cover)
                                    : (kIsWeb
                                        ? Image.network((_avatarImages[index] as XFile).path, fit: BoxFit.cover)
                                        : Image.file(File((_avatarImages[index] as XFile).path), fit: BoxFit.cover)),
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
}
