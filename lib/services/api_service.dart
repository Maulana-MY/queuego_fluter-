import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/counter_model.dart';
import '../models/queue_model.dart';
import '../models/user_store.dart';
import 'api_config.dart';

/// Exception khusus untuk kesalahan komunikasi dengan API
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Service untuk menangani semua request HTTP ke Go Backend API
class ApiService {
  final http.Client client;

  ApiService({http.Client? client}) : client = client ?? http.Client();

  // Headers default untuk request JSON
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  // Helper internal untuk GET request
  Future<Map<String, dynamic>> _get(String endpoint) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');

    try {
      final response = await client.get(url, headers: _headers).timeout(
            const Duration(seconds: ApiConfig.timeout),
          );

      return _handleResponse(response);
    } on SocketException {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi internet Anda.');
    } on TimeoutException {
      throw ApiException('Waktu koneksi ke server habis (timeout).');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Terjadi kesalahan: ${e.toString()}');
    }
  }

  // Helper internal untuk POST request
  Future<Map<String, dynamic>> _post(String endpoint, {Map<String, dynamic>? body}) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');

    try {
      final response = await client
          .post(
            url,
            headers: _headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: ApiConfig.timeout));

      return _handleResponse(response);
    } on SocketException {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi internet Anda.');
    } on TimeoutException {
      throw ApiException('Waktu koneksi ke server habis (timeout).');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Terjadi kesalahan: ${e.toString()}');
    }
  }

  // Parsing & validasi response JSON dari server
  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode == 404) {
      final path = response.request?.url.path ?? '';
      throw ApiException(
        'Endpoint $path tidak ditemukan di server (404 Not Found). Pastikan backend versi terbaru sudah aktif di server.',
        statusCode: 404,
      );
    }

    if (response.body.isEmpty) {
      throw ApiException('Server memberikan respon kosong.', statusCode: response.statusCode);
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (e) {
      if (response.statusCode >= 400) {
        throw ApiException(
          'Server mengembalikan kesalahan (${response.statusCode}): ${response.body.trim()}',
          statusCode: response.statusCode,
        );
      }
      throw ApiException('Gagal memproses data respon dari server: ${response.body}', statusCode: response.statusCode);
    }

    if (decoded is! Map<String, dynamic>) {
      throw ApiException('Format data tidak dikenali.', statusCode: response.statusCode);
    }

    final isSuccess = (response.statusCode >= 200 && response.statusCode < 300) &&
        (decoded['success'] == true || !decoded.containsKey('success'));

    if (isSuccess) {
      return decoded;
    } else {
      final message = decoded['message'] ?? decoded['error'] ?? 'Terjadi kesalahan pada server (${response.statusCode})';
      throw ApiException(message.toString(), statusCode: response.statusCode);
    }
  }

  // ============ 1. GET COUNTERS ============

  /// GET /api/counters
  /// Mendapatkan daftar loket yang tersedia
  Future<List<Counter>> getCounters() async {
    final response = await _get(ApiConfig.counters);

    if (response['data'] != null && response['data'] is List) {
      final List<dynamic> list = response['data'];
      return list.map((json) => Counter.fromJson(json as Map<String, dynamic>)).toList();
    }
    return [];
  }

  // ============ 2. GET QUEUES TODAY ============

  /// GET /api/queues/today
  /// Mendapatkan daftar seluruh antrean hari ini
  Future<List<Queue>> getQueuesToday() async {
    final response = await _get(ApiConfig.queuesToday);

    if (response['data'] != null && response['data'] is List) {
      final List<dynamic> list = response['data'];
      return list.map((json) => Queue.fromJson(json as Map<String, dynamic>)).toList();
    }
    return [];
  }

  /// Alias getQueues (kompatibel dengan parameter tanggal jika diperlukan)
  Future<List<Queue>> getQueues({String? date}) async {
    return getQueuesToday();
  }

  // ============ 3. CREATE QUEUE ============

  /// POST /api/queues
  /// Mendaftarkan antrean baru untuk pelanggan di counter tertentu
  Future<Queue> createQueue({
    required int counterId,
    required String customerName,
  }) async {
    final body = {
      'counter_id': counterId,
      'customer_name': customerName.trim().isEmpty ? 'Pelanggan' : customerName.trim(),
    };

    final response = await _post(ApiConfig.queues, body: body);

    if (response['data'] != null) {
      return Queue.fromJson(response['data'] as Map<String, dynamic>);
    } else {
      throw ApiException('Gagal membuat antrean: Respon tidak memuat data antrean');
    }
  }

  // ============ 4. CALL NEXT QUEUE ============

  /// POST /api/queues/:counterId/call
  /// Memanggil antrean berikutnya untuk counterId tertentu
  Future<Queue> callNextQueue(int counterId) async {
    final response = await _post(ApiConfig.callQueue(counterId));

    if (response['data'] != null) {
      return Queue.fromJson(response['data'] as Map<String, dynamic>);
    } else {
      throw ApiException(response['message'] ?? 'Gagal memanggil antrean');
    }
  }

  /// Alias callQueue untuk pemanggilan counter
  Future<Queue> callQueue(int counterId) async {
    return callNextQueue(counterId);
  }

  // ============ 5. RECALL QUEUE ============

  /// POST /api/queues/:queueId/recall
  /// Memanggil ulang antrean dengan queueId tertentu
  Future<Queue> recallQueue(int queueId) async {
    final response = await _post(ApiConfig.recallQueue(queueId));

    if (response['data'] != null) {
      return Queue.fromJson(response['data'] as Map<String, dynamic>);
    } else {
      throw ApiException(response['message'] ?? 'Gagal memanggil ulang antrean');
    }
  }

  // ============ 6. SERVE QUEUE ============

  /// POST /api/queues/:queueId/serve
  /// Memulai melayani antrean dengan queueId tertentu
  Future<Queue> serveQueue(int queueId) async {
    final response = await _post(ApiConfig.serveQueue(queueId));

    if (response['data'] != null) {
      return Queue.fromJson(response['data'] as Map<String, dynamic>);
    } else {
      throw ApiException(response['message'] ?? 'Gagal memulai melayani antrean');
    }
  }

  // ============ 7. COMPLETE QUEUE ============

  /// POST /api/queues/:queueId/complete
  /// Menyelesaikan antrean dengan queueId tertentu
  Future<Queue> completeQueue(int queueId) async {
    final response = await _post(ApiConfig.completeQueue(queueId));

    if (response['data'] != null) {
      return Queue.fromJson(response['data'] as Map<String, dynamic>);
    } else {
      throw ApiException(response['message'] ?? 'Gagal menyelesaikan antrean');
    }
  }

  // ============ 8. SKIP QUEUE ============

  /// POST /api/queues/:queueId/skip
  /// Melewati antrean dengan queueId tertentu
  Future<Queue> skipQueue(int queueId) async {
    final response = await _post(ApiConfig.skipQueue(queueId));

    if (response['data'] != null) {
      return Queue.fromJson(response['data'] as Map<String, dynamic>);
    } else {
      throw ApiException(response['message'] ?? 'Gagal melewati antrean');
    }
  }

  // ============ 9. AUTH: REGISTER ============

  /// POST /api/register
  /// Mendaftarkan akun baru langsung ke database MySQL
  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
    String role = 'user',
  }) async {
    final body = {
      'name': name.trim(),
      'email': email.trim().toLowerCase(),
      'password': password,
      'role': role,
    };

    final response = await _post(ApiConfig.register, body: body);

    if (response['data'] != null && response['data'] is Map<String, dynamic>) {
      final user = UserModel.fromJson(response['data'] as Map<String, dynamic>);
      UserStore.setCurrentUser(user);
      return user;
    } else {
      throw ApiException(response['message'] ?? 'Pendaftaran gagal');
    }
  }

  // ============ 10. AUTH: LOGIN ============

  /// POST /api/login
  /// Masuk dengan email/username dan kata sandi dari database MySQL
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final body = {
      'email': email.trim(),
      'password': password,
    };

    final response = await _post(ApiConfig.login, body: body);

    if (response['data'] != null && response['data'] is Map<String, dynamic>) {
      final user = UserModel.fromJson(response['data'] as Map<String, dynamic>);
      UserStore.setCurrentUser(user);
      return user;
    } else {
      throw ApiException(response['message'] ?? 'Email atau kata sandi salah');
    }
  }

  /// Menutup client HTTP saat tidak digunakan lagi
  void dispose() {
    client.close();
  }
}