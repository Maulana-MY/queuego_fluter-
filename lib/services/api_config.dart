class ApiConfig {
  // Custom Base URL override yang bisa diubah saat runtime
  static String? _overrideBaseUrl;

  static void setCustomBaseUrl(String url) {
    if (url.trim().isNotEmpty) {
      _overrideBaseUrl = url.trim();
    } else {
      _overrideBaseUrl = null;
    }
  }

  // Production Vercel Backend Go Base URL
  static String get baseUrl => _overrideBaseUrl ?? 'https://queuego-backend.vercel.app';


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

