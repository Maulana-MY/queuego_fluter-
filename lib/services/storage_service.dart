import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/queue_model.dart';

/// Service untuk menyimpan state lokal seperti tiket antrean aktif & preferensi pengguna
class StorageService {
  static const String _keyActiveQueue = 'active_queue_data';
  static const String _keyUserIp = 'backend_user_ip';
  static const String _keyUserHistoryIds = 'user_history_queue_ids';

  /// Menyimpan ID antrean ke riwayat pengguna lokal (per user)
  static Future<void> addUserHistoryQueueId(int queueId, {String? username}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = username != null && username.isNotEmpty
        ? 'user_history_queue_ids_$username'
        : _keyUserHistoryIds;
    List<String> ids = prefs.getStringList(key) ?? [];
    if (!ids.contains(queueId.toString())) {
      ids.add(queueId.toString());
      await prefs.setStringList(key, ids);
    }
  }

  /// Mengambil daftar ID antrean riwayat pengguna lokal (per user)
  static Future<List<int>> getUserHistoryQueueIds({String? username}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = username != null && username.isNotEmpty
        ? 'user_history_queue_ids_$username'
        : _keyUserHistoryIds;
    List<String> ids = prefs.getStringList(key) ?? [];
    return ids.map((e) => int.tryParse(e) ?? 0).where((e) => e > 0).toList();
  }

  /// Menyimpan data tiket antrean aktif
  static Future<bool> saveActiveQueue(Queue queue) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(queue.toJson());
    return await prefs.setString(_keyActiveQueue, jsonStr);
  }

  /// Mengambil data tiket antrean aktif yang tersimpan
  static Future<Queue?> getActiveQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyActiveQueue);
    if (jsonStr == null || jsonStr.isEmpty) return null;

    try {
      final Map<String, dynamic> map = jsonDecode(jsonStr);
      return Queue.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Menghapus tiket antrean aktif (misal ketika antrean selesai / dibatalkan)
  static Future<bool> clearActiveQueue() async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.remove(_keyActiveQueue);
  }

  /// Menyimpan alamat IP kustom untuk backend (opsional)
  static Future<bool> saveCustomIp(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.setString(_keyUserIp, ip.trim());
  }

  /// Mengambil alamat IP kustom untuk backend
  static Future<String?> getCustomIp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserIp);
  }
}
