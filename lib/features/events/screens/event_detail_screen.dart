import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/url_launcher_helper.dart';
import '../../../core/widgets/app_image_widget.dart';
import '../models/event_model.dart';
import '../services/mock_event_service.dart';
import '../services/mock_match_service.dart';
import '../services/notification_service.dart';
import '../services/spotify_service.dart';
import '../../profile/screens/user_profile_screen.dart';
import '../screens/venue_chat_screen.dart';

class EventDetailScreen extends StatefulWidget {
  final EventModel event;

  const EventDetailScreen({super.key, required this.event});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  bool _isDescriptionExpanded = false;

  // Spotify & Audio Preview State
  final AudioPlayer _audioPlayer = AudioPlayer();
  final SpotifyService _spotifyService = SpotifyService();
  SpotifyArtist? _spotifyArtist;
  List<SpotifyTrack> _spotifyTracks = [];
  bool _isLoadingSpotify = true;
  String? _playingTrackId;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;

  bool get _isMusicEvent {
    final cat = widget.event.category.toLowerCase().trim();
    final title = widget.event.title.toLowerCase().trim();

    // Tiyatro, stand-up, komedi, gösteri, sahne sanatları, spor, atölye, sinema kesinlikle müzik değildir!
    if (cat.contains('tiyatro') ||
        cat.contains('theatre') ||
        cat.contains('arts') ||
        cat.contains('stand-up') ||
        cat.contains('standup') ||
        cat.contains('komedi') ||
        cat.contains('comedy') ||
        cat.contains('sahne') ||
        cat.contains('spor') ||
        cat.contains('sport') ||
        cat.contains('sergi') ||
        cat.contains('atölye') ||
        cat.contains('workshop') ||
        cat.contains('sinema') ||
        cat.contains('cinema') ||
        title.contains('stand-up') ||
        title.contains('stand up') ||
        title.contains('tiyatro') ||
        title.contains('gösteri') ||
        title.contains('oyun') ||
        title.contains('tek kişilik')) {
      return false;
    }

    return cat.contains('konser') ||
        cat.contains('concert') ||
        cat.contains('müzik') ||
        cat.contains('music') ||
        cat.contains('akustik') ||
        cat.contains('festival');
  }

  @override
  void initState() {
    super.initState();
    _initAudioListeners();
    if (_isMusicEvent) {
      _loadSpotifyData();
    } else {
      _isLoadingSpotify = false;
    }
  }

  void _initAudioListeners() {
    _audioPlayer.setPlayerMode(PlayerMode.mediaPlayer);
    _audioPlayer.setReleaseMode(ReleaseMode.stop);

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state == PlayerState.playing;
      });
    });

    _audioPlayer.onPositionChanged.listen((pos) {
      if (!mounted) return;
      setState(() {
        _currentPosition = pos;
      });
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
        _playingTrackId = null;
        _currentPosition = Duration.zero;
      });
    });
  }

  Future<void> _loadSpotifyData() async {
    if (!_isMusicEvent) {
      if (mounted) {
        setState(() {
          _isLoadingSpotify = false;
        });
      }
      return;
    }
    try {
      final artist = await _spotifyService.searchArtist(widget.event.title, category: widget.event.category);
      if (artist != null && mounted) {
        final tracks = await _spotifyService.getArtistTopTracks(artist.id, artistName: artist.name);
        if (mounted) {
          setState(() {
            _spotifyArtist = artist;
            _spotifyTracks = tracks;
            _isLoadingSpotify = false;
          });
        }
      } else if (mounted) {
        setState(() {
          _isLoadingSpotify = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSpotify = false;
        });
      }
    }
  }

  Future<void> _togglePlayTrack(SpotifyTrack track) async {
    HapticFeedback.selectionClick();

    try {
      if (_playingTrackId == track.id && _isPlaying) {
        await _audioPlayer.pause();
        setState(() {
          _isPlaying = false;
        });
        return;
      }

      if (_playingTrackId != track.id) {
        await _audioPlayer.stop();
        _currentPosition = Duration.zero;
      }

      final audioUrl = (track.previewUrl != null && track.previewUrl!.isNotEmpty)
          ? track.previewUrl!
          : 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3';

      try {
        await _audioPlayer.play(UrlSource(audioUrl));
        setState(() {
          _playingTrackId = track.id;
          _isPlaying = true;
        });
      } catch (innerError) {
        debugPrint("Primary audio preview failed, attempting fallback: $innerError");
        const fallbackUrl = 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3';
        await _audioPlayer.play(UrlSource(fallbackUrl));
        setState(() {
          _playingTrackId = track.id;
          _isPlaying = true;
        });
      }
    } catch (e) {
      debugPrint("Audio preview error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.music_off_rounded, color: Colors.white70),
                SizedBox(width: 10),
                Expanded(child: Text('Ses önizlemesi yüklenemedi. Spotify üzerinden dinleyebilirsiniz.')),
              ],
            ),
            backgroundColor: AppColors.surfaceLight,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      }
    }
  }


  @override
  void dispose() {
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }


  String _getTurkishMonthName(int month) {
    const months = [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
    ];
    return months[month - 1];
  }

  String _getTurkishShortMonth(int month) {
    const months = [
      'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
      'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'
    ];
    return months[month - 1];
  }

  String _getTurkishDayName(int weekday) {
    const days = ['Pzt', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
    return days[weekday - 1];
  }

  String _getRichDescription() {
    final cleanDesc = widget.event.cleanDescription;

    // Check if description is short template, English API terms/rules, or Biletix template
    final isGenericOrBroken = cleanDesc.length < 90 ||
                              cleanDesc.contains('Biletix güvencesi') || 
                              cleanDesc.contains('güvencesiyle') || 
                              cleanDesc.contains('biletix') || 
                              cleanDesc.contains('Participants') || 
                              cleanDesc.contains('admitted') || 
                              cleanDesc.contains('wristbands') || 
                              cleanDesc.contains('ticketed') ||
                              cleanDesc.contains('prohibited') ||
                              cleanDesc.contains('re-enter') ||
                              cleanDesc.contains('firearms') ||
                              cleanDesc.contains('custodian') ||
                              cleanDesc.contains('Türk müziğinin');

    if (!isGenericOrBroken) {
      return cleanDesc;
    }

    final titleLower = widget.event.title.toLowerCase();
    final catLower = widget.event.category.toLowerCase();

    // Özel Sanatçı Tanımlamaları
    if (titleLower.contains('levent yüksel') || titleLower.contains('levent yuksel')) {
      return "Türk pop ve rock müziğinin usta ismi Levent Yüksel, dillerden düşmeyen unutulmaz klasikleri ve büyüleyici canlı sahne performansıyla müzikseverlere unutulmaz bir müzik ziyafeti sunuyor. 'Med Cezir', 'Zalim' ve daha nice hit şarkıyı hep birlikte söyleyeceğiniz bu özel konseri kaçırmayın.";
    }

    if (titleLower.contains('gülşen') || titleLower.contains('gulsen')) {
      return "Konseri Gülşen, güçlü sahne enerjisi, hit şarkıları ve büyüleyici sahne şovlarıyla dinleyicileri unutulmaz bir konser gecesine davet ediyor. Türk pop müziğinin en etkili isimlerinden biri olan sanatçı, yıllardır dillerden düşmeyen parçalarını ritim dolu bir atmosferle buluşturuyor.";
    }

    if (titleLower.contains('blok3') || titleLower.contains('blok 3')) {
      return "Türkçe rap ve hip-hop sahnesinin fırtına gibi esen ismi Blok3, yüksek enerjili canlı performansı, liste başı hit şarkıları ve coşkulu atmosferiyle müzikseverlere unutulmaz bir konser vadediyor.";
    }

    if (titleLower.contains('duman') || titleLower.contains('teoman') || titleLower.contains('manga') || titleLower.contains('mor ve ötesi')) {
      return "Türk rock müziğinin efsane ismi ${widget.event.title}, yıllardır milyonların kalbine kazınan unutulmaz hit parçaları ve yüksek tempolu canlı performansıyla sahneyi sallamaya hazırlanıyor.";
    }

    // 1. Stand-up / Komedi
    if (catLower.contains('stand-up') || catLower.contains('komedi') || catLower.contains('comedy') || titleLower.contains('stand up') || titleLower.contains('özdemir') || titleLower.contains('gösteri') || titleLower.contains('baturay')) {
      return "Kahkaha dolu bir geceye hazır olun! ${widget.event.title}, benzersiz espri anlayışı, eğlenceli günlük hayat tespitleri ve yüksek enerjili sahne performansıyla seyircilerine kahkaha garantili unutulmaz bir gösteri sunuyor. Eğlence ve komedinin tavan yapacağı bu özel sahne gösterisini kaçırmayın.";
    }

    // 2. Tiyatro / Sahne / Sanat
    if (catLower.contains('tiyatro') || catLower.contains('arts') || catLower.contains('theatre') || titleLower.contains('oyun') || titleLower.contains('sahne')) {
      return "Sanat dolu büyüleyici bir tiyatro deneyimi! ${widget.event.title}, sürükleyici hikayesi, güçlü sahne tasarımı ve etkileyici oyuncu performanslarıyla tiyatroseverlere unutulmaz anlar yaşatıyor. Duygu ve dramın ustalıkla harmanlandığı bu özel oyunu kaçırmayın.";
    }

    // 3. Yabancı Müzik / Grubu (e.g. The Black Keys, Rock, Pop, Dj, Festival)
    final isForeignArtist = titleLower.contains('the ') || titleLower.contains('keys') || titleLower.contains('coldplay') || titleLower.contains('dj') || titleLower.contains('festival') || titleLower.contains('band') || catLower.contains('foreign') || catLower.contains('rock') || catLower.contains('music');
    if (isForeignArtist) {
      return "Dünyaca ünlü canlı performans! ${widget.event.title}, sahnedeki muazzam enerjisi, dünya çapında dillerden düşmeyen hit parçaları ve büyüleyici atmosferiyle müzikseverlere unutulmaz bir konser deneyimi sunuyor. Canlı müziğin coşkusunu ve yüksek ritmini doyasıya yaşayacağınız bu konseri kaçırmayın.";
    }

    // 4. Spor / Maç
    if (catLower.contains('spor') || catLower.contains('sports') || titleLower.contains('maç') || titleLower.contains('turnuva')) {
      return "Heyecan ve rekabet dolu bir mücadele! ${widget.event.title}, yüksek temposu ve tutkulu atmosferiyle sporseverlere nefes kesen anlar yaşatıyor.";
    }

    // 5. Yerli Konser / Müzik
    return "Müziğin ritmine kapılacağınız unutulmaz bir gece! ${widget.event.title}, güçlü sahne enerjisi, dillerden düşmeyen sevilen şarkıları ve canlı performansıyla dinleyicilerine müzik dolu harika bir akşam vaat ediyor. Müziğin ve eğlencenin bir araya geldiği bu konseri kaçırmayın.";
  }

  Widget _buildGlassIconButton({required IconData icon, required VoidCallback onTap}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.35),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
          ),
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: Icon(icon, color: Colors.white, size: 20),
            onPressed: onTap,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final hasCoordinates = event.latitude != null && event.longitude != null;
    final richDesc = _getRichDescription();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Full-Bleed Edge-to-Edge Hero Sliver App Bar
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: AppColors.background,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: _buildGlassIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => Navigator.pop(context),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'event_image_${event.id}',
                    child: AppImageWidget(
                      imageUrl: (_isMusicEvent && _spotifyArtist != null && _spotifyArtist!.imageUrl.isNotEmpty)
                          ? _spotifyArtist!.imageUrl
                          : event.imageUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: 1080,
                    ),
                  ),
                  // Dark Gradient Overlay for text contrast
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.6),
                          Colors.transparent,
                          AppColors.background.withOpacity(0.85),
                          AppColors.background,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.4, 0.85, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Main Body Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category Badge Chip (e.g. STAND-UP / KONSER matching reference image 2)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                    ),
                    child: Text(
                      event.category.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Event Title Header
                  Text(
                    event.title,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.15,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Ultra-Premium Glassmorphic Glowing Date & Time Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.primary.withOpacity(0.25), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.12),
                          blurRadius: 20,
                          spreadRadius: 1,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Left: Gradient Glowing Calendar Date Stub
                        Container(
                          width: 58,
                          height: 62,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary.withOpacity(0.35),
                                AppColors.secondary.withOpacity(0.25),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.primary.withOpacity(0.5), width: 1.5),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _getTurkishShortMonth(event.dateTime.month).toUpperCase(),
                                style: TextStyle(
                                  color: AppColors.primaryVariant,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                '${event.dateTime.day}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  height: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Middle: Date & Time info text
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${event.dateTime.day} ${_getTurkishMonthName(event.dateTime.month)} ${event.dateTime.year}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  Icon(Icons.schedule_rounded, color: AppColors.secondary, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${_getTurkishDayName(event.dateTime.weekday)} • ${event.dateTime.hour.toString().padLeft(2, '0')}:${event.dateTime.minute.toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Right: Quick Reminder Action Chip
                        InkWell(
                          onTap: () async {
                            HapticFeedback.mediumImpact();
                            await NotificationService.scheduleEventReminders(event);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Row(
                                    children: [
                                      Icon(Icons.check_circle, color: Colors.white),
                                      SizedBox(width: 10),
                                      Expanded(child: Text('Hatırlatıcı takvime eklendi!')),
                                    ],
                                  ),
                                  backgroundColor: AppColors.primary,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                              );
                            }
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                            ),
                            child: Icon(Icons.add_alert_rounded, color: AppColors.primaryVariant, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Actions Section ("BEN DE GELİYORUM!" & Toggle Attendance / Leave)
                  Consumer<MockEventService>(
                    builder: (context, eventService, child) {
                      final isAttending = eventService.isUserAttending(event.id);
                      return Column(
                        children: [
                          // Primary Button: BEN DE GELİYORUM!
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: double.infinity,
                            height: 58,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              gradient: isAttending
                                  ? LinearGradient(
                                      colors: [AppColors.surfaceLight, AppColors.surface],
                                    )
                                  : AppColors.primaryGradient,
                              border: isAttending ? Border.all(color: Colors.white.withOpacity(0.15)) : null,
                              boxShadow: isAttending
                                  ? []
                                  : [
                                      BoxShadow(
                                        color: AppColors.primary.withOpacity(0.45),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                            ),
                            child: ElevatedButton(
                              onPressed: () {
                                HapticFeedback.mediumImpact();
                                if (isAttending) {
                                  eventService.leaveEvent(event.id);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Row(
                                        children: [
                                          Icon(Icons.remove_circle_outline, color: Colors.white),
                                          SizedBox(width: 10),
                                          Text('Etkinlik katılımın iptal edildi.'),
                                        ],
                                      ),
                                      backgroundColor: AppColors.surfaceLight,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                  );
                                } else {
                                  eventService.joinEvent(event.id);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Row(
                                        children: [
                                          Icon(Icons.stars_rounded, color: Colors.white),
                                          SizedBox(width: 10),
                                          Text('Etkinliğe katıldın! Artık listedesin.'),
                                        ],
                                      ),
                                      backgroundColor: AppColors.primary,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                disabledBackgroundColor: Colors.transparent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    isAttending ? Icons.check_circle_rounded : Icons.bolt_rounded,
                                    color: isAttending ? AppColors.success : Colors.white,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    isAttending ? 'KATILDIN (Vazgeç)' : 'BEN DE GELİYORUM!',
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          // Secondary Button: BİLET AL
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final targetUrl = event.effectiveTicketUrl;
                                await UrlLauncherHelper.launchURL(targetUrl);
                              },
                              icon: const Icon(Icons.confirmation_number_outlined, color: Colors.white, size: 20),
                              label: const Text(
                                'BİLETLER',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: AppColors.secondary.withOpacity(0.8), width: 1.5),
                                backgroundColor: AppColors.secondary.withOpacity(0.12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 32),

                  // --- ETKİNLİK KONUMU SECTION ---
                  const Text(
                    "Etkinlik Konumu",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Map Tile Preview Box
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: SizedBox(
                            height: 180,
                            width: double.infinity,
                            child: Stack(
                              children: [
                                if (hasCoordinates)
                                  FlutterMap(
                                    options: MapOptions(
                                      initialCenter: LatLng(event.latitude!, event.longitude!),
                                      initialZoom: 14.5,
                                      interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                                    ),
                                    children: [
                                      TileLayer(
                                        urlTemplate: 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                                        userAgentPackageName: 'com.eventmatch.app',
                                        tileProvider: NetworkTileProvider(),
                                      ),
                                      MarkerLayer(
                                        markers: [
                                          Marker(
                                            point: LatLng(event.latitude!, event.longitude!),
                                            width: 36,
                                            height: 36,
                                            child: Container(
                                              decoration: const BoxDecoration(
                                                color: Color(0xFFEF4444),
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 3)),
                                                ],
                                              ),
                                              child: const Icon(Icons.location_on, color: Colors.white, size: 22),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  )
                                else
                                  Container(
                                    color: AppColors.surfaceLight,
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.map_outlined, color: AppColors.primary, size: 40),
                                          const SizedBox(height: 8),
                                          Text(event.location, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                  ),
                                // Floating "Open in Maps" Badge
                                Positioned(
                                  top: 10,
                                  right: 10,
                                  child: InkWell(
                                    onTap: () async {
                                      if (hasCoordinates) {
                                        final mapsUrl = 'https://www.google.com/maps/dir/?api=1&destination=${event.latitude},${event.longitude}';
                                        await UrlLauncherHelper.launchURL(mapsUrl);
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.open_in_new_rounded, size: 12, color: Color(0xFF2563EB)),
                                          SizedBox(width: 4),
                                          Text('Open in Maps', style: TextStyle(color: Color(0xFF2563EB), fontSize: 11, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Location Title Line
                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded, color: Color(0xFF2563EB), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                event.location,
                                style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.bold),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        // Full-width "Yol Tarifi Al" Button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              if (hasCoordinates) {
                                final mapsUrl = 'https://www.google.com/maps/dir/?api=1&destination=${event.latitude},${event.longitude}';
                                await UrlLauncherHelper.launchURL(mapsUrl);
                              }
                            },
                            icon: const Icon(Icons.near_me_rounded, color: Colors.white, size: 18),
                            label: const Text(
                              'Yol Tarifi Al',
                              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3B82F6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 4,
                              shadowColor: const Color(0xFF3B82F6).withOpacity(0.4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // --- SPOTIFY ARTIST PREVIEW & TOP 3 TRACKS SECTION (Sadece Müzik/Konser) ---
                  if (_isMusicEvent)
                    _buildSpotifyPreviewSection(),

                  // --- ETKİNLİK HAKKINDA SECTION ---
                  const Text(
                    "Etkinlik Hakkında",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          richDesc,
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 14.5, height: 1.6),
                          maxLines: _isDescriptionExpanded ? 100 : 4,
                          overflow: _isDescriptionExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _isDescriptionExpanded = !_isDescriptionExpanded;
                            });
                          },
                          child: Text(
                            _isDescriptionExpanded ? 'Gizle' : 'Devamını Oku',
                            style: const TextStyle(
                              color: Color(0xFF2563EB),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Check-in and Venue Chat Section
                  Consumer<MockEventService>(
                    builder: (context, eventService, child) {
                      final isAttending = eventService.isUserAttending(event.id);
                      final isCheckedIn = eventService.isUserCheckedIn(event.id);

                      if (!isAttending) return const SizedBox.shrink();

                      return Column(
                        children: [
                          _buildGlassCard(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isCheckedIn ? Colors.green.withOpacity(0.2) : AppColors.primary.withOpacity(0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isCheckedIn ? Icons.location_on_rounded : Icons.location_on_outlined,
                                        color: isCheckedIn ? Colors.green : AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isCheckedIn ? 'Mekandasın!' : 'Mekanda mısın?',
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            isCheckedIn ? 'Diğerleriyle sohbete başla.' : 'Check-in yap, rozetini kap!',
                                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!isCheckedIn)
                                      ElevatedButton(
                                        onPressed: () {
                                          HapticFeedback.heavyImpact();
                                          eventService.checkIn(event.id);
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                        ),
                                        child: const Text('CHECK-IN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.green),
                                        ),
                                        child: const Text('MEKANDA', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.w900)),
                                      ),
                                  ],
                                ),
                                if (isCheckedIn) ...[
                                  const Divider(color: Colors.white10, height: 32),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => VenueChatScreen(event: event)),
                                        );
                                      },
                                      icon: const Icon(Icons.chat_bubble_outline_rounded),
                                      label: const Text('MEKAN SOHBETİNE KATIL', style: TextStyle(fontWeight: FontWeight.bold)),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.primaryVariant,
                                        side: BorderSide(color: AppColors.primary),
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      );
                    },
                  ),

                  // Attendees Section
                  Consumer2<MockEventService, MockMatchService>(
                    builder: (context, eventService, matchService, child) {
                      final currentEvent = eventService.getEventById(event.id) ?? event;
                      final attendees = currentEvent.attendees.where((u) => u.id != eventService.currentUser.id).toList();
                      final isAttending = eventService.isUserAttending(event.id);

                      if (!isAttending) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.surface.withOpacity(0.8),
                                AppColors.surfaceLight.withOpacity(0.4),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Avatar Overlap Stack + Lock Icon
                              SizedBox(
                                height: 48,
                                width: 140,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Positioned(
                                      left: 0,
                                      child: CircleAvatar(
                                        radius: 20,
                                        backgroundColor: AppColors.primary.withOpacity(0.3),
                                        child: const Icon(Icons.person, color: Colors.white54, size: 22),
                                      ),
                                    ),
                                    Positioned(
                                      left: 28,
                                      child: CircleAvatar(
                                        radius: 20,
                                        backgroundColor: AppColors.secondary.withOpacity(0.3),
                                        child: const Icon(Icons.person, color: Colors.white54, size: 22),
                                      ),
                                    ),
                                    Positioned(
                                      left: 56,
                                      child: CircleAvatar(
                                        radius: 20,
                                        backgroundColor: AppColors.accent.withOpacity(0.3),
                                        child: const Icon(Icons.person, color: Colors.white54, size: 22),
                                      ),
                                    ),
                                    Positioned(
                                      left: 84,
                                      child: CircleAvatar(
                                        radius: 20,
                                        backgroundColor: AppColors.primary,
                                        child: const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 20),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                "Katılımcıları Görmek İçin Katılın",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Bu etkinlikteki diğer katılımcıları görmek, eşleşmek ve mekan sohbetine katılmak için katılımınızı onaylayın.",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                              ),
                            ],
                          ),
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: AppColors.secondary,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    "Katılımcılar",
                                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  "${currentEvent.attendees.length} Kişi",
                                  style: TextStyle(color: AppColors.primaryVariant, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (attendees.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(20),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: AppColors.surface.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Center(
                                child: Text(
                                  "Henüz kimse katılmadı. İlk katılan sen ol!",
                                  style: TextStyle(color: AppColors.textSecondary),
                                ),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: attendees.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final user = attendees[index];
                                final hasSentReq = matchService.hasSentRequest(event.id, user.id);
                                final isAtVenue = (index % 2 == 0);

                                return Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.surface.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: Colors.white10),
                                  ),
                                  child: ListTile(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => UserProfileScreen(
                                            user: user,
                                            eventId: event.id,
                                          ),
                                        ),
                                      );
                                    },
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                    leading: Stack(
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(color: AppColors.primary.withOpacity(0.5), width: 1.5),
                                          ),
                                          child: CircleAvatar(
                                            backgroundColor: AppColors.surface,
                                            radius: 24,
                                            child: ClipOval(
                                              child: user.avatarUrl.startsWith('http')
                                                  ? Image.network(
                                                      user.avatarUrl,
                                                      width: 48,
                                                      height: 48,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (context, error, stackTrace) =>
                                                          Icon(Icons.person, color: AppColors.primary),
                                                    )
                                                  : Image.asset(
                                                      user.avatarUrl,
                                                      width: 48,
                                                      height: 48,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (context, error, stackTrace) =>
                                                          Icon(Icons.person, color: AppColors.primary),
                                                    ),
                                            ),
                                          ),
                                        ),
                                        if (isAtVenue)
                                          Positioned(
                                            right: 2,
                                            bottom: 2,
                                            child: Container(
                                              width: 12,
                                              height: 12,
                                              decoration: BoxDecoration(
                                                color: Colors.green,
                                                shape: BoxShape.circle,
                                                border: Border.all(color: AppColors.background, width: 2),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    title: Row(
                                      children: [
                                        Text(
                                          user.name,
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                        ),
                                        if (isAtVenue) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.green.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: Colors.green.withOpacity(0.4), width: 0.8),
                                            ),
                                            child: const Text('MEKANDA',
                                                style: TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.w900)),
                                          ),
                                        ],
                                      ],
                                    ),
                                    trailing: hasSentReq
                                        ? OutlinedButton(
                                            onPressed: null,
                                            style: OutlinedButton.styleFrom(
                                              side: const BorderSide(color: Colors.white24),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                            child: const Text("İstek Gönderildi", style: TextStyle(color: Colors.white38, fontSize: 12)),
                                          )
                                        : Icon(Icons.chevron_right_rounded, color: AppColors.primaryVariant, size: 22),
                                  ),
                                );
                              },
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard({required Widget child, EdgeInsets? padding}) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSpotifyPreviewSection() {
    if (!_isMusicEvent) {
      return const SizedBox.shrink();
    }
    if (_isLoadingSpotify) {
      return Container(
        margin: const EdgeInsets.only(bottom: 32),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF121212).withOpacity(0.7),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF1DB954).withOpacity(0.2)),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1DB954)),
            ),
            const SizedBox(width: 14),
            Text(
              "Spotify sanatçı bilgileri ve şarkılar yükleniyor...",
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_spotifyTracks.isEmpty && _spotifyArtist == null) {
      return const SizedBox.shrink();
    }

    const spotifyGreen = Color(0xFF1DB954);

    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0F2617), // Deep Spotify tinted dark
            const Color(0xFF121212).withOpacity(0.9),
            AppColors.surface.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: spotifyGreen.withOpacity(0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: spotifyGreen.withOpacity(0.12),
            blurRadius: 24,
            spreadRadius: 1,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Spotify Logo, Badge & "Aç" Action
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: const BoxDecoration(
                          color: spotifyGreen,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.music_note_rounded, color: Colors.black, size: 16),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "SPOTIFY",
                        style: TextStyle(
                          color: spotifyGreen,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          "En Popüler 3 Şarkı",
                          style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  if (_spotifyArtist?.spotifyUrl != null && _spotifyArtist!.spotifyUrl.isNotEmpty)
                    InkWell(
                      onTap: () => UrlLauncherHelper.launchURL(_spotifyArtist!.spotifyUrl),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.15)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "Spotify'da Aç",
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.open_in_new_rounded, color: Colors.white, size: 12),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Artist Profile Card
              if (_spotifyArtist != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Row(
                    children: [
                      // Artist Avatar
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: spotifyGreen.withOpacity(0.8), width: 2),
                          boxShadow: [
                            BoxShadow(color: spotifyGreen.withOpacity(0.3), blurRadius: 10),
                          ],
                        ),
                        child: ClipOval(
                          child: _spotifyArtist!.imageUrl.isNotEmpty
                              ? Image.network(
                                  _spotifyArtist!.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white),
                                )
                              : const Icon(Icons.person, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    _spotifyArtist!.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                const Icon(Icons.verified_rounded, color: Color(0xFF38BDF8), size: 16),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _spotifyArtist!.genres.isNotEmpty
                                  ? _spotifyArtist!.genres.take(2).join(' • ').toUpperCase()
                                  : 'SANATÇI',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
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

              const SizedBox(height: 14),

              // Tracks List
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: _spotifyTracks.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final track = _spotifyTracks[index];
                  final isCurrentTrack = _playingTrackId == track.id;
                  final isPlayingThis = isCurrentTrack && _isPlaying;

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isPlayingThis
                          ? spotifyGreen.withOpacity(0.12)
                          : Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isPlayingThis ? spotifyGreen.withOpacity(0.4) : Colors.white.withOpacity(0.06),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            // Track Number or Equalizer
                            SizedBox(
                              width: 20,
                              child: isPlayingThis
                                  ? const Icon(Icons.graphic_eq_rounded, color: spotifyGreen, size: 18)
                                  : Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.5),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 8),

                            // Album Thumbnail
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 44,
                                height: 44,
                                child: track.albumCoverUrl.isNotEmpty
                                    ? Image.network(
                                        track.albumCoverUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          color: Colors.white12,
                                          child: const Icon(Icons.music_note, color: Colors.white70),
                                        ),
                                      )
                                    : Container(
                                        color: Colors.white12,
                                        child: const Icon(Icons.music_note, color: Colors.white70),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Track Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    track.title,
                                    style: TextStyle(
                                      color: isPlayingThis ? spotifyGreen : Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    track.artistName,
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 11.5,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),

                            // Play / Pause Circle Button
                            InkWell(
                              onTap: () => _togglePlayTrack(track),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: isPlayingThis ? spotifyGreen : Colors.white.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                  boxShadow: isPlayingThis
                                      ? [
                                          BoxShadow(
                                            color: spotifyGreen.withOpacity(0.5),
                                            blurRadius: 10,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Icon(
                                  isPlayingThis ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  color: isPlayingThis ? Colors.black : Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),

                            const SizedBox(width: 8),

                            // Open in Spotify Button
                            if (track.spotifyUrl.isNotEmpty)
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                                icon: Icon(
                                  Icons.open_in_new_rounded,
                                  color: Colors.white.withOpacity(0.4),
                                  size: 16,
                                ),
                                onPressed: () => UrlLauncherHelper.launchURL(track.spotifyUrl),
                              ),
                          ],
                        ),

                        // Progress indicator for playing track (30s preview)
                        if (isPlayingThis) ...[
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: (_currentPosition.inMilliseconds / 30000.0).clamp(0.0, 1.0),
                              backgroundColor: Colors.white12,
                              valueColor: const AlwaysStoppedAnimation<Color>(spotifyGreen),
                              minHeight: 3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "0:${_currentPosition.inSeconds.toString().padLeft(2, '0')}",
                                style: const TextStyle(color: spotifyGreen, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                              const Text(
                                "0:30 (Önizleme)",
                                style: TextStyle(color: Colors.white38, fontSize: 10),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 12),
              Center(
                child: Text(
                  "🎵 30 saniyelik önizleme dinlemektesiniz • Tam sürüm için Spotify'a geçin",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.45),
                    fontSize: 10.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

