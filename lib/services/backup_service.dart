import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/subscription_store.dart';
import '../l10n/tr.dart';

/// Резервная копия и экспорт: JSON для восстановления, CSV для таблиц.
class BackupService {
  static String _stamp() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${n.year}${two(n.month)}${two(n.day)}';
  }

  static Future<void> _shareFile(
      String name, String content, String mime, String subject) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    // BOM нужен, чтобы Excel правильно открыл кириллицу в CSV.
    await file.writeAsString(name.endsWith('.csv') ? '﻿$content' : content,
        encoding: utf8);
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: mime)],
      subject: subject,
    ));
  }

  static Future<void> exportJson(SubscriptionStore store) => _shareFile(
        'recur-backup-${_stamp()}.json',
        store.exportJson(),
        'application/json',
        tr('Резервная копия подписок'),
      );

  static Future<void> exportCsv(SubscriptionStore store) => _shareFile(
        'recur-${_stamp()}.csv',
        store.exportCsv(),
        'text/csv',
        tr('Подписки (CSV)'),
      );

  /// Выбор файла копии и импорт. Возвращает число записей или null,
  /// если пользователь отменил выбор.
  static Future<int?> importJson(SubscriptionStore store) async {
    final file = await FilePicker.pickFile();
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return store.importJson(utf8.decode(bytes));
  }
}
