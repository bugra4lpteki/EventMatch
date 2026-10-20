import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/url_launcher_helper.dart';
import '../models/after_party_spot_model.dart';
import '../models/event_model.dart';
import '../services/after_party_service.dart';
import '../services/mock_event_service.dart';

class AfterPartySheet extends StatefulWidget {
  final EventModel event;

  const AfterPartySheet({super.key, required this.event});

  static Future<void> show(BuildContext context, {required EventModel event}) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AfterPartySheet(event: event),
    );
  }

  @override
  State<AfterPartySheet> createState() => _AfterPartySheetState();
}

class _AfterPartySheetState extends State<AfterPartySheet> {
  String _selectedCategory = 'Tümü';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSpots();
  }

  Future<void> _loadSpots() async {
    await AfterPartyService().getSpotsForEvent(widget.event);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _openMapDirections(double lat, double lng, String name) {
    HapticFeedback.selectionClick();
    final url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&destination_name=${Uri.encodeComponent(name)}';
    UrlLauncherHelper.launchURL(url);
  }

  void _showAddSpotDialog() {
    final nameCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String cat = 'Toplanma Noktası';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottom = MediaQuery.of(context).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, bottom + 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Toplanma Noktası Belirt 🍻',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white60),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Mekan / Buluşma Noktası Adı',
                      labelStyle: const TextStyle(color: Colors.white60),
                      hintText: 'Örn: Kadıköy Moda Sahili Çimler',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: cat,
                    dropdownColor: const Color(0xFF26263A),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Kategori',
                      labelStyle: const TextStyle(color: Colors.white60),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Toplanma Noktası', child: Text('Toplanma Noktası')),
                      DropdownMenuItem(value: 'Pub & Bira', child: Text('Pub & Bira')),
                      DropdownMenuItem(value: 'Kokteyl & Bar', child: Text('Kokteyl & Bar')),
                      DropdownMenuItem(value: 'Gece Kulübü', child: Text('Gece Kulübü')),
                      DropdownMenuItem(value: 'Gece Atıştırmalığı', child: Text('Gece Atıştırmalığı')),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => cat = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Açıklama / Buluşma Notu',
                      labelStyle: const TextStyle(color: Colors.white60),
                      hintText: 'Örn: Konser bitişi ana kapıda toplanıp birlikte geçiyoruz.',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) return;

                        final eventService = context.read<MockEventService>();
                        final user = eventService.currentUser;

                        AfterPartyService().addCustomSpot(
                          event: widget.event,
                          name: name,
                          category: cat,
                          note: noteCtrl.text.trim(),
                          creatorName: user.name,
                          creatorId: user.id,
                        );

                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$name toplanma noktası olarak eklendi! 🎉'),
                            backgroundColor: const Color(0xFF10B981),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add_location_alt_rounded, size: 18),
                      label: const Text('Toplanma Noktasını Yayınla', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final afterPartyService = AfterPartyService();

    return AnimatedBuilder(
      animation: afterPartyService,
      builder: (context, _) {
        final allSpots = afterPartyService.getCachedSpots(widget.event.id);
        final filteredSpots = _selectedCategory == 'Tümü'
            ? allSpots
            : allSpots.where((s) => s.category.contains(_selectedCategory)).toList();

        final totalAttendees = allSpots.fold<int>(0, (sum, s) => sum + s.attendeeNames.length);

        return Container(
          height: MediaQuery.of(context).size.height * 0.88,
          decoration: const BoxDecoration(
            color: Color(0xFF111119),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Scaffold(
                backgroundColor: Colors.transparent,
                body: Column(
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),

                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text('🍸', style: TextStyle(fontSize: 20)),
                                  const SizedBox(width: 8),
                                  Text(
                                    'After Party & Çevre Mekanlar',
                                    style: GoogleFonts.outfit(
                                      fontSize: 19,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${widget.event.title} • $totalAttendees kişi toplanıyor',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.6),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white70),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white10, height: 1),

                    // Filter Chips Bar
                    Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          _buildFilterChip('Tümü'),
                          _buildFilterChip('Pub'),
                          _buildFilterChip('Bar'),
                          _buildFilterChip('Gece Kulübü'),
                          _buildFilterChip('Toplanma Noktası'),
                        ],
                      ),
                    ),

                    // Spots List
                    Expanded(
                      child: _isLoading
                          ? Center(
                              child: CircularProgressIndicator(color: AppColors.primary),
                            )
                          : filteredSpots.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.local_bar_outlined, color: Colors.white30, size: 48),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Bu kategoride mekan bulunamadı.',
                                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                                  itemCount: filteredSpots.length,
                                  itemBuilder: (context, index) {
                                    final spot = filteredSpots[index];
                                    return _buildSpotCard(spot, afterPartyService);
                                  },
                                ),
                    ),
                  ],
                ),
                bottomSheet: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF181824),
                    border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
                  ),
                  child: SafeArea(
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _showAddSpotDialog,
                        icon: const Icon(Icons.add_location_alt_rounded, size: 18),
                        label: const Text(
                          '+ Kendi Toplanma Noktanı / Masanı Belirt',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 4,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedCategory == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) {
          HapticFeedback.selectionClick();
          setState(() => _selectedCategory = label);
        },
        selectedColor: AppColors.primary,
        backgroundColor: Colors.white.withValues(alpha: 0.06),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.white70,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: isSelected ? AppColors.primary : Colors.white10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }

  Widget _buildSpotCard(AfterPartySpotModel spot, AfterPartyService service) {
    final isJoined = service.isUserJoined(spot.id);
    final user = context.read<MockEventService>().currentUser;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isJoined ? const Color(0xFF10B981).withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.07),
          width: isJoined ? 1.4 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Icon Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _getCategoryColor(spot.category).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getCategoryIcon(spot.category),
                  color: _getCategoryColor(spot.category),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              // Name and Category
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spot.name,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          spot.category,
                          style: TextStyle(
                            color: _getCategoryColor(spot.category),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (spot.isUserCreated) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('Topluluk Noktası', style: TextStyle(color: Colors.amberAccent, fontSize: 9.5, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Walking Distance Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.directions_walk_rounded, color: Color(0xFF38BDF8), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${spot.distanceMeters.round()}m • ~${spot.walkingMinutes} dk',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (spot.note != null && spot.note!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Text(
                '💬 "${spot.note}"',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],

          const SizedBox(height: 14),

          // Attendees Row + Buttons
          Row(
            children: [
              // People going avatar counter
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.people_alt_rounded, size: 15, color: Color(0xFF10B981)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        spot.attendeeNames.isEmpty
                            ? 'İlk katılan sen ol!'
                            : '${spot.attendeeNames.length} kişi gidiyor (${spot.attendeeNames.take(2).join(', ')}${spot.attendeeNames.length > 2 ? '...' : ''})',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // Directions button
              IconButton(
                icon: const Icon(Icons.navigation_rounded, color: Color(0xFF38BDF8), size: 20),
                tooltip: 'Haritada Yol Tarifi',
                onPressed: () => _openMapDirections(spot.latitude, spot.longitude, spot.name),
              ),

              // Join / Leave Button
              ElevatedButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  service.toggleJoinSpot(widget.event.id, spot.id, user.name);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isJoined ? const Color(0xFF10B981) : Colors.white.withValues(alpha: 0.1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: Text(
                  isJoined ? 'Katıldın ✓' : 'Ben de Gidiyorum',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11.5,
                    color: isJoined ? Colors.black : Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    if (category.contains('Pub')) return const Color(0xFFF59E0B);
    if (category.contains('Kulüp')) return const Color(0xFFEC4899);
    if (category.contains('Toplanma')) return const Color(0xFF10B981);
    return const Color(0xFF8B5CF6);
  }

  IconData _getCategoryIcon(String category) {
    if (category.contains('Pub')) return Icons.sports_bar_rounded;
    if (category.contains('Kulüp')) return Icons.nightlife_rounded;
    if (category.contains('Toplanma')) return Icons.groups_rounded;
    return Icons.local_bar_rounded;
  }
}
