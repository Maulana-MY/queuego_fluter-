import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class QueueService {
  // 1. Ambil Semua Data Loket
  Future<List<dynamic>> getCounters() async {
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}${ApiConfig.counters}'));
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json['data'] ?? [];
    }
    throw Exception('Gagal mengambil data loket');
  }

  // 2. Ambil Semua Antrean Hari Ini
  Future<List<dynamic>> getQueuesToday() async {
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}${ApiConfig.queuesToday}'));
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json['data'] ?? [];
    }
    throw Exception('Gagal mengambil data antrean');
  }

  // 3. FUNGSI OPERATOR: Panggil Antrean Selanjutnya (Call Next)
  Future<dynamic> callNext(int counterId) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.callQueue(counterId)}'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['data'];
    }
    throw Exception('Tidak ada antrean yang dapat dipanggil');
  }

  // 4. FUNGSI OPERATOR: Panggil Ulang (Recall)
  Future<void> recallQueue(int queueId) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.recallQueue(queueId)}'),
    );
    if (response.statusCode != 200) {
      throw Exception('Gagal memanggil ulang antrean');
    }
  }

  // 5. FUNGSI OPERATOR: Mulai Layani (Serve)
  Future<void> serveQueue(int queueId) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.serveQueue(queueId)}'),
    );
    if (response.statusCode != 200) {
      throw Exception('Gagal mengubah status menjadi melayani');
    }
  }

  // 6. FUNGSI OPERATOR: Selesai Melayani (Complete)
  Future<void> completeQueue(int queueId) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.completeQueue(queueId)}'),
    );
    if (response.statusCode != 200) {
      throw Exception('Gagal menyelesaikan antrean');
    }
  }

  // 7. FUNGSI OPERATOR: Lewati Antrean (Skip)
  Future<void> skipQueue(int queueId) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.skipQueue(queueId)}'),
    );
    if (response.statusCode != 200) {
      throw Exception('Gagal melewati antrean');
    }
  }

  // User-facing: Register antrean baru
  Future<dynamic> registerQueue(int counterId, String customerName) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/queues');
    try {
      final response = await http.post(
        url,
        body: jsonEncode({
          "counter_id": counterId,
          "customer_name": customerName
        }),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return data['data'];
        }
      }
      return null;
    } catch (e) {
      print('Error registering queue: $e');
      return null;
    }
  }

  // User-facing: Cek status antrean
  Future<dynamic> getQueueStatus(int queueId) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/queues/$queueId');
    try {
      final response = await http.get(
        url,
        headers: {
          "Accept": "application/json",
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return data['data'];
        }
      }
      return null;
    } catch (e) {
      print('Error getting queue status: $e');
      return null;
    }
  }
}