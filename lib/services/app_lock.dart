import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// Проверка личности для блокировки приложения: отпечаток, лицо или PIN,
/// пароль и рисунок телефона. Приложение не хранит и не видит ничего из этого.
class AppLock {
  static final _auth = LocalAuthentication();

  /// Есть ли на телефоне защищённая блокировка экрана.
  static Future<bool> supported() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (e) {
      debugPrint('Lock check failed: $e');
      return false;
    }
  }

  /// Показывает системное окно проверки. true ― личность подтверждена.
  static Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(localizedReason: reason);
    } catch (e) {
      debugPrint('Authentication failed: $e');
      return false;
    }
  }
}
