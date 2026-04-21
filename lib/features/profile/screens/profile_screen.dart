import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../events/services/mock_event_service.dart';
import '../../events/services/location_radar_service.dart';
import 'settings_screen.dart';

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

  String _avatarUrl = '';
  final ImagePicker _picker = ImagePicker();

  final List<String> _availableTags = [
    'Techno',
    'Tiyatro',
    'Stand-up',
    'Kahve',
    'Gaming',
    'Konser',
    'Yürüyüş',
    'Sinema'
  ];
  List<String> _selectedTags = [];
  List<String> _plannedEvents = [];
  List<String> _pastEvents = [];

  @override
  void initState() {
    super.initState();
    final user = context.read<MockEventService>().currentUser;
    _nameController = TextEditingController(text: user.name);
    _ageController = TextEditingController(text: user.age ?? '');
    _aboutController = TextEditingController(text: user.aboutMe ?? '');
    _avatarUrl = user.avatarUrl;
    _selectedTags = List.from(user.tags);
    _plannedEvents = List.from(user.plannedEvents);
    _pastEvents = List.from(user.pastEvents);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _aboutController.dispose();
    super.dispose();
  }

  void _saveProfile() {
    if (_formKey.currentState!.validate()) {
      context.read<MockEventService>().updateCurrentUser(
            name: _nameController.text,
            age: _ageController.text,
            aboutMe: _aboutController.text,
            avatarUrl: _avatarUrl,
            tags: _selectedTags,
            plannedEvents: _plannedEvents,
            pastEvents: _pastEvents,
          );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profil başarıyla güncellendi!'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Widget _buildImage(String url) {
    if (url.isEmpty) {
      return Icon(Icons.person, size: 60, color: AppColors.primary);
    }

    try {
      if (url.startsWith('http')) {
        return Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(Icons.person, size: 60, color: AppColors.primary),
        );
      } else if (url.startsWith('assets/') || url.contains('images/')) {
        return Image.asset(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(Icons.person, size: 60, color: AppColors.primary),
        );
      } else {
        return Image.file(
          File(url),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(Icons.person, size: 60, color: AppColors.primary),
        );
      }
    } catch (e) {
      return Icon(Icons.person, size: 60, color: AppColors.primary);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<MockEventService>().currentUser;

    return CustomScrollView(
      slivers: [
        _buildSliverAppBar(user),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  _buildPointsBadge(user),
                  const SizedBox(height: 32),
                  _buildSectionHeader('Kişisel Bilgiler'),
                  const SizedBox(height: 16),
                  _buildGlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildTextField(
                          controller: _nameController,
                          label: 'Ad Soyad',
                          icon: Icons.person_outline,
                        ),
                        const Divider(color: Colors.white10, height: 32),
                        _buildTextField(
                          controller: _ageController,
                          label: 'Yaş',
                          icon: Icons.cake_outlined,
                          keyboardType: TextInputType.number,
                        ),
                        const Divider(color: Colors.white10, height: 32),
                        _buildTextField(
                          controller: _aboutController,
                          label: 'Hakkımda',
                          icon: Icons.notes_outlined,
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildSectionHeader('İlgi Alanları'),
                  const SizedBox(height: 16),
                  _buildInterestsWrap(),
                  const SizedBox(height: 32),
                  _buildSectionHeader('Etkinlik Yolculuğum'),
                  const SizedBox(height: 16),
                  _buildProfileEventList(
                      "Gitmeyi Düşündüklerim", _plannedEvents, true),
                  const SizedBox(height: 20),
                  _buildProfileEventList("Geçmiş Katılımlarım", _pastEvents, false),
                  const SizedBox(height: 32),
                  _buildSectionHeader('Tercihler'),
                  const SizedBox(height: 16),
                  _buildRadarSettings(),
                  const SizedBox(height: 40),
                  _buildUpdateButton(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSliverAppBar(user) {
    return SliverAppBar(
      expandedHeight: 240,
      pinned: true,
      backgroundColor: AppColors.background,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary.withOpacity(0.4), Colors.transparent],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryVariant],
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 55,
                        backgroundColor: AppColors.surface,
                        child: ClipOval(
                          child: SizedBox(
                            width: 110,
                            height: 110,
                            child: _avatarUrl.isNotEmpty
                                ? _buildImage(_avatarUrl)
                                : Icon(Icons.person,
                                    size: 50, color: AppColors.primary),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: _buildCircularIconButton(
                        icon: Icons.camera_alt,
                        onPressed: _showImagePickerSource,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  user.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.settings_outlined, color: AppColors.primary),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SettingsScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildPointsBadge(user) {
    return _buildGlassCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TOPLAM PUAN',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${user.points}',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (user.badges.isNotEmpty)
            Row(
              children: user.badges.take(3).map<Widget>((badge) {
                return Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Tooltip(
                    message: badge,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppColors.primary.withOpacity(0.3)),
                      ),
                      child: Icon(_getBadgeIcon(badge),
                          color: AppColors.primary, size: 20),
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildInterestsWrap() {
    return _buildGlassCard(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _availableTags.map<Widget>((tag) {
          final isSelected = _selectedTags.contains(tag);
          return FilterChip(
            label: Text(tag),
            selected: isSelected,
            onSelected: (bool selected) {
              setState(() {
                if (selected) {
                  _selectedTags.add(tag);
                } else {
                  _selectedTags.remove(tag);
                }
              });
            },
            selectedColor: AppColors.primary.withOpacity(0.2),
            checkmarkColor: AppColors.primary,
            backgroundColor: Colors.transparent,
            labelStyle: TextStyle(
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              fontSize: 13,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                  color: isSelected ? AppColors.primary : AppColors.surface),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildProfileEventList(String title, List<String> eventIds, bool isPlanned) {
    final eventService = context.read<MockEventService>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title,
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            IconButton(
              icon: Icon(Icons.add_circle_outline, color: AppColors.primary, size: 20),
              onPressed: () => _showAddEventDialog(isPlanned),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (eventIds.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text("Henüz bir etkinlik yok",
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: eventIds.map<Widget>((id) {
                final ev = eventService.getEventById(id);
                if (ev == null) return const SizedBox.shrink();
                return _buildCompactEventCard(ev, isPlanned);
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildCompactEventCard(ev, bool isPlanned) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: SizedBox(
              height: 90,
              width: double.infinity,
              child: _buildImage(ev.imageUrl),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ev.title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  ev.category,
                  style: TextStyle(color: AppColors.primary, fontSize: 10),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isPlanned) {
                        _plannedEvents.remove(ev.id);
                      } else {
                        _pastEvents.remove(ev.id);
                      }
                    });
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.delete_outline,
                          color: Colors.redAccent, size: 14),
                      const SizedBox(width: 4),
                      Text('Kaldır',
                          style:
                              TextStyle(color: Colors.redAccent, fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadarSettings() {
    return Consumer<LocationRadarService>(
      builder: (context, radarService, child) {
        return _buildGlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Yakındakiler Radarı',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                subtitle: Text('Etrafındaki kullanıcıları bul',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
                value: radarService.isRadarActive,
                activeColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
                onChanged: (bool value) => radarService.toggleRadar(value),
              ),
              if (radarService.isRadarActive) ...[
                const Divider(color: Colors.white10),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Arama Çapı',
                        style: TextStyle(color: AppColors.textSecondary)),
                    Text('${radarService.radarDistanceKm.toInt()} km',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                Slider(
                  value: radarService.radarDistanceKm,
                  min: 1.0,
                  max: 50.0,
                  activeColor: AppColors.primary,
                  onChanged: (val) => radarService.updateRadarDistance(val),
                ),
              ]
            ],
          ),
        );
      },
    );
  }

  Widget _buildUpdateButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryVariant],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: const Text(
          'DEĞİŞİKLİKLERİ KAYDET',
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child, EdgeInsets? padding}) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: child,
    );
  }

  Widget _buildCircularIconButton(
      {required IconData icon, required VoidCallback onPressed}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 20),
        onPressed: onPressed,
      ),
    );
  }

  void _showImagePickerSource() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Profil Fotoğrafı',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildSourceOption(
                    icon: Icons.photo_library,
                    label: 'Galeri',
                    onTap: () async {
                      Navigator.pop(context);
                      final image =
                          await _picker.pickImage(source: ImageSource.gallery);
                      if (image != null) setState(() => _avatarUrl = image.path);
                    },
                  ),
                  _buildSourceOption(
                    icon: Icons.camera_alt,
                    label: 'Kamera',
                    onTap: () async {
                      Navigator.pop(context);
                      final image =
                          await _picker.pickImage(source: ImageSource.camera);
                      if (image != null) setState(() => _avatarUrl = image.path);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSourceOption(
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.surface),
            ),
            child: Icon(icon, color: AppColors.primary, size: 30),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(right: 12.0),
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 4),
      ),
    );
  }

  void _showAddEventDialog(bool isPlanned) {
    final eventService = context.read<MockEventService>();
    final allEvents = eventService.allEvents;
    final currentList = isPlanned ? _plannedEvents : _pastEvents;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            Text(isPlanned ? 'Etkinlik Planla' : 'Geçmiş Etkinlik Ekle',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(24),
                itemCount: allEvents.length,
                itemBuilder: (context, index) {
                  final event = allEvents[index];
                  if (currentList.contains(event.id)) return const SizedBox.shrink();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(event.imageUrl,
                            width: 50, height: 50, fit: BoxFit.cover),
                      ),
                      title: Text(event.title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold)),
                      subtitle: Text(event.category,
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                      onTap: () {
                        setState(() {
                          if (isPlanned) {
                            _plannedEvents.add(event.id);
                          } else {
                            _pastEvents.add(event.id);
                          }
                        });
                        Navigator.pop(context);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getBadgeIcon(String badge) {
    switch (badge) {
      case 'Sahne Tozu Yutmuş':
        return Icons.theater_comedy;
      case 'Sinema Sever':
        return Icons.movie_filter;
      case 'Müzik Tutkunu':
        return Icons.music_note;
      default:
        return Icons.emoji_events;
    }
  }
}
