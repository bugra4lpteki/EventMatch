import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Etkinlik hava durumu verisi modeli
class EventWeatherData {
  final double temperature;
  final double apparentTemperature;
  final int humidity;
  final double windSpeed;
  final double precipitation;
  final int weatherCode;
  final bool isDay;
  final String conditionText;
  final IconData icon;
  final Color iconColor;
  final String advice;
  final DateTime fetchedAt;

  EventWeatherData({
    required this.temperature,
    required this.apparentTemperature,
    required this.humidity,
    required this.windSpeed,
    required this.precipitation,
    required this.weatherCode,
    required this.isDay,
    required this.conditionText,
    required this.icon,
    required this.iconColor,
    required this.advice,
    required this.fetchedAt,
  });

  /// WMO Hava Durumu Kodunu Türkçe açıklamaya ve ikona dönüştürür
  factory EventWeatherData.fromOpenMeteoJson(Map<String, dynamic> json) {
    final current = json['current'] as Map<String, dynamic>? ?? {};
    
    final temp = (current['temperature_2m'] as num?)?.toDouble() ?? 20.0;
    final apparent = (current['apparent_temperature'] as num?)?.toDouble() ?? temp;
    final humidity = (current['relative_humidity_2m'] as num?)?.toInt() ?? 50;
    final wind = (current['wind_speed_10m'] as num?)?.toDouble() ?? 10.0;
    final precip = (current['precipitation'] as num?)?.toDouble() ?? 0.0;
    final code = (current['weather_code'] as num?)?.toInt() ?? 0;
    final isDay = (current['is_day'] as num?)?.toInt() == 1;

    final info = _resolveWeatherCode(code, isDay);
    final advice = _generateEventAdvice(temp, precip, wind, code);

    return EventWeatherData(
      temperature: temp,
      apparentTemperature: apparent,
      humidity: humidity,
      windSpeed: wind,
      precipitation: precip,
      weatherCode: code,
      isDay: isDay,
      conditionText: info.text,
      icon: info.icon,
      iconColor: info.color,
      advice: advice,
      fetchedAt: DateTime.now(),
    );
  }

  static _WeatherInfo _resolveWeatherCode(int code, bool isDay) {
    switch (code) {
      case 0:
        return _WeatherInfo(
          text: isDay ? 'Açık & Güneşli' : 'Açık & Berrak Gece',
          icon: isDay ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded,
          color: isDay ? const Color(0xFFFBBF24) : const Color(0xFF818CF8),
        );
      case 1:
      case 2:
        return _WeatherInfo(
          text: 'Parçalı Bulutlu',
          icon: isDay ? Icons.cloud_queue_rounded : Icons.nights_stay_outlined,
          color: const Color(0xFF38BDF8),
        );
      case 3:
        return _WeatherInfo(
          text: 'Çok Bulutlu',
          icon: Icons.cloud_rounded,
          color: const Color(0xFF94A3B8),
        );
      case 45:
      case 48:
        return _WeatherInfo(
          text: 'Sisli',
          icon: Icons.blur_on_rounded,
          color: const Color(0xFFCBD5E1),
        );
      case 51:
      case 53:
      case 55:
        return _WeatherInfo(
          text: 'Hafif Çisenti',
          icon: Icons.grain_rounded,
          color: const Color(0xFF60A5FA),
        );
      case 61:
      case 63:
      case 65:
        return _WeatherInfo(
          text: 'Yağmurlu',
          icon: Icons.water_drop_rounded,
          color: const Color(0xFF3B82F6),
        );
      case 71:
      case 73:
      case 75:
      case 77:
        return _WeatherInfo(
          text: 'Kar Yağışlı',
          icon: Icons.ac_unit_rounded,
          color: const Color(0xFF93C5FD),
        );
      case 80:
      case 81:
      case 82:
        return _WeatherInfo(
          text: 'Sağanak Yağış',
          icon: Icons.thunderstorm_rounded,
          color: const Color(0xFF2563EB),
        );
      case 95:
      case 96:
      case 99:
        return _WeatherInfo(
          text: 'Gök Gürültülü Fırtına',
          icon: Icons.flash_on_rounded,
          color: const Color(0xFFF59E0B),
        );
      default:
        return _WeatherInfo(
          text: 'Güzel Hava',
          icon: Icons.wb_sunny_rounded,
          color: const Color(0xFFFBBF24),
        );
    }
  }

  static String _generateEventAdvice(double temp, double precip, double wind, int code) {
    if (precip > 0.5 || (code >= 61 && code <= 99)) {
      return 'Etkinlik alanında yağış bekleniyor 🌧️ Su geçirmez mont veya hafif yağmurluk almayı unutma!';
    }
    if (wind > 25.0) {
      return 'Rüzgarlı bir hava var 💨 Açık hava etkinliği için rüzgarlık veya şal iyi bir tercih olur.';
    }
    if (temp < 14.0) {
      return 'Akşam hava serin olabilir 🧥 Katmanlı giyinmeni ve üzerine kalın bir ceket almanı öneririz.';
    }
    if (temp > 27.0) {
      return 'Sıcak ve açık bir hava! ☀️ Bol su tüketmeyi, güneş gözlüğü ve ferah giysileri unutma.';
    }
    return 'Etkinlik ve festival için ideal hava şartları! 🌟 Keyifli anlar dileriz.';
  }
}

class _WeatherInfo {
  final String text;
  final IconData icon;
  final Color color;

  _WeatherInfo({
    required this.text,
    required this.icon,
    required this.color,
  });
}

/// Etkinlik konumuna göre anlık hava durumu getiren ve önbelleğe alan servis
class WeatherService {
  static final WeatherService _instance = WeatherService._internal();
  factory WeatherService() => _instance;
  WeatherService._internal();

  final Map<String, _CachedWeather> _cache = {};
  static const Duration _cacheDuration = Duration(minutes: 15);

  /// Verilen koordinatlar için Open-Meteo API'den anlık hava durumunu getirir
  Future<EventWeatherData?> getWeatherForCoordinates({
    required double latitude,
    required double longitude,
    bool forceRefresh = false,
  }) async {
    // Koordinatları 2 basamağa yuvarlayarak yakındaki mekanlar için ortak önbellek kullan
    final cacheKey = '${latitude.toStringAsFixed(2)}_${longitude.toStringAsFixed(2)}';

    if (!forceRefresh && _cache.containsKey(cacheKey)) {
      final cached = _cache[cacheKey]!;
      if (DateTime.now().difference(cached.timestamp) < _cacheDuration) {
        return cached.data;
      }
    }

    try {
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$latitude'
        '&longitude=$longitude'
        '&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,wind_speed_10m'
        '&timezone=auto',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final weather = EventWeatherData.fromOpenMeteoJson(data);
        _cache[cacheKey] = _CachedWeather(data: weather, timestamp: DateTime.now());
        return weather;
      }
    } catch (e) {
      debugPrint('[WeatherService] ⚠️ Live weather fetch error: $e');
    }

    // Eğer canlı API yanıt vermezse önbellekteki eski veriyi döndür veya null ver
    return _cache[cacheKey]?.data;
  }

  /// Konum adından (İstanbul, Ankara vb.) koordinat tahminiyle hava durumu getirir
  Future<EventWeatherData?> getWeatherForLocationName(String locationName) async {
    final lower = locationName.toLowerCase();
    double lat = 41.0082;
    double lng = 28.9784; // Default İstanbul

    if (lower.contains('ankara')) {
      lat = 39.9334;
      lng = 32.8597;
    } else if (lower.contains('izmir') || lower.contains('izmir')) {
      lat = 38.4192;
      lng = 27.1287;
    } else if (lower.contains('bursa')) {
      lat = 40.1885;
      lng = 29.0610;
    } else if (lower.contains('antalya')) {
      lat = 36.8969;
      lng = 30.7133;
    } else if (lower.contains('eskisehir') || lower.contains('eskişehir')) {
      lat = 39.7767;
      lng = 30.5206;
    }

    return getWeatherForCoordinates(latitude: lat, longitude: lng);
  }
}

class _CachedWeather {
  final EventWeatherData data;
  final DateTime timestamp;

  _CachedWeather({required this.data, required this.timestamp});
}
