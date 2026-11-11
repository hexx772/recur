import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import 'email_parser.dart';

/// БЕТА. Читает письма Gmail (только чтение) и ищет списания.
///
/// Требуется настройка OAuth-клиента в Google Cloud Console
/// (см. README.md): Android/iOS client ID и включённый Gmail API.
class GmailService {
  static const _scopes = ['https://www.googleapis.com/auth/gmail.readonly'];
  static const _base = 'https://gmail.googleapis.com/gmail/v1/users/me';

  static bool _initialized = false;

  Future<String> _accessToken() async {
    final gs = GoogleSignIn.instance;
    if (!_initialized) {
      await gs.initialize();
      _initialized = true;
    }
    final account = await gs.authenticate(scopeHint: _scopes);
    final authz = await account.authorizationClient.authorizeScopes(_scopes);
    return authz.accessToken;
  }

  Future<void> signOut() => GoogleSignIn.instance.signOut();

  /// Ищет письма о списаниях и возвращает кандидатов в подписки.
  Future<List<SubscriptionCandidate>> scan({int maxMessages = 50}) async {
    final token = await _accessToken();
    final headers = {'Authorization': 'Bearer $token'};

    final list = await http.get(
      Uri.parse('$_base/messages').replace(queryParameters: {
        'q': EmailParser.gmailQuery,
        'maxResults': '$maxMessages',
      }),
      headers: headers,
    );
    _check(list);
    final ids = ((jsonDecode(list.body)['messages'] as List?) ?? [])
        .map((m) => m['id'] as String)
        .toList();

    final found = <SubscriptionCandidate>[];
    for (final id in ids) {
      final r = await http.get(
        Uri.parse('$_base/messages/$id')
            .replace(queryParameters: {'format': 'full'}),
        headers: headers,
      );
      if (r.statusCode != 200) continue;
      final msg = jsonDecode(r.body) as Map<String, dynamic>;
      final payload = msg['payload'] as Map<String, dynamic>? ?? {};
      final hs = (payload['headers'] as List? ?? []);
      String h(String n) => hs
          .cast<Map<String, dynamic>>()
          .firstWhere((e) => (e['name'] as String).toLowerCase() == n,
              orElse: () => {'value': ''})['value'] as String;

      final date = DateTime.fromMillisecondsSinceEpoch(
          int.tryParse('${msg['internalDate']}') ?? 0);
      final c = EmailParser.parse(
        from: h('from'),
        subject: h('subject'),
        body: _bodyText(payload),
        date: date,
      );
      if (c != null) found.add(c);
    }
    return EmailParser.dedupe(found);
  }

  void _check(http.Response r) {
    if (r.statusCode != 200) {
      throw Exception('Gmail API: ${r.statusCode} ${r.reasonPhrase}');
    }
  }

  String _bodyText(Map<String, dynamic> part) {
    final sb = StringBuffer();
    final data = (part['body'] as Map<String, dynamic>?)?['data'] as String?;
    final mime = part['mimeType'] as String? ?? '';
    if (data != null && mime.startsWith('text/')) {
      try {
        sb.write(utf8.decode(base64Url.decode(base64Url.normalize(data))));
      } catch (_) {}
    }
    for (final p in (part['parts'] as List? ?? [])) {
      sb.write(_bodyText(p as Map<String, dynamic>));
    }
    return sb.toString();
  }
}
