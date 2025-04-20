// Импорт основных классов Flutter
import 'package:flutter/foundation.dart';

// Класс, представляющий данные аутентификации
class AuthData {
  // API ключ для доступа к сервисам
  final String apiKey;
  // PIN-код для входа в приложение
  final String pin;
  // Тип провайдера (openRouter или VSEGPT)
  final String provider;
  // Временная метка создания
  final DateTime createdAt;

  // Конструктор класса AuthData
  AuthData({
    required this.apiKey, // Обязательный параметр: API ключ
    required this.pin, // Обязательный параметр: PIN-код
    required this.provider, // Обязательный параметр: тип провайдера
    DateTime? createdAt, // Необязательный параметр: временная метка
  }) : createdAt = createdAt ??
            DateTime.now(); // Установка текущего времени, если не указано

  // Преобразование объекта в JSON
  Map<String, dynamic> toJson() {
    return {
      'apiKey': apiKey, // API ключ
      'pin': pin, // PIN-код
      'provider': provider, // Тип провайдера
      'createdAt':
          createdAt.toIso8601String(), // Временная метка в формате ISO 8601
    };
  }

  // Фабричный метод для создания объекта из JSON
  factory AuthData.fromJson(Map<String, dynamic> json) {
    try {
      // Создание объекта AuthData из JSON
      return AuthData(
        apiKey: json['apiKey'] as String, // Получение API ключа
        pin: json['pin'] as String, // Получение PIN-кода
        provider: json['provider'] as String, // Получение типа провайдера
        createdAt: DateTime.parse(
            json['createdAt'] as String), // Парсинг временной метки
      );
    } catch (e) {
      // Логирование ошибок при декодировании
      debugPrint('Error decoding auth data: $e');
      // Повторный выброс исключения
      rethrow;
    }
  }

  // Определение типа провайдера по формату ключа
  static String determineProvider(String apiKey) {
    if (apiKey.startsWith('sk-or-vv-')) {
      return 'VSEGPT';
    } else if (apiKey.startsWith('sk-or-v1-')) {
      return 'openRouter';
    } else {
      throw Exception('Неизвестный формат ключа API');
    }
  }
}
