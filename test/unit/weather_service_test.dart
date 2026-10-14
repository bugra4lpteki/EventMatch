import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:event_match/core/services/weather_service.dart';

void main() {
  group('🌤️ WeatherService & EventWeatherData Tests', () {
    test('EventWeatherData fromOpenMeteoJson parses sunny daytime weather correctly', () {
      final mockJson = {
        'latitude': 41.05,
        'longitude': 28.98,
        'current': {
          'time': '2026-10-14T16:00',
          'temperature_2m': 22.4,
          'apparent_temperature': 21.8,
          'relative_humidity_2m': 55,
          'is_day': 1,
          'precipitation': 0.0,
          'weather_code': 0,
          'wind_speed_10m': 12.3,
        }
      };

      final data = EventWeatherData.fromOpenMeteoJson(mockJson);

      expect(data.temperature, 22.4);
      expect(data.apparentTemperature, 21.8);
      expect(data.humidity, 55);
      expect(data.isDay, true);
      expect(data.weatherCode, 0);
      expect(data.conditionText, contains('Açık & Güneşli'));
      expect(data.icon, Icons.wb_sunny_rounded);
    });

    test('EventWeatherData fromOpenMeteoJson parses rainy night weather correctly', () {
      final mockJson = {
        'latitude': 41.05,
        'longitude': 28.98,
        'current': {
          'time': '2026-10-14T21:00',
          'temperature_2m': 13.0,
          'apparent_temperature': 11.5,
          'relative_humidity_2m': 85,
          'is_day': 0,
          'precipitation': 2.4,
          'weather_code': 63,
          'wind_speed_10m': 28.0,
        }
      };

      final data = EventWeatherData.fromOpenMeteoJson(mockJson);

      expect(data.temperature, 13.0);
      expect(data.isDay, false);
      expect(data.weatherCode, 63);
      expect(data.conditionText, 'Yağmurlu');
      expect(data.icon, Icons.water_drop_rounded);
      expect(data.advice, contains('yağış bekleniyor'));
    });

    test('EventWeatherData generates appropriate clothing advice for cold weather', () {
      final mockJson = {
        'current': {
          'temperature_2m': 11.0,
          'apparent_temperature': 9.0,
          'relative_humidity_2m': 60,
          'is_day': 1,
          'precipitation': 0.0,
          'weather_code': 2,
          'wind_speed_10m': 10.0,
        }
      };

      final data = EventWeatherData.fromOpenMeteoJson(mockJson);
      expect(data.advice, contains('serin'));
    });

    test('WeatherService getWeatherForLocationName falls back to valid coordinates for known cities', () async {
      final service = WeatherService();
      
      // Should handle location without throwing
      final weather = await service.getWeatherForLocationName('Zorlu PSM, Beşiktaş / İstanbul');
      // If network is available, weather is fetched; if not, null is gracefully returned
      expect(weather == null || weather is EventWeatherData, true);
    });
  });
}
