import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:journal/core/constants.dart';
import 'package:journal/core/errors.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class LocalBackupInfo {
  const LocalBackupInfo({required this.file, required this.modifiedAt});
  final File file;
  final DateTime modifiedAt;
}

class LocalBackupService {
  static const _export = MethodChannel('journal/file_export');

  Future<Directory> _backupDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/backups');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> save(String json) async {
    final dir = await _backupDir();
    final stamp = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());
    final stamped = File('${dir.path}/journal-journal-backup-$stamp.json');
    final latest = File('${dir.path}/${AppConfig.driveBackupFileName}');
    await stamped.writeAsString(json);
    await latest.writeAsString(json);
    return stamped;
  }

  Future<ShareResult> share(File file, {Rect? sharePositionOrigin}) async {
    return Share.shareXFiles(
      [
        XFile(
          file.path,
          mimeType: 'application/json',
          name: file.uri.pathSegments.last,
        ),
      ],
      subject: 'Journal journal backup',
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  Future<bool> exportVisible(File file, {Rect? sharePositionOrigin}) async {
    try {
      final saved = await _export.invokeMethod<bool>('exportFile', {
        'path': file.path,
        'name': file.uri.pathSegments.last,
      });
      return saved == true;
    } on MissingPluginException {
      final result = await share(
        file,
        sharePositionOrigin: sharePositionOrigin,
      );
      return result.status == ShareResultStatus.success;
    }
  }

  Future<List<LocalBackupInfo>> list() async {
    final dir = await _backupDir();
    try {
      final files =
          dir
              .listSync()
              .whereType<File>()
              .where((f) => f.path.endsWith('.json'))
              .toList()
            ..sort(
              (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
            );
      return [
        for (final file in files)
          LocalBackupInfo(file: file, modifiedAt: file.lastModifiedSync()),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<LocalBackupInfo?> latest() async {
    final dir = await _backupDir();
    final latest = File('${dir.path}/${AppConfig.driveBackupFileName}');
    if (await latest.exists()) {
      return LocalBackupInfo(
        file: latest,
        modifiedAt: latest.lastModifiedSync(),
      );
    }
    final items = await list();
    return items.isEmpty ? null : items.first;
  }

  Future<String> read(File file) async {
    if (!await file.exists()) {
      throw AppException('That backup file is no longer on this phone.');
    }
    return file.readAsString();
  }

  Future<String?> pick() async {
    const jsonGroup = XTypeGroup(
      label: 'JSON',
      extensions: ['json'],
      mimeTypes: ['application/json'],
      uniformTypeIdentifiers: ['public.json', 'public.text'],
    );
    final file = await openFile(acceptedTypeGroups: const [jsonGroup]);
    if (file == null) return null;
    return file.readAsString();
  }
}
