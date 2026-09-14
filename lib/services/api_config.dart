/// Konfigurasi API untuk QueueGo Backend (Go API)
/// Base URL: http://139.190.96.203:8095
class ApiConfig {
  // Pilihan Base URL:
  // - Android Emulator (Backend Go di laptop): 'http://10.0.2.2:8095'
  // - HP Fisik via WiFi (Backend Go di laptop): 'http://172.16.253.199:8095'
  // - Windows / Chrome Web: 'http://localhost:8095'
  // - VPS Online: 'http://139.190.96.203:8095'
  static const String baseUrl = 'http://172.16.253.199:8095';

  // Timeout dalam detik
  static const int timeout = 30;

  // Endpoints (sesuai dengan backend Go)
  static const String register = '/api/register';
  static const String login = '/api/login';
  static const String counters = '/api/counters';
  static const String queuesToday = '/api/queues/today';
  static const String queues = '/api/queues';

  // Helper endpoints
  /// POST /api/queues/:counterId/call (Memanggil antrean berikutnya untuk counter ini)
  static String callQueue(int counterId) => '$queues/$counterId/call';

  /// POST /api/queues/:queueId/recall (Memanggil ulang antrean)
  static String recallQueue(int queueId) => '$queues/$queueId/recall';

  /// POST /api/queues/:queueId/serve (Memulai melayani antrean)
  static String serveQueue(int queueId) => '$queues/$queueId/serve';

  /// POST /api/queues/:queueId/complete (Menyelesaikan antrean)
  static String completeQueue(int queueId) => '$queues/$queueId/complete';

  /// POST /api/queues/:queueId/skip (Melewati antrean)
  static String skipQueue(int queueId) => '$queues/$queueId/skip';
}

