import 'dart:io';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/known_services.dart';
import '../models/subscription.dart';
import 'email_parser.dart';

class SmsMessage {
  SmsMessage(this.address, this.body, this.date);
  final String address;
  final String body;
  final DateTime date;
}

/// БЕТА (только Android). Читает входящие SMS и ищет в них списания за
/// известные сервисы. Данные остаются на устройстве.
class SmsService {
  static const _channel = MethodChannel('appsub/sms');

  static bool get supported => Platform.isAndroid;

  Future<bool> requestPermission() async =>
      (await Permission.sms.request()).isGranted;

  Future<List<SubscriptionCandidate>> scan({int days = 180}) async {
    final raw = await _channel.invokeMethod<List<dynamic>>(
          'readSms',
          {'days': days, 'limit': 1500},
        ) ??
        [];
    final msgs = raw.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return SmsMessage(
        (m['address'] as String?) ?? '',
        (m['body'] as String?) ?? '',
        DateTime.fromMillisecondsSinceEpoch((m['date'] as num).toInt()),
      );
    }).toList();
    return SmsParser.parse(msgs);
  }
}

class SmsParser {
  static final _skip = RegExp(r'возврат|refund|отмен|cancel|код|code|otp',
      caseSensitive: false);

  /// Ищет в SMS списания за известные сервисы и угадывает периодичность
  /// по интервалу между повторами.
  static List<SubscriptionCandidate> parse(List<SmsMessage> msgs) {
    final byService = <String, List<(SmsMessage, double, String)>>{};
    final services = <String, KnownService>{};

    for (final m in msgs) {
      if (_skip.hasMatch(m.body)) continue;
      final s = KnownServices.findInText('${m.address} ${m.body}');
      if (s == null) continue;
      final a = EmailParser.findAmount(m.body);
      if (a == null) continue;
      services[s.name] = s;
      byService.putIfAbsent(s.name, () => []).add((m, a.price, a.currency));
    }

    final out = <SubscriptionCandidate>[];
    for (final e in byService.entries) {
      final list = e.value..sort((a, b) => b.$1.date.compareTo(a.$1.date));
      final latest = list.first;
      out.add(SubscriptionCandidate(
        name: e.key,
        price: latest.$2,
        currency: latest.$3,
        period: _periodFromGaps(list.map((x) => x.$1.date).toList()),
        date: latest.$1.date,
        subject: 'SMS: ${_snippet(latest.$1.body)}',
      ));
    }
    out.sort((a, b) => b.date.compareTo(a.date));
    return out;
  }

  /// Медианный интервал между списаниями → периодичность (по умолчанию месяц).
  static BillingPeriod _periodFromGaps(List<DateTime> datesDesc) {
    if (datesDesc.length < 2) return BillingPeriod.monthly;
    final gaps = <int>[];
    for (var i = 0; i < datesDesc.length - 1; i++) {
      gaps.add(datesDesc[i].difference(datesDesc[i + 1]).inDays);
    }
    gaps.sort();
    final median = gaps[gaps.length ~/ 2];
    if (median >= 5 && median <= 9) return BillingPeriod.weekly;
    if (median >= 80 && median <= 100) return BillingPeriod.quarterly;
    if (median >= 340) return BillingPeriod.yearly;
    return BillingPeriod.monthly;
  }

  static String _snippet(String s) {
    final t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t.length <= 70 ? t : '${t.substring(0, 70)}…';
  }
}
