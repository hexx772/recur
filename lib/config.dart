/// Поиск подписок в SMS. В сборке для Google Play его нет: разрешение
/// READ_SMS там запрещено правилами магазина. Сборка:
/// `flutter build appbundle --flavor play --dart-define=SMS=false`.
const bool kSmsEnabled = bool.fromEnvironment('SMS', defaultValue: true);
