import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../events/models/event_model.dart';
import '../../events/services/mock_event_service.dart';

class EventFormScreen extends StatefulWidget {
  final EventModel? event;
  final bool isCommunityMeetup;

  const EventFormScreen({
    super.key,
    this.event,
    this.isCommunityMeetup = false,
  });

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _locationController;
  late TextEditingController _descriptionController;
  late TextEditingController _imageUrlController;
  late TextEditingController _categoryController;
  late TextEditingController _priceController;

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  bool _isFree = true;
  bool _isUploadingImage = false;
  double? _selectedLat = 41.0082; // İstanbul varsayılanı
  double? _selectedLng = 28.9784;
  String _selectedCity = 'İstanbul';

  static const List<Map<String, dynamic>> _presetCities = [
    {'name': 'İstanbul', 'lat': 41.0082, 'lng': 28.9784},
    {'name': 'Ankara', 'lat': 39.9334, 'lng': 32.8597},
    {'name': 'İzmir', 'lat': 38.4237, 'lng': 27.1428},
    {'name': 'Antalya', 'lat': 36.8969, 'lng': 30.7133},
    {'name': 'Bursa', 'lat': 40.1885, 'lng': 29.0610},
    {'name': 'Eskişehir', 'lat': 39.7767, 'lng': 30.5206},
  ];

  static const List<Map<String, String>> _presetCovers = [
    {
      'label': '☕ Kahve & Sohbet',
      'url': 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?q=80&w=1200&auto=format&fit=crop',
      'cat': 'Buluşma',
    },
    {
      'label': '🎸 Konser',
      'url': 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?q=80&w=1200&auto=format&fit=crop',
      'cat': 'Konser',
    },
    {
      'label': '🎪 Festival',
      'url': 'https://images.unsplash.com/photo-1533174072545-7a4b6ad7a6c3?q=80&w=1200&auto=format&fit=crop',
      'cat': 'Festival',
    },
    {
      'label': '🎭 Tiyatro & Kültür',
      'url': 'https://images.unsplash.com/photo-1507676184212-d03ab07a01bf?q=80&w=1200&auto=format&fit=crop',
      'cat': 'Tiyatro',
    },
    {
      'label': '🎤 Stand-up & Mizah',
      'url': 'https://images.unsplash.com/photo-1585699324551-f6c309eedeca?q=80&w=1200&auto=format&fit=crop',
      'cat': 'Stand-up',
    },
    {
      'label': '🌿 Doğa & Yürüyüş',
      'url': 'https://images.unsplash.com/photo-1551632811-561732d1e306?q=80&w=1200&auto=format&fit=crop',
      'cat': 'Açık Hava',
    },
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.event?.title ?? '');
    _locationController = TextEditingController(text: widget.event?.location ?? 'Kadıköy, İstanbul');
    _descriptionController = TextEditingController(text: widget.event?.description ?? '');
    _imageUrlController = TextEditingController(
      text: widget.event?.imageUrl ?? _presetCovers.first['url']!,
    );
    _categoryController = TextEditingController(
      text: widget.event?.category ?? (widget.isCommunityMeetup ? 'Buluşma' : 'Konser'),
    );
    _priceController = TextEditingController(text: widget.event?.price ?? '');
    _selectedDate = widget.event?.dateTime ?? DateTime.now().add(const Duration(days: 1));
    _selectedLat = widget.event?.latitude ?? 41.0082;
    _selectedLng = widget.event?.longitude ?? 28.9784;
    _isFree = widget.event?.price == null || widget.event!.price!.isEmpty || widget.event!.price!.toLowerCase().contains('ücretsiz');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    _categoryController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );

    if (pickedFile == null) return;

    setState(() => _isUploadingImage = true);

    try {
      final bytes = await pickedFile.readAsBytes();
      final ext = pickedFile.name.split('.').last.toLowerCase();
      final fileName = 'event_${DateTime.now().millisecondsSinceEpoch}_${UniqueKey().toString().replaceAll('#', '')}.$ext';
      final supabase = Supabase.instance.client;

      // chat-media veya event-images bucket'ına yükleme
      String bucket = 'chat-media';
      try {
        await supabase.storage.from(bucket).uploadBinary(
          fileName,
          bytes,
          fileOptions: FileOptions(contentType: 'image/$ext'),
        );
      } catch (_) {
        bucket = 'avatars';
        await supabase.storage.from(bucket).uploadBinary(
          fileName,
          bytes,
          fileOptions: FileOptions(contentType: 'image/$ext'),
        );
      }

      final publicUrl = supabase.storage.from(bucket).getPublicUrl(fileName);
      setState(() {
        _imageUrlController.text = publicUrl;
        _isUploadingImage = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fotoğraf başarıyla yüklendi! 📸')),
        );
      }
    } catch (e) {
      setState(() => _isUploadingImage = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Görsel yüklenemedi: $e')),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
            dialogBackgroundColor: AppColors.background,
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDate),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.dark(
                primary: AppColors.primary,
                onPrimary: Colors.white,
                surface: AppColors.surface,
                onSurface: AppColors.textPrimary,
              ),
              dialogBackgroundColor: AppColors.background,
            ),
            child: child!,
          );
        },
      );

      if (time != null) {
        setState(() {
          _selectedDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  void _saveEvent() {
    if (!_formKey.currentState!.validate()) return;

    final eventService = context.read<MockEventService>();
    final newCategory = _categoryController.text.trim();

    if (newCategory.isNotEmpty) {
      eventService.addCategory(newCategory);
    }

    final currentUid = eventService.currentUserId;
    final isEditing = widget.event != null;

    final newEvent = EventModel(
      id: widget.event?.id ?? 'event_ugc_${DateTime.now().millisecondsSinceEpoch}',
      title: _titleController.text.trim(),
      category: newCategory.isNotEmpty ? newCategory : 'Genel',
      location: _locationController.text.trim(),
      dateTime: _selectedDate,
      description: _descriptionController.text.trim(),
      imageUrl: _imageUrlController.text.trim().isNotEmpty
          ? _imageUrlController.text.trim()
          : _presetCovers.first['url']!,
      latitude: _selectedLat,
      longitude: _selectedLng,
      price: _isFree ? 'Ücretsiz' : _priceController.text.trim(),
      creatorId: widget.event?.creatorId ?? currentUid,
      isUserCreated: widget.isCommunityMeetup || (widget.event?.isUserCreated ?? true),
      attendees: widget.event?.attendees ?? [eventService.currentUser],
      isActive: widget.event?.isActive ?? true,
      atmosphere: widget.isCommunityMeetup ? 'Samimi & Eğlenceli' : 'Canlı',
    );

    HapticFeedback.mediumImpact();

    if (!isEditing) {
      eventService.addEvent(newEvent);
      // Etkinliği oluşturan kişiyi otomatik katılımcı yap
      eventService.joinEvent(newEvent.id, newEvent);
    } else {
      eventService.updateEvent(newEvent);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.greenAccent),
            const SizedBox(width: 8),
            Text(
              isEditing ? 'Etkinlik güncellendi! ✨' : 'Etkinlik / Buluşma başarıyla yayınlandı! 🎉',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: Colors.grey.shade900,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.event != null;
    final screenTitle = isEditing
        ? 'Etkinliği Düzenle'
        : (widget.isCommunityMeetup ? 'Buluşma / Etkinlik Oluştur' : 'Yeni Etkinlik');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          screenTitle,
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        leading: BackButton(color: AppColors.primary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cover Preview & Upload Card
              _buildCoverImageCard(),
              const SizedBox(height: 20),

              // Title Field
              _buildTextField(
                controller: _titleController,
                label: 'Buluşma / Etkinlik Başlığı',
                hint: 'Örn: Kadıköy Akustik Jam & Kahve Buluşması',
                prefixIcon: Icons.local_activity_rounded,
                validator: (v) => v == null || v.trim().isEmpty ? 'Başlık girmelisiniz' : null,
              ),
              const SizedBox(height: 16),

              // Category Selector / Autocomplete
              _buildCategorySelector(),
              const SizedBox(height: 16),

              // City Quick Select
              _buildCitySelector(),
              const SizedBox(height: 12),

              // Location Detail Field
              _buildTextField(
                controller: _locationController,
                label: 'Mekan / Adres',
                hint: 'Örn: Moda Sahil / Kadıköy, İstanbul',
                prefixIcon: Icons.location_on_rounded,
                validator: (v) => v == null || v.trim().isEmpty ? 'Mekan girmelisiniz' : null,
              ),
              const SizedBox(height: 16),

              // Date & Time Picker
              _buildDatePickerButton(context),
              const SizedBox(height: 16),

              // Price & Free Toggle
              _buildPriceSection(),
              const SizedBox(height: 16),

              // Description Field
              _buildTextField(
                controller: _descriptionController,
                label: 'Açıklama & Detaylar',
                hint: 'Buluşmada ne yapacağız? Kimler katılmalı? Detayları paylaş...',
                prefixIcon: Icons.description_rounded,
                maxLines: 4,
                validator: (v) => v == null || v.trim().isEmpty ? 'Açıklama girmelisiniz' : null,
              ),
              const SizedBox(height: 28),

              // Submit Button
              ElevatedButton(
                onPressed: _saveEvent,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.primary,
                  elevation: 6,
                  shadowColor: AppColors.primary.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                child: Text(
                  isEditing ? 'GÜNCELLE' : 'YAYINLA VE BAŞLAT 🚀',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoverImageCard() {
    final imgUrl = _imageUrlController.text.trim();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Kapak Fotoğrafı',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton.icon(
                onPressed: _isUploadingImage ? null : _pickAndUploadImage,
                icon: _isUploadingImage
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent),
                      )
                    : const Icon(Icons.photo_library_rounded, size: 16, color: Colors.cyanAccent),
                label: Text(
                  _isUploadingImage ? 'Yükleniyor...' : 'Galeriden Seç',
                  style: const TextStyle(color: Colors.cyanAccent, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Image Preview Container
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 150,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imgUrl.isNotEmpty)
                    Image.network(
                      imgUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.black26,
                        child: const Icon(Icons.broken_image_rounded, color: Colors.white38, size: 40),
                      ),
                    )
                  else
                    Container(
                      color: Colors.black26,
                      child: const Icon(Icons.image_rounded, color: Colors.white24, size: 48),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.6)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Preset chips
          Text(
            'Veya hazır konseptlerden seçin:',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _presetCovers.map((cover) {
                final isCurrent = _imageUrlController.text == cover['url'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(cover['label']!, style: const TextStyle(fontSize: 11)),
                    selected: isCurrent,
                    selectedColor: AppColors.primary.withValues(alpha: 0.3),
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                    labelStyle: TextStyle(
                      color: isCurrent ? AppColors.primaryVariant : Colors.white70,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _imageUrlController.text = cover['url']!;
                          _categoryController.text = cover['cat']!;
                        });
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Consumer<MockEventService>(
      builder: (context, eventService, child) {
        return Autocomplete<String>(
          initialValue: TextEditingValue(text: _categoryController.text),
          optionsBuilder: (TextEditingValue textEditingValue) {
            final query = textEditingValue.text.toLowerCase();
            return eventService.categories.where((c) => c != 'Tümü' && c.toLowerCase().contains(query));
          },
          onSelected: (String selection) {
            _categoryController.text = selection;
          },
          fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
            return TextFormField(
              controller: textEditingController,
              focusNode: focusNode,
              style: TextStyle(color: AppColors.textPrimary),
              onChanged: (val) => _categoryController.text = val,
              decoration: InputDecoration(
                labelText: 'Kategori',
                hintText: 'Örn: Buluşma, Konser, Kahve, Tiyatro...',
                labelStyle: TextStyle(color: AppColors.textSecondary),
                hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5), fontSize: 13),
                prefixIcon: Icon(Icons.category_rounded, color: AppColors.primary),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Kategori seçmelisiniz' : null,
            );
          },
        );
      },
    );
  }

  Widget _buildCitySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text('Şehir:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _presetCities.map((city) {
              final isSelected = _selectedCity == city['name'];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(city['name']),
                  selected: isSelected,
                  selectedColor: AppColors.primary.withValues(alpha: 0.35),
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedCity = city['name'];
                        _selectedLat = (city['lat'] as num).toDouble();
                        _selectedLng = (city['lng'] as num).toDouble();
                        if (!_locationController.text.contains(city['name'])) {
                          _locationController.text = '${city['name']}';
                        }
                      });
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePickerButton(BuildContext context) {
    final formattedDate =
        '${_selectedDate.day.toString().padLeft(2, '0')}.${_selectedDate.month.toString().padLeft(2, '0')}.${_selectedDate.year} ${_selectedDate.hour.toString().padLeft(2, '0')}:${_selectedDate.minute.toString().padLeft(2, '0')}';

    return GestureDetector(
      onTap: () => _selectDate(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_month_rounded, color: AppColors.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tarih ve Saat', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(
                    formattedDate,
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 14.5, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.confirmation_number_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text('Ücretsiz Buluşma', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
              Switch.adaptive(
                value: _isFree,
                activeColor: AppColors.primary,
                onChanged: (val) {
                  setState(() {
                    _isFree = val;
                    if (val) _priceController.text = 'Ücretsiz';
                  });
                },
              ),
            ],
          ),
          if (!_isFree) ...[
            const SizedBox(height: 8),
            _buildTextField(
              controller: _priceController,
              label: 'Tahmini Ücret / Bilet Fiyatı',
              hint: 'Örn: 250 ₺',
              prefixIcon: Icons.payments_rounded,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? prefixIcon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(color: AppColors.textPrimary, fontSize: 14.5),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
        hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.45), fontSize: 12.5),
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: AppColors.primary, size: 20) : null,
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
      validator: validator,
    );
  }
}
