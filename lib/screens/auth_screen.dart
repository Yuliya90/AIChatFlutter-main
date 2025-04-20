// Импорт основных виджетов Flutter
import 'package:flutter/material.dart';
// Импорт для работы с генерацией случайных чисел
import 'dart:math';
// Импорт модели данных аутентификации
import '../models/auth_data.dart';
// Импорт сервиса для работы с базой данных
import '../services/database_service.dart';
// Импорт клиента для работы с API
import '../api/openrouter_client.dart';
// Импорт экрана чата
import 'chat_screen.dart';

// Экран аутентификации
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  // Контроллер для поля ввода API ключа
  final TextEditingController _apiKeyController = TextEditingController();
  // Контроллер для поля ввода PIN-кода
  final TextEditingController _pinController = TextEditingController();

  // Состояние загрузки
  bool _isLoading = false;
  // Сообщение об ошибке
  String? _errorMessage;
  // Сообщение об успехе
  String? _successMessage;

  // Флаг, указывающий, есть ли сохраненные данные аутентификации
  bool _hasAuthData = false;
  // Флаг, указывающий, нужно ли показывать форму сброса ключа
  bool _showResetForm = false;

  // Сервис для работы с базой данных
  final DatabaseService _db = DatabaseService();
  // Клиент для работы с API
  final OpenRouterClient _api = OpenRouterClient();

  @override
  void initState() {
    super.initState();
    // Проверка наличия сохраненных данных аутентификации
    _checkAuthData();
  }

  // Метод проверки наличия сохраненных данных аутентификации
  Future<void> _checkAuthData() async {
    try {
      // Получение данных аутентификации из базы данных
      final authData = await _db.getAuthData();

      // Обновление состояния
      setState(() {
        _hasAuthData = authData != null;
      });
    } catch (e) {
      debugPrint('Error checking auth data: $e');
    }
  }

  // Метод генерации случайного PIN-кода
  String _generatePin() {
    // Генерация случайного 4-значного числа
    final random = Random();
    return (1000 + random.nextInt(9000)).toString();
  }

  // Метод проверки API ключа и сохранения данных аутентификации
  Future<void> _validateAndSaveKey(String apiKey) async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _successMessage = null;
      });

      // Проверка формата ключа
      String provider;
      try {
        provider = AuthData.determineProvider(apiKey);
      } catch (e) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Неверный формат ключа API. Ключ должен начинаться с sk-or-vv-... или sk-or-v1-...';
        });
        return;
      }

      // Инициализация клиента с новым ключом
      await _api.initialize(apiKey);

      // Проверка валидности ключа и баланса
      final result = await _api.validateKeyAndCheckBalance();

      if (!result['valid']) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Ошибка проверки ключа: ${result['error']}';
        });
        return;
      }

      // Проверка баланса
      final balance = result['balance'] as double;
      if (balance <= 0) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Недостаточно средств на балансе: ${result['balanceText']}';
        });
        return;
      }

      // Генерация PIN-кода
      final pin = _generatePin();

      // Создание объекта данных аутентификации
      final authData = AuthData(
        apiKey: apiKey,
        pin: pin,
        provider: provider,
      );

      // Сохранение данных аутентификации в базу данных
      await _db.saveAuthData(authData);

      // Обновление состояния
      setState(() {
        _isLoading = false;
        _hasAuthData = true;
        _successMessage = 'Ключ API успешно сохранен. Ваш PIN-код: $pin';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Ошибка: $e';
      });
    }
  }

  // Метод проверки PIN-кода
  Future<void> _validatePin(String pin) async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Получение данных аутентификации из базы данных
      final authData = await _db.getAuthData();

      // Проверка наличия данных
      if (authData == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Данные аутентификации не найдены';
          _hasAuthData = false;
        });
        return;
      }

      // Проверка PIN-кода
      if (authData.pin != pin) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Неверный PIN-код';
        });
        return;
      }

      // Инициализация клиента с сохраненным ключом
      await _api.initialize(authData.apiKey);

      // Переход на экран чата
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const ChatScreen()),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Ошибка: $e';
      });
    }
  }

  // Метод сброса ключа API
  Future<void> _resetKey() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Очистка данных аутентификации
      await _db.clearAuthData();

      // Обновление состояния
      setState(() {
        _isLoading = false;
        _hasAuthData = false;
        _showResetForm = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Ошибка при сбросе ключа: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF262626),
        title: const Text(
          'Аутентификация',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Логотип или иконка приложения
                const Icon(
                  Icons.chat,
                  size: 80,
                  color: Colors.blue,
                ),
                const SizedBox(height: 24),

                // Заголовок
                Text(
                  _hasAuthData
                      ? 'Введите PIN-код для входа'
                      : 'Добро пожаловать в AI Chat',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Описание
                Text(
                  _hasAuthData
                      ? 'Введите 4-значный PIN-код, который был сгенерирован при первом входе'
                      : 'Для начала работы введите ключ API от openRouter.ai или VSEGPT',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Форма ввода PIN-кода
                if (_hasAuthData && !_showResetForm) ...[
                  // Поле ввода PIN-кода
                  TextField(
                    controller: _pinController,
                    decoration: const InputDecoration(
                      labelText: 'PIN-код',
                      labelStyle: TextStyle(color: Colors.white70),
                      hintText: 'Введите 4-значный PIN-код',
                      hintStyle: TextStyle(color: Colors.white30),
                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white30),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.blue),
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),

                  // Кнопка входа
                  ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () => _validatePin(_pinController.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Войти',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                  ),
                  const SizedBox(height: 16),

                  // Кнопка сброса ключа
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            setState(() {
                              _showResetForm = true;
                              _errorMessage = null;
                            });
                          },
                    child: const Text(
                      'Сбросить ключ API',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ]

                // Форма подтверждения сброса ключа
                else if (_hasAuthData && _showResetForm) ...[
                  const Text(
                    'Вы уверены, что хотите сбросить ключ API?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Кнопки подтверждения и отмены
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Кнопка отмены
                      OutlinedButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                setState(() {
                                  _showResetForm = false;
                                  _errorMessage = null;
                                });
                              },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white54),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child: const Text(
                          'Отмена',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Кнопка подтверждения
                      ElevatedButton(
                        onPressed: _isLoading ? null : _resetKey,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Сбросить',
                                style: TextStyle(color: Colors.white),
                              ),
                      ),
                    ],
                  ),
                ]

                // Форма ввода ключа API
                else ...[
                  // Поле ввода ключа API
                  TextField(
                    controller: _apiKeyController,
                    decoration: const InputDecoration(
                      labelText: 'Ключ API',
                      labelStyle: TextStyle(color: Colors.white70),
                      hintText: 'Введите ключ API (sk-or-...)',
                      hintStyle: TextStyle(color: Colors.white30),
                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white30),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.blue),
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 16),

                  // Кнопка проверки ключа
                  ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () => _validateAndSaveKey(_apiKeyController.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Проверить ключ',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                  ),
                ],

                const SizedBox(height: 16),

                // Сообщение об ошибке
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // Сообщение об успехе
                if (_successMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _successMessage!,
                          style: const TextStyle(color: Colors.green),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (context) => const ChatScreen(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          child: const Text(
                            'Продолжить',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _pinController.dispose();
    super.dispose();
  }
}
