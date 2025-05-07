import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class JsonStorage {
  static const _fileName = 'proxmox_config.json';

  static Future<File> _configFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File(p.join(directory.path, _fileName));
  }

  static Future<List<Map<String, dynamic>>> loadConfigs() async {
    final file = await _configFile();
    if (!await file.exists()) return [];
    final content = await file.readAsString();
    try {
      final decoded = jsonDecode(content);
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      } else if (decoded is Map) {
        return [decoded.cast<String, dynamic>()];
      }
    } catch (_) {}
    return [];
  }

  static Future<void> saveConfig(Map<String, dynamic> config) async {
    final file = await _configFile();
    final configs = await loadConfigs();
    final exists = configs.any((c) =>
        c['host'] == config['host'] &&
        c['port'] == config['port'] &&
        c['username'] == config['username'] &&
        c['keyPath'] == config['keyPath']);
    if (!exists) {
      configs.add(config);
      await file.writeAsString(jsonEncode(configs));
    }
  }
}
