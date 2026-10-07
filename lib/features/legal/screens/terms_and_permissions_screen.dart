import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';

/// EventMatch – Kullanım Koşulları, Gizlilik ve İzinler Merkezi
/// Kayıt öncesinde ve ayarlar kısmından erişilebilir.
class TermsAndPermissionsScreen extends StatefulWidget {
  /// [isOnboarding] = true → kayıt akışındaki tam sayfa modu (geri yok, kabul butonu var)
  final bool isOnboarding;

  const TermsAndPermissionsScreen({super.key, this.isOnboarding = false});

  @override
  State<TermsAndPermissionsScreen> createState() =>
      _TermsAndPermissionsScreenState();
}

class _TermsAndPermissionsScreenState
    extends State<TermsAndPermissionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _activeTab = 0;

  // Kullanıcının her sekmeyi kaydırıp kaydırmadığını takip eder
  final List<bool> _tabRead = [false, false, false, false];
  bool get _allTabsRead => _tabRead.every((r) => r);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _activeTab = _tabController.index;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onScrolledToBottom(int tabIndex) {
    if (!_tabRead[tabIndex]) {
      setState(() => _tabRead[tabIndex] = true);
    }
  }

  // ─── Sekmeler ────────────────────────────────────────────────────────────
  static const List<_TabMeta> _tabs = [
    _TabMeta(icon: Icons.gavel_rounded, label: 'Kullanım\nKoşulları', color: Color(0xFF8B5CF6)),
    _TabMeta(icon: Icons.shield_rounded, label: 'Gizlilik\nPolitikası', color: Color(0xFF06B6D4)),
    _TabMeta(icon: Icons.tune_rounded, label: 'İzin\nMerkezi', color: Color(0xFF10B981)),
    _TabMeta(icon: Icons.child_care_rounded, label: 'Topluluk\nKuralları', color: Color(0xFFEC4899)),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Arka plan dekorasyon ─────────────────────────────────────────
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -60,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.secondary.withOpacity(0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── Ana içerik ────────────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _ScrollableSection(
                        content: _eulaContent(),
                        onScrolledToBottom: () => _onScrolledToBottom(0),
                      ),
                      _ScrollableSection(
                        content: _privacyContent(),
                        onScrolledToBottom: () => _onScrolledToBottom(1),
                      ),
                      _ScrollableSection(
                        content: _permissionsContent(),
                        onScrolledToBottom: () => _onScrolledToBottom(2),
                      ),
                      _ScrollableSection(
                        content: _communityContent(),
                        onScrolledToBottom: () => _onScrolledToBottom(3),
                      ),
                    ],
                  ),
                ),
                if (widget.isOnboarding) _buildAcceptBar(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          if (!widget.isOnboarding)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                    padding: const EdgeInsets.all(10),
                    constraints: const BoxConstraints(),
                  ),
                ),
              ),
            )
          else
            const SizedBox(width: 44),
          Expanded(
            child: Column(
              children: [
                ShaderMask(
                  shaderCallback: (b) =>
                      AppColors.primaryGradient.createShader(b),
                  child: Text(
                    'İzin Merkezi',
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'EventMatch Kullanıcı Sözleşmesi',
                  style: GoogleFonts.outfit(
                      fontSize: 12, color: AppColors.textMuted),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          // Tarih etiketi
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Text(
              'v1.0',
              style: GoogleFonts.outfit(
                  color: AppColors.primaryVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Tab Bar ──────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final tab = _tabs[i];
          final isActive = _activeTab == i;
          final isRead = _tabRead[i];
          return GestureDetector(
            onTap: () => _tabController.animateTo(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: isActive
                    ? LinearGradient(
                        colors: [
                          tab.color.withOpacity(0.3),
                          tab.color.withOpacity(0.1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isActive ? null : AppColors.surface.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isActive
                      ? tab.color.withOpacity(0.7)
                      : Colors.white.withOpacity(0.07),
                  width: isActive ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(tab.icon,
                      color: isActive ? tab.color : AppColors.textMuted,
                      size: 18),
                  const SizedBox(width: 7),
                  Text(
                    tab.label.replaceAll('\n', ' '),
                    style: GoogleFonts.outfit(
                      color: isActive ? Colors.white : AppColors.textSecondary,
                      fontWeight:
                          isActive ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                  if (isRead) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.check_circle_rounded,
                        color: AppColors.success, size: 14),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Onay Çubuğu (sadece kayıt akışında) ─────────────────────────────────
  Widget _buildAcceptBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.95),
        border:
            Border(top: BorderSide(color: Colors.white.withOpacity(0.07))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Okunmamış uyarı
          if (!_allTabsRead)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: AppColors.accent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Kabul etmek için tüm sekmeleri okuyun.',
                      style: GoogleFonts.outfit(
                          color: AppColors.accent, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.error.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text('Reddet',
                      style: GoogleFonts.outfit(
                          color: AppColors.error, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: _allTabsRead
                        ? AppColors.primaryGradient
                        : LinearGradient(
                            colors: [
                              AppColors.textMuted.withOpacity(0.3),
                              AppColors.textMuted.withOpacity(0.2),
                            ],
                          ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: _allTabsRead
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 5),
                            ),
                          ]
                        : [],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _allTabsRead
                        ? () => Navigator.pop(context, true)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: Icon(
                      _allTabsRead
                          ? Icons.check_circle_rounded
                          : Icons.lock_outline_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    label: Text(
                      _allTabsRead ? 'Kabul Ediyorum' : 'Tümünü Oku...',
                      style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // İÇERİK BÖLÜMLERİ
  // ═══════════════════════════════════════════════════════════════════════════

  // ─── 1. EULA / Kullanım Koşulları ─────────────────────────────────────────
  List<_LegalSection> _eulaContent() => [
        _LegalSection(
          icon: Icons.gavel_rounded,
          iconColor: const Color(0xFF8B5CF6),
          title: 'EventMatch Son Kullanıcı Lisans Sözleşmesi (EULA)',
          subtitle: 'Son güncelleme: Eylül 2026 · Türkçe',
          items: [
            _LegalItem(
              number: '1',
              heading: 'Taraflar ve Kapsam',
              body:
                  'Bu Sözleşme; EventMatch uygulamasını ("Uygulama") işleten EventMatch Inc. ("Şirket") ile Uygulamayı kullanan gerçek kişi ("Kullanıcı") arasında akdedilmektedir. Uygulamayı indirerek, yükleyerek veya kullanarak bu koşulları kabul etmiş sayılırsınız.',
            ),
            _LegalItem(
              number: '2',
              heading: 'Hizmet Tanımı',
              body:
                  'EventMatch; kullanıcıların etkinlikler keşfetmesini, etkinlik arkadaşı bulmasını ve ortak ilgi alanlarına sahip katılımcılarla buluşmasını sağlayan sosyal bir etkinlik platformudur. Şirket, hizmetlerin kesintisiz veya hatasız çalışacağını garanti etmez.',
            ),
            _LegalItem(
              number: '3',
              heading: 'Yaş Sınırı (18+)',
              body:
                  'Uygulama yalnızca 18 (on sekiz) yaş ve üzeri bireyler için tasarlanmıştır. Yaşını yanlış beyan eden kullanıcının hesabı derhal kapatılır ve yasal süreç başlatılabilir. Ebeveyn/vasi izni bu kısıtlamayı ortadan kaldırmaz.',
              highlight: true,
              highlightColor: Color(0xFFEC4899),
            ),
            _LegalItem(
              number: '4',
              heading: 'Hesap Güvenliği',
              body:
                  'Hesap bilgilerinizi (şifre, e-posta) gizli tutmakla yükümlüsünüz. Hesabınızın yetkisiz kullanımından kaynaklanan zararlardan Şirket sorumlu tutulamaz. Şüpheli erişim durumunda derhal destek ekibimize bildirmeniz gerekmektedir.',
            ),
            _LegalItem(
              number: '5',
              heading: 'Kullanıcı Içeriği (UGC)',
              body:
                  'Uygulamaya yüklediğiniz fotoğraf, metin, biyografi ve etkinlik içerikleri için tam sorumluluk size aittir. Şirket, yüklenen içerikleri moderasyon amacıyla inceleme ve gerektiğinde kaldırma hakkını saklı tutar.',
            ),
            _LegalItem(
              number: '6',
              heading: 'Sıfır Tolerans Politikası',
              body:
                  'Aşağıdaki davranışlar kesinlikle yasaktır ve hesap kalıcı kapatılmasına yol açar:\n• Taciz, zorbalık, cinsel istismar içerikli mesajlar\n• Nefret söylemi (ırk, din, cinsiyet, engellilik vb. temelli)\n• Sahte kimlik veya profil oluşturma\n• Spam, dolandırıcılık veya kimlik avı girişimleri\n• Yasadışı içerik paylaşımı',
              highlight: true,
              highlightColor: Color(0xFFEF4444),
            ),
            _LegalItem(
              number: '7',
              heading: 'Fikri Mülkiyet',
              body:
                  'Uygulamanın tüm kodu, tasarımı, logosu ve içeriği EventMatch Inc. mülkiyetindedir ve Türk Ticaret Kanunu, Fikir ve Sanat Eserleri Kanunu kapsamında korunmaktadır. İzinsiz kopyalama, dağıtma veya ters mühendislik yasaktır.',
            ),
            _LegalItem(
              number: '8',
              heading: 'Hizmet Değişiklikleri ve Fesih',
              body:
                  'Şirket, herhangi bir bildirim yapmaksızın hizmetleri değiştirme, askıya alma veya sonlandırma hakkını saklı tutar. Bu sözleşmeyi ihlal eden hesaplar önceden bildirim yapılmaksızın kapatılabilir.',
            ),
            _LegalItem(
              number: '9',
              heading: 'Sorumluluk Sınırlaması',
              body:
                  'Yasal olarak izin verilen azami ölçüde, Şirket; dolaylı, tesadüfi, özel veya sonuç olarak ortaya çıkan zararlardan sorumlu değildir. Doğrudan zararlar bakımından sorumluluk, son 6 aylık dönemde ödediğiniz ücret tutarıyla sınırlıdır.',
            ),
            _LegalItem(
              number: '10',
              heading: 'Uygulanacak Hukuk',
              body:
                  'Bu Sözleşme, Türkiye Cumhuriyeti hukukuna tabidir. Uyuşmazlıklarda İstanbul Mahkemeleri ve İcra Daireleri yetkilidir.',
            ),
          ],
        ),
      ];

  // ─── 2. Gizlilik Politikası ───────────────────────────────────────────────
  List<_LegalSection> _privacyContent() => [
        _LegalSection(
          icon: Icons.shield_rounded,
          iconColor: const Color(0xFF06B6D4),
          title: 'Kişisel Verilerin Korunması & Gizlilik Politikası',
          subtitle: 'KVKK & GDPR uyumlu · Son güncelleme: Eylül 2026',
          items: [
            _LegalItem(
              number: '1',
              heading: 'Veri Sorumlusu',
              body:
                  'Kişisel verilerinizin işlenmesinden sorumlu veri sorumlusu EventMatch Inc. dir. İletişim: privacy@eventmatch.app',
            ),
            _LegalItem(
              number: '2',
              heading: 'Toplanan Veriler',
              body:
                  'Kimlik Verileri: Ad, soyad, kullanıcı adı, doğum tarihi\n\nİletişim Verileri: E-posta adresi\n\nKonum Verileri: Yaklaşık GPS konumu (yalnızca etkinlik önerileri için, yalnızca izin verdiğinizde)\n\nKullanım Verileri: Uygulama içi eylemler, tercih edilen kategoriler, mesajlaşma meta verileri\n\nCihaz Verileri: Cihaz kimliği (push bildirim servisi için), işletim sistemi',
            ),
            _LegalItem(
              number: '3',
              heading: 'Veri İşleme Amaçları',
              body:
                  '• Hesap oluşturma ve kimlik doğrulama\n• Etkinlik ve kullanıcı eşleştirme algoritması\n• Konum bazlı etkinlik önerileri\n• Push bildirimleri (OneSignal üzerinden)\n• Platform güvenliği ve dolandırıcılık tespiti\n• Yasal yükümlülüklerin yerine getirilmesi',
            ),
            _LegalItem(
              number: '4',
              heading: 'Konum İzninin Kullanımı',
              body:
                  'Konumunuz yalnızca açık izniz mevcut olduğunda alınır ve yalnızca yakınınızdaki etkinlik ve kullanıcıları listelemek için kullanılır. Tam konumunuz diğer kullanıcılara hiçbir zaman gösterilmez; yalnızca tahmini mesafe paylaşılır. Konum iznini istediğiniz zaman cihaz ayarlarından kaldırabilirsiniz.',
              highlight: true,
              highlightColor: Color(0xFF06B6D4),
            ),
            _LegalItem(
              number: '5',
              heading: 'Verilerle Üçüncü Taraf Paylaşımı',
              body:
                  'Kişisel verileriniz ticari amaçlarla üçüncü taraflarla paylaşılmaz. Yalnızca aşağıdaki durumlar istisnadır:\n• Yasal zorunluluk (mahkeme kararı, savcılık talebi)\n• Hizmet sağlayıcılar (Supabase – veri depolama, OneSignal – bildirim)\n• Suç veya tehlike bildirimi zorunluluğu',
            ),
            _LegalItem(
              number: '6',
              heading: 'Veri Güvenliği',
              body:
                  'Tüm veriler SSL/TLS şifrelemesi ile iletilir. Parolalar bcrypt ile hash\'lenerek saklanır. Veritabanı (Supabase) SOC 2 Type II sertifikalı altyapıda barındırılmaktadır. Supabase Row Level Security (RLS) politikaları uygulanmıştır.',
            ),
            _LegalItem(
              number: '7',
              heading: 'Haklarınız (KVKK Md. 11)',
              body:
                  '• Verilerinizin işlenip işlenmediğini öğrenme\n• İşlenen verilerinizi talep etme\n• Yanlış veya eksik verilerin düzeltilmesini isteme\n• Verilerin silinmesini ya da yok edilmesini talep etme\n• Kişisel verilerinizin üçüncü kişilere bildirilmesini talep etme\n• İşlemenin münhasıran otomatik sistemler vasıtasıyla yapılması halinde ortaya çıkabilecek aleyhe sonuçlara itiraz etme\n\nTalep için: kvkk@eventmatch.app',
            ),
            _LegalItem(
              number: '8',
              heading: 'Veri Saklama Süreleri',
              body:
                  'Aktif Hesap Verileri: Hesap açık olduğu sürece\nHesap Silme Sonrası: 30 gün içinde veritabanından kalıcı silme\nYasal Zorunluluk İçeren Veriler: İlgili mevzuatta belirtilen süre\nAnalitik / Anonim Veriler: Süresiz (kişisel veri içermez)',
            ),
            _LegalItem(
              number: '9',
              heading: 'Çerezler (Cookies)',
              body:
                  'Mobil uygulama çerez kullanmaz. Web versiyonumuz (varsa) yalnızca oturum yönetimi için zorunlu çerezler kullanır. Üçüncü taraf takip veya reklam çerezi kullanılmaz.',
            ),
          ],
        ),
      ];

  // ─── 3. İzin Merkezi ──────────────────────────────────────────────────────
  List<_LegalSection> _permissionsContent() => [
        _LegalSection(
          icon: Icons.tune_rounded,
          iconColor: const Color(0xFF10B981),
          title: 'Uygulama İzinleri & Onaylar',
          subtitle:
              'EventMatch\'in talep ettiği sistem izinleri ve kullanım amaçları',
          items: [
            _LegalItem(
              number: '',
              heading: '📍 Konum İzni',
              body:
                  'Neden İstenir: Yakınızdaki etkinlikleri ve kullanıcıları göstermek; Konum Radarı özelliğini çalıştırmak.\n\nKullanım Şekli: Yalnızca uygulama açıkken (Foreground). Arka planda konum alınmaz.\n\nPaylaşım: Diğer kullanıcılara tam konumunuz değil, yalnızca tahmini mesafe (örn. "3 km") gösterilir.\n\nReddetme Sonucu: Konum Radarı ve konum bazlı etkinlik önerileri devre dışı kalır; diğer tüm özellikler çalışmaya devam eder.',
              highlight: true,
              highlightColor: Color(0xFF10B981),
            ),
            _LegalItem(
              number: '',
              heading: '🔔 Bildirim İzni',
              body:
                  'Neden İstenir: Yeni katılım isteği, mesaj ve etkinlik hatırlatma bildirimleri göndermek.\n\nKullanım Şekli: OneSignal push bildirim altyapısı kullanılır. Cihaz kimliği şifrelenmiş şekilde saklanır.\n\nReddetme Sonucu: Push bildirimler alınmaz; uygulama içinde mesajlar ve bağlantılar yine de görüntülenebilir.',
            ),
            _LegalItem(
              number: '',
              heading: '📷 Kamera ve Fotoğraf Kitaplığı',
              body:
                  'Neden İstenir: Profil fotoğrafı ve etkinlik görseli yüklemek.\n\nKullanım Şekli: Yalnızca kullanıcının seçim yaptığı anlarda erişilir; sürekli arka plan erişimi yoktur.\n\nReddetme Sonucu: Fotoğraf yükleme işlevi çalışmaz; URL tabanlı alternatif kullanılabilir.',
            ),
            _LegalItem(
              number: '',
              heading: '🌐 İnternet Erişimi',
              body:
                  'Neden İstenir: Etkinlik verileri, mesajlar ve kullanıcı profilleri sunucudan anlık yüklenmektedir.\n\nKullanım Şekli: Tüm trafik HTTPS/SSL üzerinden şifrelenmiş olarak iletilir.\n\nReddetme Sonucu: Uygulama internet bağlantısı olmadan çalışamaz.',
              highlight: true,
              highlightColor: Color(0xFF06B6D4),
            ),
            _LegalItem(
              number: '',
              heading: '🎵 Müzik / Spotify Bağlantısı (İsteğe Bağlı)',
              body:
                  'Neden İstenir: Müzik zevkinize göre etkinlik ve kullanıcı eşleştirmesi yapmak.\n\nKullanım Şekli: Yalnızca kullanıcının bağlamayı onayladığı durumda Spotify OAuth kullanılır. Token güvenli depolamada saklanır.\n\nReddetme Sonucu: Müzik bazlı eşleştirme özelliği devre dışı kalır; diğer eşleştirme yöntemleri çalışmaya devam eder.',
            ),
            _LegalItem(
              number: '',
              heading: '📅 Takvim Erişimi (İsteğe Bağlı)',
              body:
                  'Neden İstenir: Katıldığınız etkinlikleri doğrudan cihaz takviminize eklemek.\n\nKullanım Şekli: Yalnızca kullanıcının "Takvime Ekle" butonuna bastığında tek seferlik erişim talep edilir.\n\nReddetme Sonucu: Etkinlikler otomatik takvime eklenmez; elle ekleme her zaman mümkündür.',
            ),
          ],
        ),
      ];

  // ─── 4. Topluluk Kuralları ────────────────────────────────────────────────
  List<_LegalSection> _communityContent() => [
        _LegalSection(
          icon: Icons.child_care_rounded,
          iconColor: const Color(0xFFEC4899),
          title: 'Topluluk Kuralları & Güvenlik Taahhüdü',
          subtitle: 'EventMatch güvenli ve kapsayıcı bir topluluktur',
          items: [
            _LegalItem(
              number: '🌟',
              heading: 'Saygı Zorunludur',
              body:
                  'Her kullanıcı, diğer kullanıcılara saygılı ve nazik davranmakla yükümlüdür. Kişisel saldırı, hakaret ve aşağılama kesinlikle yasaktır ve anında hesap askıya alınmasıyla sonuçlanır.',
              highlight: true,
              highlightColor: Color(0xFFEC4899),
            ),
            _LegalItem(
              number: '🚫',
              heading: 'Yasak Davranışlar',
              body:
                  '• Cinsel taciz veya istek içerikli mesajlar\n• Sahte kimlik, catfishing\n• Spam mesajlama veya ticari promosyon\n• Başka kullanıcıların kişisel bilgilerini paylaşma (Doxxing)\n• Şiddet tehdidi veya tehdit içerikli içerik\n• Uyuşturucu, silah veya yasadışı hizmet satışı\n• Bot hesap veya koordineli sahte eylem',
            ),
            _LegalItem(
              number: '🔒',
              heading: 'Güvenli Buluşma İlkeleri',
              body:
                  '• İlk buluşmalarınızı her zaman halka açık, kalabalık yerlerde gerçekleştirin\n• Buluştuğunuz kişi hakkında güvendiğiniz birine bilgi verin\n• Kendinizi güvensiz hissediyorsanız hemen ayrılın ve şikayet edin\n• Kişisel bilgilerinizi (ev adresi, telefon) acele paylaşmayın\n• EventMatch, uygulama dışındaki buluşmalardan sorumlu tutulamaz',
            ),
            _LegalItem(
              number: '⚡',
              heading: 'Moderasyon & Yaptırım Süreci',
              body:
                  'Raporlama: Herhangi bir profil veya mesajdan "Şikayet Et" butonuyla bildirim yapabilirsiniz.\n\nInceleme Süresi: Şikayetler moderasyon ekibimiz tarafından en geç 24 saat içinde incelenir.\n\nYaptırım Kademeleri:\n1. Uyarı ve içerik kaldırma\n2. Geçici hesap askıya alma (1–30 gün)\n3. Kalıcı hesap kapatma\n4. Yasal makamlarla paylaşım (suç teşkil eden durumlar)',
              highlight: true,
              highlightColor: Color(0xFFF59E0B),
            ),
            _LegalItem(
              number: '📞',
              heading: 'Acil Durum & Destek',
              body:
                  'Kendinizi veya başkasını tehlikede hissediyorsanız önce 112\'yi arayın.\n\nEventMatch Destek: destek@eventmatch.app\nGüvenlik Ekibi: guvenlik@eventmatch.app\nKVKK Başvurusu: kvkk@eventmatch.app\n\nYanıt Süresi: Mesai saatlerinde 4 saat, mesai dışında 24 saat.',
            ),
            _LegalItem(
              number: '✅',
              heading: 'Olumlu Topluluk Taahhüdü',
              body:
                  'EventMatch olarak amacımız; farklı geçmişlerden, kültürlerden ve ilgi alanlarından insanları ortak etkinlikler etrafında bir araya getirmektir. Bu hedefe ulaşmak için her üyemizin kapsayıcı, destekleyici ve güvenli bir ortam yaratmasını bekliyoruz. Birlikte daha güçlüyüz. 🎉',
            ),
          ],
        ),
      ];
}

// ═══════════════════════════════════════════════════════════════════════════
// YARDIMCI WIDGET'LAR
// ═══════════════════════════════════════════════════════════════════════════

class _TabMeta {
  final IconData icon;
  final String label;
  final Color color;

  const _TabMeta({required this.icon, required this.label, required this.color});
}

class _LegalSection {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final List<_LegalItem> items;

  const _LegalSection({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.items,
  });
}

class _LegalItem {
  final String number;
  final String heading;
  final String body;
  final bool highlight;
  final Color highlightColor;

  const _LegalItem({
    required this.number,
    required this.heading,
    required this.body,
    this.highlight = false,
    this.highlightColor = const Color(0xFF8B5CF6),
  });
}

/// Kaydırılabilir bölüm widget'ı — alta ulaşıldığında callback tetikler
class _ScrollableSection extends StatefulWidget {
  final List<_LegalSection> content;
  final VoidCallback onScrolledToBottom;

  const _ScrollableSection({
    required this.content,
    required this.onScrolledToBottom,
  });

  @override
  State<_ScrollableSection> createState() => _ScrollableSectionState();
}

class _ScrollableSectionState extends State<_ScrollableSection> {
  final ScrollController _scrollController = ScrollController();
  bool _hasTriggered = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Kısa içerikler için hemen "okundu" say
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients &&
          _scrollController.position.maxScrollExtent < 10) {
        _triggerRead();
      }
    });
  }

  void _onScroll() {
    if (!_hasTriggered &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 60) {
      _triggerRead();
    }
  }

  void _triggerRead() {
    if (!_hasTriggered) {
      _hasTriggered = true;
      widget.onScrolledToBottom();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        for (final section in widget.content) ...[
          _SectionHeader(section: section),
          const SizedBox(height: 16),
          for (int i = 0; i < section.items.length; i++) ...[
            _LegalItemCard(item: section.items[i]),
            if (i < section.items.length - 1) const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final _LegalSection section;

  const _SectionHeader({required this.section});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            section.iconColor.withOpacity(0.18),
            section.iconColor.withOpacity(0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: section.iconColor.withOpacity(0.3), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: section.iconColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(section.icon, color: section.iconColor, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section.title,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  section.subtitle,
                  style: GoogleFonts.outfit(
                      color: section.iconColor.withOpacity(0.8), fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalItemCard extends StatelessWidget {
  final _LegalItem item;

  const _LegalItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: item.highlight
            ? item.highlightColor.withOpacity(0.07)
            : AppColors.surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.highlight
              ? item.highlightColor.withOpacity(0.35)
              : Colors.white.withOpacity(0.06),
          width: item.highlight ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.number.isNotEmpty) ...[
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: item.highlight
                        ? item.highlightColor.withOpacity(0.2)
                        : AppColors.primary.withOpacity(0.15),
                    shape: item.number.length == 1 && int.tryParse(item.number) != null
                        ? BoxShape.circle
                        : BoxShape.rectangle,
                    borderRadius: item.number.length == 1 && int.tryParse(item.number) != null
                        ? null
                        : BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.number,
                    style: GoogleFonts.outfit(
                      color: item.highlight ? item.highlightColor : AppColors.primaryVariant,
                      fontSize: int.tryParse(item.number) != null ? 12 : 14,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  item.heading,
                  style: GoogleFonts.outfit(
                    color: item.highlight ? item.highlightColor : Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.body,
            style: GoogleFonts.outfit(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}
