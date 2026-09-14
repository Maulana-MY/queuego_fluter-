import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../constants/app_colors.dart';
import '../../models/counter_model.dart';
import '../../models/queue_model.dart';
import '../../models/queue_status.dart';
import '../../models/user_store.dart';
import '../../services/api_service.dart';
import '../../utils/date_formatter.dart';
import '../auth/login_screen.dart';
import '../queue/ambil_antrean_screen.dart';
import '../queue/tiket_antrean_screen.dart';

class HomeShell extends StatefulWidget {
  final UserModel currentUser;

  const HomeShell({super.key, required this.currentUser});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentPage = 0;

  final TextEditingController _customerController = TextEditingController();
  final FlutterTts _tts = FlutterTts();
  final ApiService _apiService = ApiService();

  final List<Counter> counters = [
    Counter(id: 1, name: 'Loket 1'),
    Counter(id: 2, name: 'Loket 2'),
    Counter(id: 3, name: 'Loket 3'),
  ];

  final List<Queue> queues = [];

  int? selectedCounterId;
  int nextQueueId = 1;
  Queue? myQueue;
  String historyFilter = 'Semua';
  bool _isLoadingFromApi = false;
  String? _apiError;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    selectedCounterId = counters.isNotEmpty ? counters.first.id : null;
    _initTts();
    _loadFromApi();
    // Auto-refresh setiap 5 detik agar antrean dari user lain langsung muncul di operator
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _silentRefresh();
    });
  }

  Future<void> _loadFromApi() async {
    setState(() {
      _isLoadingFromApi = true;
      _apiError = null;
    });

    try {
      // Fetch counters from API
      final apiCounters = await _apiService.getCounters();
      if (apiCounters.isNotEmpty) {
        setState(() {
          counters.clear();
          counters.addAll(apiCounters);
          selectedCounterId = counters.first.id;
        });
      }

      // Fetch queues from API
      final today = DateTime.now();
      final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final apiQueues = await _apiService.getQueues(date: dateStr);

      setState(() {
        queues.clear();
        queues.addAll(apiQueues);
        nextQueueId = queues.isNotEmpty ? queues.map((q) => q.id).reduce((a, b) => a > b ? a : b) + 1 : 1;
      });
    } catch (e) {
      setState(() {
        _apiError = 'Gagal terhubung ke server: ${e.toString()}';
      });
      // Fallback: use sample data if API fails
      _initSampleData();
    } finally {
      if (mounted) setState(() => _isLoadingFromApi = false);
    }
  }

  Future<void> _refreshData() async {
    await _loadFromApi();
  }

  /// Refresh data dari API tanpa menampilkan loading indicator
  /// Dipanggil secara otomatis oleh timer untuk sinkronisasi real-time
  Future<void> _silentRefresh() async {
    try {
      final apiQueues = await _apiService.getQueuesToday();
      if (mounted) {
        setState(() {
          queues.clear();
          queues.addAll(apiQueues);
          if (queues.isNotEmpty) {
            nextQueueId = queues.map((q) => q.id).reduce((a, b) => a > b ? a : b) + 1;
          }
        });
      }
    } catch (_) {
      // Gagal refresh diam-diam, jangan tampilkan error
    }
  }

  void _initSampleData() {
    // Add a few initial demo waiting queues so operator and monitor have immediate live data
    final now = DateTime.now();
    queues.addAll([
      Queue(
        id: nextQueueId++,
        counterId: 1,
        queueNumber: 'L1-001',
        customerName: 'Budi Santoso',
        status: QueueStatus.waiting,
        createdAt: now.subtract(const Duration(minutes: 15)),
      ),
      Queue(
        id: nextQueueId++,
        counterId: 1,
        queueNumber: 'L1-002',
        customerName: 'Siti Aminah',
        status: QueueStatus.waiting,
        createdAt: now.subtract(const Duration(minutes: 10)),
      ),
      Queue(
        id: nextQueueId++,
        counterId: 2,
        queueNumber: 'L2-001',
        customerName: 'Rudi Hartono',
        status: QueueStatus.waiting,
        createdAt: now.subtract(const Duration(minutes: 8)),
      ),
      Queue(
        id: nextQueueId++,
        counterId: 3,
        queueNumber: 'L3-001',
        customerName: 'Dewi Lestari',
        status: QueueStatus.waiting,
        createdAt: now.subtract(const Duration(minutes: 5)),
      ),
    ]);
  }

  Future<void> _initTts() async {
    try {
      await _tts.awaitSpeakCompletion(true);
      await _tts.setLanguage('id-ID');
      await _tts.setSpeechRate(0.45);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      try {
        await _tts.getEngines;
      } catch (_) {}
    } catch (e) {
      debugPrint('TTS init error: $e');
    }
  }

  Future<void> speakQueue(Queue queue) async {
    final counter = counters.firstWhere((c) => c.id == queue.counterId);
    try {
      await _tts.stop();
      await _tts.setLanguage('id-ID');
      await _tts.setSpeechRate(0.45);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);

      // Example: L1-001 -> "Nomor antrean, L, satu, kosong, kosong, satu. Silakan menuju ke Loket 1"
      final parts = queue.queueNumber.split('-');
      final prefix = parts[0];
      final numberPart = parts.length > 1 ? parts[1] : '';

      final prefixSpaced = prefix.split('').join(', ');
      final numberSpaced = numberPart.split('').join(', ');

      final text =
          'Nomor antrean, $prefixSpaced, $numberSpaced. Silakan menuju ke ${counter.name}.';
      await _tts.speak(text);
    } catch (e) {
      debugPrint('TTS speak error: $e');
      if (mounted) {
        showMessage('Suara panggilan tidak dapat diputar.');
      }
    }
  }

  Future<void> testVoice() async {
    try {
      await _tts.stop();
      await _tts.setLanguage('id-ID');
      await _tts.setSpeechRate(0.45);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      await _tts.speak('Tes suara QueueGo. Sistem panggilan suara aktif.');
    } catch (e) {
      debugPrint('TTS test error: $e');
      showMessage('TTS belum tersedia di perangkat ini.');
    }
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _customerController.dispose();
    _tts.stop();
    super.dispose();
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  Queue takeQueue(int counterId, String name) {
    final customerName = name.trim().isEmpty ? 'Pelanggan' : name.trim();
    final today = DateTime.now();
    final todayQueues = queues.where((q) =>
        q.counterId == counterId &&
        q.createdAt.year == today.year &&
        q.createdAt.month == today.month &&
        q.createdAt.day == today.day);
    final nextNumber = todayQueues.length + 1;
    final queueNumber = 'L$counterId-${nextNumber.toString().padLeft(3, '0')}';

    final queue = Queue(
      id: nextQueueId++,
      counterId: counterId,
      queueNumber: queueNumber,
      customerName: customerName,
      status: QueueStatus.waiting,
      createdAt: DateTime.now(),
    );

    setState(() {
      queues.add(queue);
      myQueue = queue;
    });

    // Sinkronisasi buat antrean ke Go Backend API
    _apiService.createQueue(counterId: counterId, customerName: customerName).then((apiQueue) {
      if (mounted) {
        setState(() {
          final idx = queues.indexWhere((q) => q.id == queue.id);
          if (idx != -1) {
            queues[idx] = apiQueue;
          }
          if (myQueue?.id == queue.id) {
            myQueue = apiQueue;
          }
        });
      }
    }).catchError((_) {});

    return queue;
  }


  int queuesAhead(Queue queue) {
    return queues
        .where((item) =>
            item.counterId == queue.counterId &&
            item.status == QueueStatus.waiting &&
            item.id < queue.id &&
            _isToday(item.createdAt))
        .length;
  }

  Queue? currentQueue(int counterId) {
    final active = queues
        .where((q) =>
            q.counterId == counterId &&
            (q.status == QueueStatus.calling ||
                q.status == QueueStatus.serving) &&
            _isToday(q.createdAt))
        .toList();
    if (active.isEmpty) return null;
    active.sort((a, b) => b.id.compareTo(a.id));
    return active.first;
  }

  int waitingCount(int counterId) {
    return queues
        .where((q) =>
            q.counterId == counterId &&
            q.status == QueueStatus.waiting &&
            _isToday(q.createdAt))
        .length;
  }

  List<Queue> waitingListForCounter(int counterId) {
    final waiting = queues
        .where((q) =>
            q.counterId == counterId &&
            q.status == QueueStatus.waiting &&
            _isToday(q.createdAt))
        .toList();
    waiting.sort((a, b) => a.id.compareTo(b.id));
    return waiting;
  }

  Future<void> callNext(int counterId) async {
    try {
      final called = await _apiService.callNextQueue(counterId);
      setState(() {
        final idx = queues.indexWhere((q) => q.id == called.id);
        if (idx != -1) {
          queues[idx] = called;
        } else {
          queues.add(called);
        }
      });
      await speakQueue(called);
      showMessage('Memanggil nomor ${called.queueNumber}');
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      // Fallback local jika offline atau server tidak merespon
      final active = queues.where((q) =>
          q.counterId == counterId &&
          (q.status == QueueStatus.calling || q.status == QueueStatus.serving) &&
          _isToday(q.createdAt));
      for (final q in active) {
        q.status = QueueStatus.completed;
        q.completedAt = DateTime.now();
      }

      final waiting = waitingListForCounter(counterId);

      if (waiting.isEmpty) {
        setState(() {});
        showMessage(msg.isNotEmpty ? msg : 'Tidak ada antrean dalam daftar tunggu untuk loket ini.');
        return;
      }

      final next = waiting.first;

      setState(() {
        next.status = QueueStatus.calling;
        next.calledAt = DateTime.now();
      });

      await speakQueue(next);
      showMessage('Memanggil nomor ${next.queueNumber}');
    }
  }

  Future<void> callSpecificQueue(Queue queue) async {
    try {
      final called = await _apiService.recallQueue(queue.id);
      setState(() {
        final idx = queues.indexWhere((q) => q.id == queue.id);
        if (idx != -1) queues[idx] = called;
      });
      await speakQueue(called);
      showMessage('Memanggil nomor ${called.queueNumber}');
    } catch (_) {
      final active = queues.where((q) =>
          q.counterId == queue.counterId &&
          (q.status == QueueStatus.calling || q.status == QueueStatus.serving) &&
          _isToday(q.createdAt));
      for (final q in active) {
        q.status = QueueStatus.completed;
        q.completedAt = DateTime.now();
      }

      setState(() {
        queue.status = QueueStatus.calling;
        queue.calledAt = DateTime.now();
      });

      await speakQueue(queue);
      showMessage('Memanggil nomor ${queue.queueNumber}');
    }
  }

  Future<void> recall(Queue queue) async {
    try {
      final called = await _apiService.recallQueue(queue.id);
      setState(() {
        final idx = queues.indexWhere((q) => q.id == queue.id);
        if (idx != -1) queues[idx] = called;
      });
      await speakQueue(called);
      showMessage('Panggilan ulang nomor ${called.queueNumber}');
    } catch (_) {
      setState(() {
        queue.status = QueueStatus.calling;
        queue.calledAt = DateTime.now();
      });
      await speakQueue(queue);
      showMessage('Panggilan ulang nomor ${queue.queueNumber}');
    }
  }

  void startServing(Queue queue) {
    _apiService.serveQueue(queue.id).then((updated) {
      if (mounted) {
        setState(() {
          final idx = queues.indexWhere((q) => q.id == queue.id);
          if (idx != -1) queues[idx] = updated;
        });
      }
    }).catchError((_) {});
    setState(() => queue.status = QueueStatus.serving);
    showMessage('${queue.queueNumber} mulai dilayani');
  }

  void complete(Queue queue) {
    _apiService.completeQueue(queue.id).then((updated) {
      if (mounted) {
        setState(() {
          final idx = queues.indexWhere((q) => q.id == queue.id);
          if (idx != -1) queues[idx] = updated;
        });
      }
    }).catchError((_) {});
    setState(() {
      queue.status = QueueStatus.completed;
      queue.completedAt = DateTime.now();
    });
    showMessage('${queue.queueNumber} selesai dilayani');
  }

  void skip(Queue queue) {
    _apiService.skipQueue(queue.id).then((updated) {
      if (mounted) {
        setState(() {
          final idx = queues.indexWhere((q) => q.id == queue.id);
          if (idx != -1) queues[idx] = updated;
        });
      }
    }).catchError((_) {});
    setState(() {
      queue.status = QueueStatus.skipped;
      queue.completedAt = DateTime.now();
    });
    showMessage('${queue.queueNumber} telah dilewati');
  }


  Queue? get latestCalling {
    final calling = queues
        .where((q) => q.status == QueueStatus.calling && _isToday(q.createdAt))
        .toList();
    if (calling.isEmpty) return null;
    calling.sort((a, b) {
      final at = a.calledAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bt = b.calledAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bt.compareTo(at);
    });
    return calling.first;
  }

  List<Queue> get allWaitingList {
    final result = queues
        .where((q) => q.status == QueueStatus.waiting && _isToday(q.createdAt))
        .toList();
    result.sort((a, b) => a.id.compareTo(b.id));
    return result;
  }

  List<Queue> get todayActivity {
    final result = queues.where((q) => _isToday(q.createdAt)).toList();
    result.sort((a, b) => b.id.compareTo(a.id));
    return result.take(8).toList();
  }

  List<Queue> get history {
    final result = queues
        .where((q) =>
            q.status == QueueStatus.completed ||
            q.status == QueueStatus.skipped ||
            q.status == QueueStatus.cancelled)
        .toList();
    result.sort((a, b) {
      final at = a.completedAt ?? a.createdAt;
      final bt = b.completedAt ?? b.createdAt;
      return bt.compareTo(at);
    });
    if (historyFilter == 'Semua') return result;
    final filterMap = {
      'Selesai': QueueStatus.completed,
      'Dilewati': QueueStatus.skipped,
      'Dibatalkan': QueueStatus.cancelled,
    };
    return result.where((q) => q.status == filterMap[historyFilter]).toList();
  }

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openAmbilAntrean() {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => AmbilAntreanPage(
          counters: counters,
          customerController: _customerController,
          initialCounterId: selectedCounterId,
          onCounterSelected: (id) => selectedCounterId = id,
          onSubmit: (counterId, name) => takeQueue(counterId, name),
          aheadCounter: queuesAhead,
          waitingCounter: waitingCount,
        ),
      ),
    )
        .then((_) {
      if (mounted) setState(() {});
    });
  }

  void _openTiket(Queue queue) {
    final counter = counters.firstWhere((c) => c.id == queue.counterId);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TiketAntreanPage(
          queue: queue,
          counter: counter,
          aheadCount: queuesAhead(queue),
        ),
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar dari Aplikasi?'),
        content: const Text('Anda akan keluar dari sesi saat ini.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOperator = widget.currentUser.isOperator;

    // Separate Navigation destinations and pages based on role
    final List<Widget> pages = isOperator
        ? [
            _buildOperatorTab(),
            _buildMonitorTab(),
            _buildRiwayatTab(),
          ]
        : [
            _buildUserHomeTab(),
            _buildMonitorTab(),
            _buildRiwayatTab(),
          ];

    final List<NavigationDestination> destinations = isOperator
        ? const [
            NavigationDestination(
              icon: Icon(Icons.support_agent_outlined),
              selectedIcon: Icon(Icons.support_agent),
              label: 'Operator',
            ),
            NavigationDestination(
              icon: Icon(Icons.tv_outlined),
              selectedIcon: Icon(Icons.tv),
              label: 'Monitor',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history),
              label: 'Riwayat',
            ),
          ]
        : const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Beranda',
            ),
            NavigationDestination(
              icon: Icon(Icons.tv_outlined),
              selectedIcon: Icon(Icons.tv),
              label: 'Monitor',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history),
              label: 'Riwayat',
            ),
          ];

    final safeIndex = _currentPage >= pages.length ? 0 : _currentPage;

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: safeIndex,
          children: pages,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: (i) => setState(() => _currentPage = i),
        destinations: destinations,
      ),
    );
  }

  // ===========================================================================
  // 1. USER HOME TAB (Khusus Pelanggan / Tamu)
  // ===========================================================================
  Widget _buildUserHomeTab() {
    final activeQueue = myQueue;
    final hasActiveTicket = activeQueue != null &&
        (activeQueue.status == QueueStatus.waiting ||
            activeQueue.status == QueueStatus.calling ||
            activeQueue.status == QueueStatus.serving);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Header
          _buildUserHeader(),
          const SizedBox(height: 20),

          // Active Ticket Card (if exists)
          if (hasActiveTicket) ...[
            _buildUserActiveTicketCard(activeQueue),
            const SizedBox(height: 18),
          ],

          // Hero Button "Ambil Antrean"
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: _openAmbilAntrean,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.32),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.confirmation_number_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ambil Nomor Antrean',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Pilih loket layanan dan dapatkan nomor antrean Anda sekarang',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      color: Colors.white, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Status Loket Ringkas (Live Overview)
          const Text(
            'Status Loket Saat Ini',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 10),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: counters.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final counter = counters[index];
              final current = currentQueue(counter.id);
              final waiting = waitingCount(counter.id);
              final isBusy = current != null;

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isBusy
                            ? AppColors.greenBg
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.storefront_rounded,
                        color: isBusy ? AppColors.green : AppColors.textGrey,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            counter.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isBusy
                                ? 'Sedang melayani ${current.queueNumber}'
                                : 'Loket Siap Melayani',
                            style: TextStyle(
                              fontSize: 12,
                              color: isBusy
                                  ? AppColors.green
                                  : AppColors.textGrey,
                              fontWeight: isBusy
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$waiting Menunggu',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildUserHeader() {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: const Icon(Icons.person, color: AppColors.primary, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Halo, ${widget.currentUser.name}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                widget.currentUser.username == 'tamu'
                    ? 'Pengunjung Tamu'
                    : 'Pelanggan QueueGo',
                style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Keluar',
          onPressed: _confirmLogout,
          icon: const Icon(Icons.logout_rounded, color: AppColors.textGrey),
        ),
      ],
    );
  }

  Widget _buildUserActiveTicketCard(Queue queue) {
    final counter = counters.firstWhere((c) => c.id == queue.counterId);
    final ahead = queuesAhead(queue);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: queue.status.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(queue.status.icon,
                        size: 14, color: queue.status.color),
                    const SizedBox(width: 5),
                    Text(
                      queue.status.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: queue.status.color,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                counter.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'NOMOR ANTREAN ANDA',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppColors.textGrey,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                    Text(
                      queue.queueNumber,
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Column(
                  children: [
                    Text(
                      '$ahead',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.orange,
                      ),
                    ),
                    const Text(
                      'Di Depan Anda',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openTiket(queue),
              icon: const Icon(Icons.qr_code_rounded, size: 18),
              label: const Text('Buka Tiket Digital Lengkap'),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 2. OPERATOR TAB (Tampilan Sesuai Laravel resources/views/operator/index.blade.php)
  // ===========================================================================
  Widget _buildOperatorTab() {
    final selectedCounter = selectedCounterId == null
        ? (counters.isNotEmpty ? counters.first : null)
        : counters.firstWhere((c) => c.id == selectedCounterId,
            orElse: () => counters.first);

    final activeQueue =
        selectedCounter == null ? null : currentQueue(selectedCounter.id);
    final waitingList = selectedCounter == null
        ? <Queue>[]
        : waitingListForCounter(selectedCounter.id);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Panel Operasional (matching Laravel header)
          _buildOperatorHeader(selectedCounter, waitingList.length),
          const SizedBox(height: 16),

          // Pilihan Loket Chips (Loket Selector)
          const Text(
            'Pilih Loket Tugas',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: counters.map((counter) {
                final isSelected = selectedCounter?.id == counter.id;
                final isBusy = currentQueue(counter.id) != null;
                final waiting = waitingCount(counter.id);

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => selectedCounterId = counter.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.border,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isBusy
                                  ? (isSelected
                                      ? Colors.greenAccent
                                      : AppColors.green)
                                  : (isSelected
                                      ? Colors.white54
                                      : AppColors.textFaint),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            counter.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textDark,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white.withOpacity(0.2)
                                  : const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$waiting',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 18),

          // Action: Test Voice & Manual Take Ticket
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: testVoice,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.purple,
                    side: const BorderSide(color: AppColors.purple),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.volume_up_rounded, size: 18),
                  label: const Text('Tes Suara',
                      style: TextStyle(fontSize: 12.5)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openAmbilAntrean,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('Ambilkan Tiket',
                      style: TextStyle(fontSize: 12.5)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Active Queue Card (Matching Laravel Main Focus Box)
          if (selectedCounter != null) ...[
            _buildOperatorActiveCard(selectedCounter, activeQueue),
            const SizedBox(height: 16),

            // Big "PANGGIL SELANJUTNYA" Action Button (Matching Laravel)
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => callNext(selectedCounter.id),
                icon: const Icon(Icons.volume_up_rounded, size: 24),
                label: const Text(
                  'PANGGIL SELANJUTNYA',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),

            // Waiting List Section (Matching Laravel Waiting List for this Loket)
            _buildOperatorWaitingList(selectedCounter, waitingList),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildOperatorHeader(Counter? counter, int waitingCount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.support_agent_rounded,
                color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Panel Operasional',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.green,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Aktif: ${counter?.name ?? "-"}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFFEDD5)),
            ),
            child: Text(
              '$waitingCount Menunggu',
              style: const TextStyle(
                color: AppColors.orange,
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Keluar',
            onPressed: _confirmLogout,
            icon: const Icon(Icons.logout_rounded, color: AppColors.textGrey),
          ),
        ],
      ),
    );
  }

  Widget _buildOperatorActiveCard(Counter counter, Queue? queue) {
    if (queue == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.people_outline_rounded,
                  size: 30, color: AppColors.textFaint),
            ),
            const SizedBox(height: 12),
            const Text(
              'Belum Ada Antrean Aktif',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tekan tombol "Panggil Selanjutnya" untuk memanggil antrean di ${counter.name}.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textGrey, fontSize: 12),
            ),
          ],
        ),
      );
    }

    final isCalling = queue.status == QueueStatus.calling;
    final isServing = queue.status == QueueStatus.serving;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCalling ? AppColors.orange : AppColors.green,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isCalling ? AppColors.orange : AppColors.green)
                .withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Status Pill Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: (isCalling ? AppColors.orange : AppColors.green)
                  .withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isCalling
                      ? Icons.volume_up_rounded
                      : Icons.room_service_rounded,
                  size: 14,
                  color: isCalling ? AppColors.orange : AppColors.green,
                ),
                const SizedBox(width: 6),
                Text(
                  isCalling ? 'SEDANG DIPANGGIL' : 'SEDANG DILAYANI',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: isCalling ? AppColors.orange : AppColors.green,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Large Queue Number (Matching Laravel)
          FittedBox(
            child: Text(
              queue.queueNumber,
              style: const TextStyle(
                fontSize: 54,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 4),

          // Customer Name & Loket
          Text(
            queue.customerName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            'Loket: ${counter.name} • ${formatTime(queue.calledAt ?? queue.createdAt)}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textGrey,
            ),
          ),
          const SizedBox(height: 18),

          // Operator Control Action Buttons (Matching Laravel: Panggil Ulang, Mulai Melayani / Selesai, Lewati)
          Row(
            children: [
              // Panggil Ulang (Recall)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => recall(queue),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.orange,
                    side: const BorderSide(color: AppColors.orange),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.replay_rounded, size: 17),
                  label: const Text(
                    'Panggil Ulang',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Mulai Melayani / Selesai
              Expanded(
                child: FilledButton.icon(
                  onPressed: isCalling
                      ? () => startServing(queue)
                      : () => complete(queue),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.green,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: Icon(
                    isCalling ? Icons.play_arrow_rounded : Icons.check_circle_rounded,
                    size: 17,
                  ),
                  label: Text(
                    isCalling ? 'Mulai Layani' : 'Selesai',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Lewati (Skip)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => skip(queue),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.red,
                    side: const BorderSide(color: AppColors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.skip_next_rounded, size: 17),
                  label: const Text(
                    'Lewati',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOperatorWaitingList(Counter counter, List<Queue> waitingList) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Daftar Tunggu (${counter.name})',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              Text(
                '${waitingList.length} Antrean',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textGrey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (waitingList.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              alignment: Alignment.center,
              child: const Text(
                'Tidak ada antrean yang sedang menunggu di loket ini.',
                style: TextStyle(
                  color: AppColors.textFaint,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: waitingList.length,
              separatorBuilder: (_, __) => const Divider(height: 16),
              itemBuilder: (context, index) {
                final item = waitingList[index];
                return Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEFF6FF),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.queueNumber,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: AppColors.textDark,
                            ),
                          ),
                          Text(
                            '${item.customerName} • ${formatTime(item.createdAt)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => callSpecificQueue(item),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.volume_up_rounded,
                                size: 14, color: AppColors.primary),
                            SizedBox(width: 4),
                            Text(
                              'Panggil',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 3. MONITOR TAB (Layar Monitor Antrean Real-Time)
  // ===========================================================================
  Widget _buildMonitorTab() {
    final calling = latestCalling;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Monitor Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Monitor Antrean',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Tampilan real-time nomor panggilan dan status loket',
                    style: TextStyle(fontSize: 12, color: AppColors.textGrey),
                  ),
                ],
              ),
              IconButton(
                tooltip: 'Tes Suara',
                onPressed: testVoice,
                icon: const Icon(Icons.volume_up_outlined,
                    color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Calling Now Main Focus (Matching Laravel Monitor Hero)
          if (calling != null) ...[
            _buildMonitorCallingNow(calling),
            const SizedBox(height: 20),
          ],

          // Grid Status Semua Loket
          const Text(
            'Status Loket Pelayanan',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 10),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: counters.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final counter = counters[index];
              final current = currentQueue(counter.id);
              final waiting = waitingCount(counter.id);
              final isBusy = current != null;

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isBusy
                        ? (current.status == QueueStatus.calling
                            ? AppColors.orange
                            : AppColors.green)
                        : AppColors.border,
                    width: isBusy ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isBusy
                            ? (current.status == QueueStatus.calling
                                ? AppColors.orangeBg
                                : AppColors.greenBg)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          'L${counter.id}',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: isBusy
                                ? (current.status == QueueStatus.calling
                                    ? AppColors.orange
                                    : AppColors.green)
                                : AppColors.textGrey,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            counter.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isBusy
                                ? '${current.status.label}: ${current.customerName}'
                                : 'Loket Tersedia',
                            style: TextStyle(
                              fontSize: 12,
                              color: isBusy
                                  ? (current.status == QueueStatus.calling
                                      ? AppColors.orange
                                      : AppColors.green)
                                  : AppColors.textGrey,
                              fontWeight: isBusy
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          current?.queueNumber ?? '-',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: isBusy
                                ? AppColors.primary
                                : AppColors.textFaint,
                          ),
                        ),
                        Text(
                          '$waiting menunggu',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),

          // Daftar Tunggu Global (Matching Laravel Monitor Waiting List)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Daftar Antrean Menunggu',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${allWaitingList.length} Total',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (allWaitingList.isEmpty)
            _emptyContainer(
              Icons.done_all_rounded,
              'Semua Antrean Telah Selesai',
              'Tidak ada antrean dalam daftar tunggu saat ini.',
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: allWaitingList.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = allWaitingList[index];
                final counter =
                    counters.firstWhere((c) => c.id == item.counterId);

                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.queueNumber,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: AppColors.textDark,
                              ),
                            ),
                            Text(
                              item.customerName,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          counter.name,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildMonitorCallingNow(Queue queue) {
    final counter = counters.firstWhere((c) => c.id == queue.counterId);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1D4ED8), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.volume_up_rounded, size: 14, color: Colors.white),
                SizedBox(width: 6),
                Text(
                  'SEDANG DIPANGGIL',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FittedBox(
            child: Text(
              queue.queueNumber,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 60,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
          ),
          Text(
            queue.customerName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Silakan Menuju Ke: ',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                Text(
                  counter.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 4. RIWAYAT TAB (History Antrean)
  // ===========================================================================
  Widget _buildRiwayatTab() {
    final data = history;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Riwayat Antrean',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Daftar antrean yang telah selesai diproses atau dilewati',
            style: TextStyle(fontSize: 12, color: AppColors.textGrey),
          ),
          const SizedBox(height: 16),

          // Filter ChoiceChips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['Semua', 'Selesai', 'Dilewati', 'Dibatalkan'].map((f) {
                final isSelected = historyFilter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(f),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                    onSelected: (_) => setState(() => historyFilter = f),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          if (data.isEmpty)
            _emptyContainer(
              Icons.history_rounded,
              'Belum Ada Riwayat Antrean',
              'Antrean yang selesai atau dilewati akan muncul di sini.',
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: data.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = data[index];
                final counter =
                    counters.firstWhere((c) => c.id == item.counterId);
                final color = item.status.color;

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 72,
                        child: Text(
                          item.queueNumber,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.customerName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${counter.name} • ${formatTime(item.createdAt)} - ${formatTime(item.completedAt ?? item.createdAt)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          item.status.label,
                          style: TextStyle(
                            color: color,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _emptyContainer(IconData icon, String title, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 34),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 42, color: AppColors.textFaint),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textGrey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
