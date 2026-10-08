import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_colors.dart';
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
    final text = '✨ ${widget.event.title} için Kombin & Rehber:\n'
        'Tarz: ${rec['vibeTitle']} ${rec['vibeEmoji']}\n'
        'Kıyafet: ${rec['outfitText']}\n'
        'Ayakkabı: ${rec['shoesText']}\n'
        'Mekan: ${_isOutdoor ? "Açık Hava (Akşam serinliği için ceket al!)" : "Kapalı Salon"}\n'
        'EventMatch ile etkinlikte buluşalım!';
    Share.share(text);
  }

  @override
  Widget build(BuildContext context) {
    final rec = _getOutfitRecommendation();
    final palette = rec['palette'] as List<Color>;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: SingleChildScrollView(
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
            const SizedBox(height: 16),

            // Sheet Title Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kombin & Etkinlik Rehberi',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Ne giyilir, ne alınır, mekan atmosferi',
                            style: GoogleFonts.outfit(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white60),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // ── VIBE & OUTFIT CARD ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF1E1E2E),
                      const Color(0xFF13131F),
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              rec['vibeEmoji'],
                              style: const TextStyle(fontSize: 22),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              rec['vibeTitle'],
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        // Color Palette Chips
                        Row(
                          children: palette.map((c) {
                            return Container(
                              margin: const EdgeInsets.only(left: 4),
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white30, width: 1),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildRecommendationItem(
                      icon: Icons.checkroom_rounded,
                      iconColor: const Color(0xFFEC4899),
                      title: 'Kıyafet Önerisi',
                      desc: rec['outfitText'],
                    ),
                    const SizedBox(height: 12),
                    _buildRecommendationItem(
                      icon: Icons.roller_skating_rounded,
                      iconColor: const Color(0xFF38BDF8),
                      title: 'Ayakkabı Seçimi',
                      desc: rec['shoesText'],
                    ),
                    const SizedBox(height: 12),
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
                          Text(
                            _isOutdoor
                                ? 'Açık Hava Alanı İpuçları 🌳'
                                : 'Kapalı Salon & Kulüp İpuçları 🏛️',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isOutdoor
                                ? 'Konser akşamı serin esinti olabilir; beline veya omzuna bağlayabileceğin hafif bir ceket almayı unutma. Çim ve toprak zemin için düz tabanlı ayakkabı önerilir.'
                                : 'İçerisi yoğun kalabalık nedeniyle sıcak olabilir. Katmanlı (soğan stili) giyinerek salonda rahat kalabileceğin bir kombin seç.',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              height: 1.35,
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
              padding: const EdgeInsets.symmetric(horizontal: 24),
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
                  Text(
                    '${_checklist.values.where((v) => v).length} / ${_checklist.length} Hazır',
                    style: const TextStyle(
                      color: Color(0xFF38BDF8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Column(
                  children: _checklist.keys.map((item) {
                    final isChecked = _checklist[item] ?? false;
                    return InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _checklist[item] = !isChecked;
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
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
                                      ? Colors.white.withOpacity(0.9)
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
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => _shareVibeGuide(rec),
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: Text(
                    'Kombin ve Rehberi Arkadaşınla Paylaş',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFA855F7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
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
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.16),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
