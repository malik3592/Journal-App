import 'dart:io';

import 'package:path_provider/path_provider.dart';

class TradeShotStore {
  static const folder = 'trade-shots';

  Future<Directory> _docs() => getApplicationDocumentsDirectory();

  Future<String> import({required String tradeId, required String sourcePath}) async {
    final docs = await _docs();
    final dir = Directory('${docs.path}/$folder/$tradeId');
    await dir.create(recursive: true);
    final lower = sourcePath.toLowerCase();
    final ext = lower.endsWith('.png')
        ? '.png'
        : lower.endsWith('.heic')
            ? '.heic'
            : lower.endsWith('.webp')
                ? '.webp'
                : '.jpg';
    final name = '${DateTime.now().millisecondsSinceEpoch}$ext';
    await File(sourcePath).copy('${dir.path}/$name');
    return '$folder/$tradeId/$name';
  }

  Future<File?> resolve(String stored) async {
    final docs = await _docs();
    final path = stored.startsWith('/') ? stored : '${docs.path}/$stored';
    final file = File(path);
    return await file.exists() ? file : null;
  }

  Future<void> remove(String stored) async {
    final file = await resolve(stored);
    if (file != null) await file.delete();
  }

  Future<void> removeAll(String tradeId) async {
    final dir = Directory('${(await _docs()).path}/$folder/$tradeId');
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}
