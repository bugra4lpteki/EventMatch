import 'package:flutter/material.dart';

class AppStrings {
  final Locale locale;
  AppStrings(this.locale);

  static AppStrings of(BuildContext context) {
    return Localizations.of<AppStrings>(context, AppStrings) ?? AppStrings(const Locale('tr'));
  }

  static const _localizedValues = <String, Map<String, String>>{
    'tr': {
      'app_name': 'EventMatch',
      'explore': 'Keşfet',
      'radar': 'Radar',
      'matches': 'Eşleşmeler',
      'messages': 'Mesajlar',
      'profile': 'Profil',
      'tickets': 'Bilet Cüzdanım',
      'settings': 'Ayarlar',
      'join_event': 'Ben de Geliyorum',
      'joined_event': 'Katıldın',
      'buy_ticket': 'Bilet Al',
      'community_chat': 'Topluluk Sohbeti',
      'reviews_and_ratings': 'Değerlendirmeler & Yorumlar',
      'filter': 'Filtrele',
      'search_placeholder': 'Etkinlik, sanatçı veya mekan ara...',
      'meetup_title': 'Topluluk Buluşması',
      'create_event': 'Etkinlik / Buluşma Oluştur',
      'logout': 'Çıkış Yap',
      'vip_member': 'VIP Üyelik',
    },
    'en': {
      'app_name': 'EventMatch',
      'explore': 'Explore',
      'radar': 'Radar',
      'matches': 'Matches',
      'messages': 'Messages',
      'profile': 'Profile',
      'tickets': 'My Tickets',
      'settings': 'Settings',
      'join_event': 'Count Me In',
      'joined_event': 'Attending',
      'buy_ticket': 'Buy Ticket',
      'community_chat': 'Community Chat',
      'reviews_and_ratings': 'Reviews & Ratings',
      'filter': 'Filter',
      'search_placeholder': 'Search events, artists or venues...',
      'meetup_title': 'Community Meetup',
      'create_event': 'Create Event / Meetup',
      'logout': 'Log Out',
      'vip_member': 'VIP Membership',
    },
  };

  String get(String key) {
    final langCode = locale.languageCode;
    return _localizedValues[langCode]?[key] ?? _localizedValues['tr']?[key] ?? key;
  }
}
