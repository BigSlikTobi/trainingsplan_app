import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ExchangeDirectoryService {
  static const _channel = MethodChannel('codex_fitness/exchange');

  Future<Directory> resolveExchangeDirectory() async {
    if (Platform.isIOS) {
      try {
        final path = await _channel.invokeMethod<String>(
          'iCloudExchangeDirectory',
        );
        if (path != null && path.trim().isNotEmpty) {
          final dir = Directory(path);
          if (!dir.existsSync()) await dir.create(recursive: true);
          return dir;
        }
      } on PlatformException {
        // Fall through to local app documents. This keeps simulator/dev usable
        // when iCloud is disabled or entitlements are not active yet.
      } on MissingPluginException {
        // Widget tests and non-iOS platforms do not expose the native channel.
      }
    }

    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'CodexFitnessExchange'));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }
}
