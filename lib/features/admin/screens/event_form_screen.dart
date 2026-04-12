import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../events/models/event_model.dart';
import '../../events/services/mock_event_service.dart';

class EventFormScreen extends StatefulWidget {
  final EventModel? event;

  const EventFormScreen({super.key, this.event});

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
  
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.event?.title ?? '');
    _locationController = TextEditingController(text: widget.event?.location ?? '');
    _descriptionController = TextEditingController(text: widget.event?.description ?? '');
    _imageUrlController = TextEditingController(text: widget.event?.imageUrl ?? '');
    _categoryController = TextEditingController(text: widget.event?.category ?? '');
    _selectedDate = widget.event?.dateTime ?? DateTime.now();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final pickedTime = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
         return Theme(
           data: Theme.of(context).copyWith(
             colorScheme: const ColorScheme.dark(
               primary: AppColors.primary,
               onPrimary: Colors.white,
               surface: AppColors.surface,
               onSurface: AppColors.textPrimary,
             ),
             dialogBackgroundColor: AppColors.background,
           ),
           child: child!,
         );
      }
    );
    if (pickedTime != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDate),
      );
      if (time != null) {
        setState(() {
          _selectedDate = DateTime(
            pickedTime.year, pickedTime.month, pickedTime.day,
            time.hour, time.minute
          );
        });
      }
    }
  }

  void _saveEvent() {
    if (_formKey.currentState!.validate()) {
      final eventService = context.read<MockEventService>();
      final isNewCategory = _categoryController.text.trim();
      
      if (isNewCategory.isNotEmpty) {
        eventService.addCategory(isNewCategory);
      }

      final newEvent = EventModel(
        id: widget.event?.id ?? 'event_${DateTime.now().millisecondsSinceEpoch}',
        title: _titleController.text.trim(),
        category: _categoryController.text.trim(),
        location: _locationController.text.trim(),
        dateTime: _selectedDate,
        description: _descriptionController.text.trim(),
        imageUrl: _imageUrlController.text.trim(),
        attendees: widget.event?.attendees ?? [],
      );

      if (widget.event == null) {
        eventService.addEvent(newEvent);
      } else {
        eventService.updateEvent(newEvent);
      }
      
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.event != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Etkinliği Düzenle' : 'Yeni Etkinlik', style: const TextStyle(color: AppColors.primary)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTextField(_titleController, 'Başlık (Etkinlik Adı)'),
              const SizedBox(height: 16),
              // Category Input (EITHER Autocomplete or just Text)
              Consumer<MockEventService>(
                builder: (context, eventService, child) {
                  return Autocomplete<String>(
                    initialValue: TextEditingValue(text: _categoryController.text),
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text == '') {
                        return eventService.categories.where((c) => c != 'Tümü');
                      }
                      return eventService.categories.where((String option) {
                         return option.toLowerCase().contains(textEditingValue.text.toLowerCase()) && option != 'Tümü';
                      });
                    },
                    onSelected: (String selection) {
                      _categoryController.text = selection;
                    },
                    fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                      return TextFormField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        style: const TextStyle(color: AppColors.textPrimary),
                        onChanged: (val) => _categoryController.text = val,
                        decoration: InputDecoration(
                          labelText: 'Kategori (Örn: Tiyatro, Stand-up veya Yeni Ekle)',
                          labelStyle: const TextStyle(color: AppColors.textSecondary),
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        ),
                        validator: (value) => value == null || value.isEmpty ? 'Gerekli' : null,
                      );
                    },
                  );
                }
              ),
              const SizedBox(height: 16),
              _buildTextField(_locationController, 'Konum (Şehir - Mekan)'),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => _selectDate(context),
                child: Container(
                   padding: const EdgeInsets.all(16),
                   decoration: BoxDecoration(
                     color: AppColors.surface,
                     borderRadius: BorderRadius.circular(16)
                   ),
                   child: Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       Text("Tarih ve Saat: ${_selectedDate.day.toString().padLeft(2,'0')}.${_selectedDate.month.toString().padLeft(2,'0')}.${_selectedDate.year} ${_selectedDate.hour.toString().padLeft(2,'0')}:${_selectedDate.minute.toString().padLeft(2,'0')}", 
                            style: const TextStyle(color: AppColors.textPrimary)),
                       const Icon(Icons.calendar_today, color: AppColors.primary),
                     ],
                   ),
                ),
              ),
              const SizedBox(height: 16),
              _buildTextField(_descriptionController, 'Açıklama', maxLines: 4),
              const SizedBox(height: 16),
              _buildTextField(_imageUrlController, 'Kapak Görsel URL (Unsplash vb.)'),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _saveEvent,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                child: Text(isEditing ? 'GÜNCELLE' : 'OLUŞTUR', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
      validator: (value) => value == null || value.isEmpty ? 'Bu alan boş bırakılamaz' : null,
    );
  }
}
