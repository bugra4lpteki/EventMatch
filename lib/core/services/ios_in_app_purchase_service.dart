import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/events/services/mock_event_service.dart';

/// iOS Apple In-App Purchase & StoreKit 2 Servisi
/// Apple App Store Guideline 3.1.1 & 3.1.2 uyumlu StoreKit entegrasyonu.
class IosInAppPurchaseService {
  static final IosInAppPurchaseService _instance = IosInAppPurchaseService._internal();
  factory IosInAppPurchaseService() => _instance;
  IosInAppPurchaseService._internal();

  InAppPurchase? _iapInstance;
  InAppPurchase get _iap => _iapInstance ??= InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  // Apple App Store Connect Product IDs
  static const String vipWeeklyId = 'com.eventmatch.app.vip.weekly';
  static const String vipMonthlyId = 'com.eventmatch.app.vip.monthly';
  static const String vipQuarterlyId = 'com.eventmatch.app.vip.quarterly';
  static const String boostSingleId = 'com.eventmatch.app.boost.single';

  static const Set<String> productIds = {
    vipWeeklyId,
    vipMonthlyId,
    vipQuarterlyId,
    boostSingleId,
  };

  bool _isAvailable = false;
  bool get isAvailable => _isAvailable;

  List<ProductDetails> _products = [];
  List<ProductDetails> get products => _products;

  MockEventService? _eventService;

  /// Servisi başlat ve Apple StoreKit satın alma akışını dinle
  Future<void> initialize(MockEventService eventService) async {
    _eventService = eventService;

    // Yalnızca iOS platformunda Apple StoreKit çalıştırılır
    if (kIsWeb || !Platform.isIOS) {
      _isAvailable = false;
      return;
    }

    try {
      _isAvailable = await _iap.isAvailable();
      debugPrint('[StoreKit] 🍏 Apple In-App Purchase Kullanılabilir: $_isAvailable');

      if (_isAvailable) {
        // Satın alma akışı dinleyicisi
        _subscription?.cancel();
        _subscription = _iap.purchaseStream.listen(
          _handlePurchaseUpdates,
          onDone: () => _subscription?.cancel(),
          onError: (error) => debugPrint('[StoreKit] ⚠️ Satın alma akış hatası: $error'),
        );

        // Ürün detaylarını Apple StoreKit üzerinden sorgula
        final ProductDetailsResponse response = await _iap.queryProductDetails(productIds);
        if (response.error != null) {
          debugPrint('[StoreKit] ⚠️ Ürün sorgulama hatası: ${response.error!.message}');
        }
        _products = response.productDetails;
        debugPrint('[StoreKit] 📦 Yüklenen Apple ürün sayısı: ${_products.length}');
      }
    } catch (e) {
      debugPrint('[StoreKit] ⚠️ StoreKit başlatma istisnası: $e');
    }
  }

  /// Satın alma güncellemelerini işle (Satın alındı, Geri yüklendi, İptal, Hata)
  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchaseDetails in purchaseDetailsList) {
      debugPrint('[StoreKit] 🔔 Satın alma durumu: ${purchaseDetails.productID} -> ${purchaseDetails.status}');

      switch (purchaseDetails.status) {
        case PurchaseStatus.pending:
          // Apple Face ID / Touch ID / Şifre bekleniyor
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // Başarılı satın alma veya geri yükleme
          await _deliverProduct(purchaseDetails);
          break;

        case PurchaseStatus.error:
          debugPrint('[StoreKit] ❌ Satın alma hatası: ${purchaseDetails.error?.message}');
          break;

        case PurchaseStatus.canceled:
          debugPrint('[StoreKit] ↩️ Satın alma kullanıcı tarafından iptal edildi.');
          break;
      }

      // Apple StoreKit kuralı: İşlem bittiğinde StoreKit kuyruğundan tamamlandı olarak düşürülmelidir
      if (purchaseDetails.pendingCompletePurchase) {
        await _iap.completePurchase(purchaseDetails);
      }
    }
  }

  /// Satın alınan ürünü kullanıcı hesabına tanımla ve Supabase'e yaz
  Future<void> _deliverProduct(PurchaseDetails purchase) async {
    try {
      final productId = purchase.productID;
      int days = 30;

      if (productId == vipWeeklyId) {
        days = 7;
      } else if (productId == vipMonthlyId) {
        days = 30;
      } else if (productId == vipQuarterlyId) {
        days = 90;
      } else if (productId == boostSingleId) {
        // 1 Saatlik Harita Boost
        if (_eventService != null) {
          await _eventService!.activateBoost(hours: 1);
        }
        return;
      }

      // VIP Aboneliğini aktifleştir
      if (_eventService != null) {
        await _eventService!.activateVip(days: days);
      }

      // Supabase üzerinde yedekleme / sync
      final supabase = Supabase.instance.client;
      final currentUserId = supabase.auth.currentUser?.id;
      if (currentUserId != null && currentUserId.isNotEmpty) {
        final expiry = DateTime.now().add(Duration(days: days)).toUtc().toIso8601String();
        await supabase.from('users').update({
          'is_vip': true,
          'vip_expires_at': expiry,
        }).eq('id', currentUserId);
      }

      debugPrint('[StoreKit] 👑 VIP Başarıyla Teslim Edildi: $productId ($days gün)');
    } catch (e) {
      debugPrint('[StoreKit] ⚠️ Ürün teslim hatası: $e');
    }
  }

  /// Apple In-App Purchase Satın Alma Başlat
  Future<bool> buyProduct(String productId) async {
    try {
      if (kIsWeb || (!kIsWeb && !Platform.isIOS)) {
        debugPrint('[StoreKit] ⚠️ iOS harici platform, simülasyon akışı çalıştırılıyor.');
        return _simulatePurchase(productId);
      }

      // iOS Platformundayız
      if (!_isAvailable) {
        _isAvailable = await _iap.isAvailable();
      }

      if (!_isAvailable) {
        throw Exception('Apple App Store (StoreKit) servislerine erişilemiyor. Lütfen Apple Kimliğinizle App Store\'a giriş yaptığınızdan emin olun.');
      }

      // Ürünler henüz yüklenmediyse tekrar Apple'dan sorgula
      if (_products.isEmpty) {
        debugPrint('[StoreKit] 🔄 Ürünler boş, Apple StoreKit üzerinden yeniden sorgulanıyor...');
        final ProductDetailsResponse response = await _iap.queryProductDetails(productIds);
        _products = response.productDetails;
        debugPrint('[StoreKit] 📦 Sorgu sonucu yüklenen ürün sayısı: ${_products.length}');
      }

      if (_products.isEmpty) {
        throw Exception(
          'Abonelik ürünleri Apple sunucularında henüz işleniyor.\n'
          'Banka ve sözleşme onayı (24 saatlik süreç) tamamlandığında doğrudan Apple Pay ile açılacaktır.',
        );
      }

      final product = _products.firstWhere(
        (p) => p.id == productId,
        orElse: () => throw Exception('Seçilen ürün Apple StoreKit üzerinde bulunamadı: $productId'),
      );

      final purchaseParam = PurchaseParam(productDetails: product);
      if (productId == boostSingleId) {
        return await _iap.buyConsumable(purchaseParam: purchaseParam);
      } else {
        return await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      }
    } catch (e) {
      debugPrint('[StoreKit] Satın alma başlatma hatası: $e');
      rethrow;
    }
  }

  /// Apple App Store Guideline 3.1.1 Zorunluluğu: Satın Alımları Geri Yükle (Restore Purchases)
  Future<bool> restorePurchases() async {
    try {
      if (Platform.isIOS && _isAvailable) {
        await _iap.restorePurchases();
        return true;
      }
      
      // Simülatör ve test ortamında Supabase üzerinden geri yükleme kontrolü
      debugPrint('[StoreKit] ⚠️ StoreKit simülasyon modu: Supabase üzerinden VIP kontrol ediliyor.');
      final supabase = Supabase.instance.client;
      final currentUserId = supabase.auth.currentUser?.id;
      if (currentUserId != null) {
        final res = await supabase
            .from('users')
            .select('is_vip, vip_expires_at')
            .eq('id', currentUserId)
            .maybeSingle();

        if (res != null && res['is_vip'] == true) {
          final expiryStr = res['vip_expires_at'];
          if (expiryStr != null) {
            final expiry = DateTime.tryParse(expiryStr);
            if (expiry != null && expiry.isAfter(DateTime.now())) {
              final remainingDays = expiry.difference(DateTime.now()).inDays;
              await _eventService?.activateVip(days: remainingDays > 0 ? remainingDays : 1);
              return true;
            }
          }
        }
      }
      return false;
    } catch (e) {
      debugPrint('[StoreKit] Restore purchases hatası: $e');
      return false;
    }
  }

  /// Simülatör ve test ortamları için güvenli mock satın alma
  Future<bool> _simulatePurchase(String productId) async {
    int days = 30;
    if (productId == vipWeeklyId) days = 7;
    if (productId == vipMonthlyId) days = 30;
    if (productId == vipQuarterlyId) days = 90;

    if (productId == boostSingleId) {
      if (_eventService != null) {
        await _eventService!.activateBoost(hours: 1);
      }
      return true;
    }

    if (_eventService != null) {
      await _eventService!.activateVip(days: days);
    }

    // Supabase üzerinde yedekleme / sync
    try {
      final supabase = Supabase.instance.client;
      final currentUserId = supabase.auth.currentUser?.id;
      if (currentUserId != null && currentUserId.isNotEmpty) {
        final expiry = DateTime.now().add(Duration(days: days)).toUtc().toIso8601String();
        await supabase.from('users').update({
          'is_vip': true,
          'vip_expires_at': expiry,
        }).eq('id', currentUserId);
      }
    } catch (e) {
      debugPrint('[StoreKit] Simülasyon Supabase sync hatası: $e');
    }

    return true;
  }

  void dispose() {
    _subscription?.cancel();
  }
}
