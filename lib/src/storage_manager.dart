import 'package:get_storage/get_storage.dart';
import 'models/request_log_group.dart';

class ZSStorageManager {
  static const _key = "app_logs";
  static final GetStorage _box = GetStorage();
  static bool _initialized = false;

  /// Initialize GetStorage before first use (call once in main)
  static Future<void> init() async {
    if (!_initialized) {
      await GetStorage.init();
      _initialized = true;
    }
  }

  /// Save all log groups to storage
  static Future<void> saveLogGroups(List<ZSRequestLogGroup> groups) async {
    final jsonList = groups.map((g) => g.toJson()).toList();
    await _box.write(_key, jsonList);
  }

  /// Load saved log groups
  static Future<List<ZSRequestLogGroup>> loadLogGroups() async {
    final data = _box.read<List<dynamic>>(_key);
    if (data == null) return [];

    try {
      return data
          .map((json) =>
              ZSRequestLogGroup.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // If migration from old format fails, return empty list
      print("Error loading logs: $e");
      return [];
    }
  }

  /// Clear all stored logs
  static Future<void> clearLogs() async {
    await _box.remove(_key);
  }

  /// Legacy methods for backward compatibility (if needed)
  static Future<void> saveLogs(List<String> logs) async {
    // This is kept for backward compatibility but won't be used
    await _box.write("${_key}_legacy", logs);
  }

  static Future<List<String>> loadLogs() async {
    // This is kept for backward compatibility but won't be used
    final data = _box.read<List<dynamic>>("${_key}_legacy");
    if (data == null) return [];
    return data.cast<String>();
  }
}
