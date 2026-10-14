import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/weather_service.dart';
import '../../../core/utils/event_share_helper.dart';
import '../models/event_model.dart';

/// Etkinlik Rehberi, Ne Giyilir (Kombin) ve Konser Çantası Kontrol Listesi
class EventVibeGuideSheet extends StatefulWidget {
  final EventModel event;

  const EventVibeGuideSheet({super.key, required this.event});

  static Future<void> show(BuildContext context, {required EventModel event}) {
    HapticFeedback.mediumImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EventVibeGuideSheet(event: event),
    );
  }

  @override
  State<EventVibeGuideSheet> createState() => _EventVibeGuideSheetState();
}

class _EventVibeGuideSheetState extends State<EventVibeGuideSheet> {
  EventWeatherData? _weather;

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  Future<void> _loadWeather() async {
    try {
      EventWeatherData? data;
      if (widget.event.latitude != null && widget.event.longitude != null) {
        data = await WeatherService().getWeatherForCoordinates(
          latitude: widget.event.latitude!,
          longitude: widget.event.longitude!,
        );
      } else {
        data = await WeatherService().getWeatherForLocationName(widget.event.location);
      }
      if (mounted && data != null) {
        setState(() => _weather = data);
      }
    } catch (_) {}
  }

  // İnteraktif kontrol listesi (Checklist)
  final Map<String, bool> _checklist = {
    '🎟️ Dijital Bilet veya EventMatch QR Kod': true,
    '🪪 Resmi Kimlik Kartı / Ehliyet (Kapı kontrolü)': true,
    '🔋 Taşınabilir Şarj Cihazı (Powerbank)': false,
    '🎧 Akustik Kulak Tıkacı (Hoparlör yakını ses koruması)': false,
    '👜 Hafif Çapraz Askılı Bel/Omuz Çantası': false,
    '🕶️ Güneş Gözlüğü & Dudak Balmı': false,
    '💳 Temassız Ödeme Kartı / Nakit': true,
  };

  bool get _isOutdoor {
    final loc = widget.event.location.toLowerCase();
    final title = widget.event.title.toLowerCase();
    return loc.contains('park') ||
        loc.contains('açıkhava') ||
        loc.contains('acikhava') ||
        loc.contains('bahçe') ||
        loc.contains('bahce') ||
        loc.contains('festival') ||
        loc.contains('harbiye') ||
        loc.contains('küçükçiftlik') ||
        loc.contains('kucukciftlik') ||
        loc.contains('plaj') ||
        loc.contains('beach') ||
        title.contains('festival') ||
        title.contains('open air');
  }

  Map<String, dynamic> _getOutfitRecommendation() {
    final cat = widget.event.category.toLowerCase().trim();
    final title = widget.event.title.toLowerCase().trim();

    if (cat.contains('rock') ||
        cat.contains('metal') ||
        title.contains('rock') ||
        title.contains('metal')) {
      return {
        'vibeTitle': 'Grunge & Rock Enerjisi',
        'vibeEmoji': '🎸',
        'outfitText':
            'Deri ceket veya vintage kot ceket, baskılı oversize grup tişörtü ve rahat siyah denim pantolon.',
        'shoesText':
            'Rahat deri botlar (Dr. Martens stili) ya da dayanıklı koyu renk sneakerlar. Kalabalıkta zıplarken ayağını korur.',
        'accessoryText':
            'Gümüş zincir kolyeler, mat deri bileklikler ve küçük çapraz askılı çanta.',
        'palette': [
          const Color(0xFF1E1E2E),
          const Color(0xFF475569),
          const Color(0xFF991B1B),
          const Color(0xFFCBD5E1),
        ],
      };
    }

    if (cat.contains('elektronik') ||
        cat.contains('techno') ||
        cat.contains('rave') ||
        cat.contains('house') ||
        title.contains('techno')) {
      return {
        'vibeTitle': 'Cyber & Techno All-Black',
        'vibeEmoji': '⚡',
        'outfitText':
            'Monokrom siyah minimalist kesimler, file/mesh detaylar, kargo pantolon veya bisikletçi taytı ile hafif crop üstler.',
        'shoesText':
            'Yüksek tabanlı ve ultra yastıklamalı sneakerlar. Saatlerce dans ederken konfor 1. önceliktir.',
        'accessoryText':
            'Fütüristik festival gözlükleri, reflektör detaylar ve kulak sağlığı için akustik tıkacı.',
        'palette': [
          const Color(0xFF0F172A),
          const Color(0xFF06B6D4),
          const Color(0xFFA855F7),
          const Color(0xFF10B981),
        ],
      };
    }

    if (cat.contains('festival') || title.contains('festival')) {
      return {
        'vibeTitle': 'Boho Festival Işıltısı',
        'vibeEmoji': '🎪',
        'outfitText':
            'Renkli keten gömlek, şort/etek, hafif boho katmanlar veya renkli desenli festival kombini.',
        'shoesText':
            'Toz ve çim alana uygun rahat sneaker veya düz festival botları. İnce topuktan kesinlikle kaçının.',
        'accessoryText':
            'Renkli güneş gözlüğü, bucket şapka, festival simi/yüz taşları ve taşınabilir mini matara.',
        'palette': [
          const Color(0xFFF59E0B),
          const Color(0xFFEC4899),
          const Color(0xFF10B981),
          const Color(0xFF3B82F6),
        ],
      };
    }

    if (cat.contains('tiyatro') ||
        cat.contains('theatre') ||
        cat.contains('stand-up') ||
        cat.contains('sahne')) {
      return {
        'vibeTitle': 'Smart Casual & Konfor',
        'vibeEmoji': '🎭',
        'outfitText':
            'Düz kesim kumaş pantolon, şık triko kazak veya blazer ceket kombini. Klimalı salon için katmanlı giyinin.',
        'shoesText':
            'Temiz beyaz deri sneaker, loafer veya şık düz taban ayakkabılar.',
        'accessoryText':
            'Minimalist saat, şık omuz çantası ve hafif bir ipek fular/atkı.',
        'palette': [
          const Color(0xFF334155),
          const Color(0xFF64748B),
          const Color(0xFFD97706),
          const Color(0xFFF8FAFC),
        ],
      };
    }

    if (cat.contains('klasik') || cat.contains('caz') || cat.contains('jazz')) {
      return {
        'vibeTitle': 'Zarif & Akşam Şıklığı',
        'vibeEmoji': '🎷',
        'outfitText':
            'Koyu renk takım ceket, gömlek veya şık midi elbise. Akustik ambiyansa uyumlu asil dokular.',
        'shoesText': 'Klasik deri kundura, oxford veya şık topuklu ayakkabı.',
        'accessoryText':
            'Zarif takılar, deri el çantası ve hoş bir parfüm dokunuşu.',
        'palette': [
          const Color(0xFF0F172A),
          const Color(0xFF1E293B),
          const Color(0xFFCA8A04),
          const Color(0xFFF1F5F9),
        ],
      };
    }

    // Pop / Genel Varsayılan
    return {
      'vibeTitle': 'Şehirli Sokak Modası (Streetwear)',
      'vibeEmoji': '✨',
      'outfitText':
          'Oversize grafik tişört, baggy kot veya kargo pantolon, hafif bomber ya da zip-up kapüşonlu sweatshirt.',
      'shoesText':
          'En rahat günlük sneaker\'ların (Air Force, Dunk, Samba veya New Balance stili).',
      'accessoryText':
          'Şık cap şapka, ince gümüş zincir ve telefon askısı / çapraz çanta.',
      'palette': [
        const Color(0xFF2563EB),
        const Color(0xFF8B5CF6),
        const Color(0xFF10B981),
        const Color(0xFFF3F4F6),
      ],
    };
  }

  void _shareVibeGuide(Map<String, dynamic> rec) {
    HapticFeedback.selectionClick();
    EventShareHelper.shareVibeGuide(
      context: context,
      event: widget.event,
      rec: rec,
      isOutdoor: _isOutdoor,
      weather: _weather,
    );
  }

  @override
  Widget build(BuildContext context) {
    final rec = _getOutfitRecommendation();
    final palette = rec['palette'] as List<Color>;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.90;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0F0F1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Modal Handle
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Sheet Title Bar (Always pinned at top)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFA855F7).withOpacity(0.18),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: const Color(0xFFA855F7).withOpacity(0.3)),
                          ),
                          child: const Icon(
                            Icons.checkroom_rounded,
                            color: Color(0xFFC084FC),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Kombin & Etkinlik Rehberi',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Ne giyilir, ne alınır, mekan atmosferi',
                                style: GoogleFonts.outfit(
                                  color: Colors.white60,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white60),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),
            const Divider(color: Colors.white10, height: 1),

            // Scrollable Body
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.only(
                  top: 16,
                  bottom: bottomInset + 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── VIBE & OUTFIT CARD ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF1E1E2E),
                              Color(0xFF13131F),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  rec['vibeEmoji'],
                                  style: const TextStyle(fontSize: 22),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    rec['vibeTitle'],
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Color Palette Chips
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: palette.map((c) {
                                    return Container(
                                      margin: const EdgeInsets.only(left: 4),
                                      width: 14,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color: c,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white38, width: 1.2),
                                        boxShadow: [
                                          BoxShadow(
                                            color: c.withOpacity(0.4),
                                            blurRadius: 3,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildRecommendationItem(
                              icon: Icons.checkroom_rounded,
                              iconColor: const Color(0xFFEC4899),
                              title: 'Kıyafet Önerisi',
                              desc: rec['outfitText'],
                            ),
                            const SizedBox(height: 14),
                            _buildRecommendationItem(
                              icon: Icons.roller_skating_rounded,
                              iconColor: const Color(0xFF38BDF8),
                              title: 'Ayakkabı Seçimi',
                              desc: rec['shoesText'],
                            ),
                            const SizedBox(height: 14),
                            _buildRecommendationItem(
                              icon: Icons.watch_rounded,
                              iconColor: const Color(0xFFFBBF24),
                              title: 'Aksesuar & Detaylar',
                              desc: rec['accessoryText'],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── VENUE & WEATHER CARD ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _isOutdoor
                                    ? const Color(0xFF10B981).withOpacity(0.18)
                                    : const Color(0xFF3B82F6).withOpacity(0.18),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _isOutdoor
                                    ? Icons.wb_sunny_rounded
                                    : Icons.nightlife_rounded,
                                color: _isOutdoor
                                    ? const Color(0xFF34D399)
                                    : const Color(0xFF60A5FA),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _isOutdoor
                                              ? 'Açık Hava Alanı İpuçları 🌳'
                                              : 'Kapalı Salon & Kulüp İpuçları 🏛️',
                                          style: GoogleFonts.outfit(
                                            color: Colors.white,
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (_weather != null) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _weather!.iconColor
                                                .withOpacity(0.15),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                                color: _weather!.iconColor
                                                    .withOpacity(0.3)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(_weather!.icon,
                                                  color: _weather!.iconColor,
                                                  size: 12),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${_weather!.temperature.round()}°C · ${_weather!.conditionText}',
                                                style: TextStyle(
                                                  color: _weather!.iconColor,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _isOutdoor
                                        ? 'Açık hava mekanı: Çim ve toprak zemin için düz tabanlı ayakkabı önerilir. Akşam rüzgarına dikkat.'
                                        : 'Kapalı salon mekanı: Havalandırma ve salon atmosferine uygun ferah ve rahat bir kombin seç.',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.72),
                                      fontSize: 12,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── CONCERT BAG CHECKLIST ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Konser Çantası Hazırlığı 🎒',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF38BDF8).withOpacity(0.14),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: const Color(0xFF38BDF8).withOpacity(0.3)),
                            ),
                            child: Text(
                              '${_checklist.values.where((v) => v).length} / ${_checklist.length} Hazır',
                              style: const TextStyle(
                                color: Color(0xFF38BDF8),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                        ),
                        child: Column(
                          children: _checklist.keys.toList().asMap().entries.map((entry) {
                            final index = entry.key;
                            final item = entry.value;
                            final isChecked = _checklist[item] ?? false;
                            final isLast = index == _checklist.length - 1;
                            return Column(
                              children: [
                                InkWell(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() {
                                      _checklist[item] = !isChecked;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 11),
                                    child: Row(
                                      children: [
                                        AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          width: 22,
                                          height: 22,
                                          decoration: BoxDecoration(
                                            color: isChecked
                                                ? const Color(0xFF10B981)
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: isChecked
                                                  ? const Color(0xFF10B981)
                                                  : Colors.white38,
                                              width: 1.5,
                                            ),
                                          ),
                                          child: isChecked
                                              ? const Icon(
                                                  Icons.check,
                                                  color: Colors.white,
                                                  size: 16,
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            item,
                                            style: TextStyle(
                                              color: isChecked
                                                  ? Colors.white.withOpacity(0.92)
                                                  : Colors.white60,
                                              fontSize: 13,
                                              decoration: isChecked
                                                  ? TextDecoration.none
                                                  : null,
                                              fontWeight: isChecked
                                                  ? FontWeight.w600
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (!isLast)
                                  Divider(
                                    color: Colors.white.withOpacity(0.05),
                                    height: 1,
                                    indent: 14,
                                    endIndent: 14,
                                  ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Share Guide Button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () => _shareVibeGuide(rec),
                          icon: const Icon(Icons.share_outlined, size: 18),
                          label: Text(
                            'Kombin ve Rehberi Arkadaşınla Paylaş',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 14.5,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFA855F7),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.16),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: iconColor, size: 17),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                desc,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.78),
                  fontSize: 12.5,
                  height: 1.42,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
