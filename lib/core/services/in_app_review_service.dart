import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// StoreKit SKStoreReviewController & Google In-App Review Servisi
/// Apple Review Guideline 5.6.1 standartlarına tam uyumludur.
class InAppReviewService {
  static final InAppReviewService _instance = InAppReviewService._internal();
  factory InAppReviewService() => _instance;
  InAppReviewService._internal();

  final InAppReview _inAppReview = InAppReview.instance;

  static const String _prefKeyLastPromptTime = 'key_last_review_prompt_time';
  static const String _prefKeyActionCount = 'key_review_positive_action_count';
  static const int _minActionsBeforePrompt = 2; // En az 2 olumlu etkileşim sonrası
  static const int _cooldownDays = 14; // İki istek arasında en az 14 gün

  /// Kullanıcı bilet satın alma sayfasına tıkladığında nazik değerlendirme tetiklemesi
  Future<void> triggerTicketPurchaseReview() async {
    await _recordPositiveActionAndCheck(reason: 'bilet_alindi_veya_tiklandi');
  }

  /// Kullanıcı başarıyla bir etkinlik arkadaşı bulduğunda / istek kabul edildiğinde
  Future<void> triggerMatchSuccessReview() async {
    await _recordPositiveActionAndCheck(reason: 'basarili_etkinlik_arkadasi_bulundu');
  }

  /// Kullanıcı bir etkinliğe katıldığında
  Future<void> triggerEventAttendedReview() async {
    await _recordPositiveActionAndCheck(reason: 'etkinlige_katilindi');
  }

  /// Nazik değerlendirme koşullarını kontrol eder ve uygunsa SKStoreReviewController'ı çağırır
  Future<void> _recordPositiveActionAndCheck({required String reason}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      int actionCount = (prefs.getInt(_prefKeyActionCount) ?? 0) + 1;
      await prefs.setInt(_prefKeyActionCount, actionCount);

      final lastTimeMs = prefs.getInt(_prefKeyLastPromptTime) ?? 0;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final daysSinceLast = (nowMs - lastTimeMs) / (1000 * 60 * 60 * 24);

      debugPrint('[InAppReview] Olumlu aksiyon: $reason (Toplam: $actionCount, Geçen Gün: ${daysSinceLast.toStringAsFixed(1)})');

      if (actionCount >= _minActionsBeforePrompt && daysSinceLast >= _cooldownDays) {
        if (await _inAppReview.isAvailable()) {
          debugPrint('[InAppReview] 🌟 StoreKit SKStoreReviewController tetikleniyor...');
          await _inAppReview.requestReview();
          await prefs.setInt(_prefKeyLastPromptTime, nowMs);
          await prefs.setInt(_prefKeyActionCount, 0);
        }
      }
    } catch (e) {
      debugPrint('[InAppReview] İstek hatası: $e');
    }
  }

  /// App Store mağaza sayfasını doğrudan açar (Ayarlar ekranı için)
  Future<void> openStoreListing() async {
    try {
      if (await _inAppReview.isAvailable()) {
        await _inAppReview.openStoreListing(
          appStoreId: 'com.eventmatch.social',
        );
      }
    } catch (e) {
      debugPrint('[InAppReview] Mağaza açma hatası: $e');
    }
  }
}
