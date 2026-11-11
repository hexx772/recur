const kCategories = [
  'Видео и музыка',
  'AI',
  'Софт и облако',
  'Игры',
  'Новости и книги',
  'Здоровье и спорт',
  'Другое',
];

const kCurrencies = ['RUB', 'KZT', 'USD', 'EUR', 'GBP'];

/// Справочник популярных сервисов: категория, ссылка отмены и слова для поиска
/// в SMS/письмах. Цены зависят от региона, поэтому их здесь нет.
class KnownService {
  const KnownService(this.name, this.category, this.cancelUrl,
      {this.keywords = const []});

  final String name;
  final String category;
  final String cancelUrl;

  /// Строчные подстроки, по которым сервис узнаётся в тексте.
  final List<String> keywords;
}

class KnownServices {
  static const all = [
    KnownService('Netflix', 'Видео и музыка',
        'https://www.netflix.com/cancelplan',
        keywords: ['netflix']),
    KnownService('YouTube Premium', 'Видео и музыка',
        'https://www.youtube.com/paid_memberships',
        keywords: ['youtube', 'google youtube']),
    KnownService('Spotify', 'Видео и музыка',
        'https://www.spotify.com/account/subscription/',
        keywords: ['spotify']),
    KnownService('Яндекс Плюс', 'Видео и музыка',
        'https://plus.yandex.ru/my',
        keywords: ['yandex plus', 'яндекс плюс', 'яндекс.плюс', 'yandex.plus']),
    KnownService('Apple Music', 'Видео и музыка',
        'https://support.apple.com/ru-ru/118428',
        keywords: ['apple music', 'apple.com/bill', 'itunes']),
    KnownService('iCloud+', 'Софт и облако',
        'https://support.apple.com/ru-ru/118428',
        keywords: ['icloud']),
    KnownService('Google One', 'Софт и облако',
        'https://one.google.com/settings',
        keywords: ['google one', 'google storage']),
    KnownService('ChatGPT Plus', 'AI',
        'https://help.openai.com/en/articles/6950777',
        keywords: ['openai', 'chatgpt']),
    KnownService('Claude Pro', 'AI',
        'https://support.claude.com/en/articles/8325606',
        keywords: ['claude', 'anthropic']),
    KnownService('Google AI Pro', 'AI',
        'https://one.google.com/settings',
        keywords: ['gemini', 'google ai']),
    KnownService('Perplexity Pro', 'AI',
        'https://www.perplexity.ai/settings/subscription',
        keywords: ['perplexity']),
    KnownService('Midjourney', 'AI',
        'https://docs.midjourney.com/hc/en-us/articles/32691098396813',
        keywords: ['midjourney']),
    KnownService('GitHub Copilot', 'AI',
        'https://github.com/settings/billing',
        keywords: ['copilot']),
    KnownService('Cursor', 'AI',
        'https://cursor.com/settings',
        keywords: ['cursor']),
    KnownService('Telegram Premium', 'Софт и облако',
        'https://telegram.org/faq_premium',
        keywords: ['telegram']),
    KnownService('Xbox Game Pass', 'Игры',
        'https://account.microsoft.com/services',
        keywords: ['xbox', 'game pass']),
    KnownService('PlayStation Plus', 'Игры',
        'https://www.playstation.com/support/store/cancel-ps-plus-subscription/',
        keywords: ['playstation', 'psn']),
    KnownService('Steam', 'Игры',
        'https://store.steampowered.com/account/',
        keywords: ['steam']),
    KnownService('Glovo', 'Другое',
        'https://glovoapp.com/ru/ru/help/',
        keywords: ['glovo']),
    KnownService('Wolt+', 'Другое',
        'https://wolt.com/en/help',
        keywords: ['wolt']),
    KnownService('Microsoft 365', 'Софт и облако',
        'https://account.microsoft.com/services',
        keywords: ['microsoft 365', 'office 365', 'microsoft*']),
    KnownService('Adobe', 'Софт и облако',
        'https://account.adobe.com/plans',
        keywords: ['adobe']),
  ];

  static KnownService? find(String name) {
    final n = name.toLowerCase().trim();
    for (final s in all) {
      if (s.name.toLowerCase() == n) return s;
    }
    for (final s in all) {
      if (s.keywords.any((k) => n.contains(k))) return s;
    }
    return null;
  }

  static String? cancelUrlFor(String name) => find(name)?.cancelUrl;

  /// Ищет известный сервис в произвольном тексте (например, SMS банка).
  static KnownService? findInText(String text) {
    final t = text.toLowerCase();
    for (final s in all) {
      if (s.keywords.any((k) => t.contains(k))) return s;
    }
    return null;
  }
}
