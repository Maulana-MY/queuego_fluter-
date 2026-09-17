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
import '../../services/storage_service.dart';
import '../../widgets/queue_status_stepper.dart';
import '../../services/tts_service.dart';
import '../../screens/operator/operator_panel_page.dart';

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
  final DateTime now = DateTime.now();

  int? selectedCounterId;
  int nextQueueId = 1;
  Queue? myQueue;
  String historyFilter = 'Semua';
  Timer? _autoRefreshTimer;
  List<int> _myHistoryIds = [];

  @override
  void initState() {
    super.initState();
    selectedCounterId = counters.isNotEmpty ? counters.first.id : null;
    _initTts();
    _loadUserHistoryIds();
    _loadSavedActiveQueue();
    _loadFromApi();
    // Auto-refresh setiap 5 detik agar antrean dari user lain langsung muncul di operator
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _silentRefresh();
    });
  }

  Future<void> _loadUserHistoryIds() async {
    final ids = await StorageService.getUserHistoryQueueIds(
      username: widget.currentUser.username,
    );
    if (mounted) {
      setState(() {
        _myHistoryIds = ids;
      });
    }
  }

  Future<void> _loadSavedActiveQueue() async {
    final saved = await StorageService.getActiveQueue();
    if (mounted) {
      setState(() {
        if (saved != null &&
            (saved.status == QueueStatus.waiting ||
                saved.status == QueueStatus.calling ||
                saved.status == QueueStatus.serving)) {
          myQueue = saved;
        } else {
          myQueue = null;
          if (saved != null) {
            StorageService.clearActiveQueue();
          }
        }
      });
    }
  }

  Future<void> _loadFromApi() async {
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
    } catch (_) {
      // Fallback: use sample data if API fails
      _initSampleData();
    }
  }

  Future<void> _refreshData() async {
    await _loadFromApi();
  }

  /// Refresh data dari API tanpa menampilkan loading indicator
  /// Dipanggil secara otomatis oleh timer untuk sinkronisasi real-time
  Future<void> _silentRefresh() async {
    try {
      final savedActive = await StorageService.getActiveQueue();
      if (savedActive == null) {
        if (myQueue != null && mounted) {
          setState(() {
            myQueue = null;
          });
        }
      }

      final apiQueues = await _apiService.getQueuesToday();
      if (mounted) {
        setState(() {
          queues.clear();
          queues.addAll(apiQueues);
          if (queues.isNotEmpty) {
            nextQueueId = queues.map((q) => q.id).reduce((a, b) => a > b ? a : b) + 1;
          }
          if (myQueue != null) {
            final oldStatus = myQueue!.status;
            final oldCalledAt = myQueue!.calledAt;
            final latest = apiQueues.firstWhere(
              (q) => q.id == myQueue!.id,
              orElse: () => myQueue!,
            );
            if (latest.status == QueueStatus.cancelled ||
                latest.status == QueueStatus.skipped ||
                latest.status == QueueStatus.completed) {
              myQueue = null;
              StorageService.clearActiveQueue();
            } else {
              final bool isRecall = latest.status == QueueStatus.calling &&
                  oldCalledAt != null &&
                  latest.calledAt != null &&
                  latest.calledAt!.isAfter(oldCalledAt);

              final bool isFirstCall =
                  oldStatus != QueueStatus.calling && latest.status == QueueStatus.calling;

              myQueue = latest;

              if (isFirstCall || isRecall) {
                final counter = counters.firstWhere(
                  (c) => c.id == latest.counterId,
                  orElse: () => Counter(id: latest.counterId, name: 'Loket ${latest.counterId}', isActive: true),
                );
                TtsService().speakQueueCall(
                  queueId: latest.id,
                  queueNumber: latest.queueNumber,
                  counterName: counter.name,
                  isRecall: isRecall,
                );
              }
            }
          }
        });
      }
    } catch (_) {
      // Gagal refresh diam-diam, jangan tampilkan error
    }
  }

  void _initSampleData() {
    // Add a few initial demo waiting queues so operator and monitor have immediate live data

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
    StorageService.saveActiveQueue(queue);
    StorageService.addUserHistoryQueueId(queue.id, username: widget.currentUser.username);
    _loadUserHistoryIds();

    // Sinkronisasi buat antrean ke Go Backend API
    _apiService.createQueue(counterId: counterId, customerName: customerName).then((apiQueue) {
      if (mounted) {
        StorageService.addUserHistoryQueueId(apiQueue.id, username: widget.currentUser.username);
        _loadUserHistoryIds();
        setState(() {
          final idx = queues.indexWhere((q) => q.id == queue.id);
          if (idx != -1) {
            queues[idx] = apiQueue;
          }
          if (myQueue?.id == queue.id) {
            myQueue = apiQueue;
          }
        });
        StorageService.saveActiveQueue(apiQueue);
      }
    }).catchError((_) {});

    return queue;
  }


  int queuesAhead(Queue queue) {
    final int activeCounterId = int.parse(queue.counterId.toString());
    return queues
        .where((item) {
          final int itemCounterId = int.parse(item.counterId.toString());
          return itemCounterId == activeCounterId &&
              item.status == QueueStatus.waiting &&
              item.id < queue.id;
        })
        .length;
  }

  Queue? currentQueue(dynamic counterId) {
    if (counterId == null) return null;
    final int activeCounterId = int.parse(counterId.toString());
    final active = queues
        .where((q) {
          final int qCounterId = int.parse(q.counterId.toString());
          return qCounterId == activeCounterId &&
              (q.status == QueueStatus.calling ||
                  q.status == QueueStatus.serving);
        })
        .toList();
    if (active.isEmpty) return null;
    active.sort((a, b) => b.id.compareTo(a.id));
    return active.first;
  }

  int waitingCount(dynamic counterId) {
    if (counterId == null) return 0;
    final int activeCounterId = int.parse(counterId.toString());
    return queues
        .where((q) {
          final int qCounterId = int.parse(q.counterId.toString());
          return qCounterId == activeCounterId &&
              q.status == QueueStatus.waiting;
        })
        .length;
  }

  List<Queue> waitingListForCounter(dynamic counterId) {
    if (counterId == null) return [];
    final int activeCounterId = int.parse(counterId.toString());
    final waiting = queues
        .where((q) {
          final int qCounterId = int.parse(q.counterId.toString());
          return qCounterId == activeCounterId &&
              q.status == QueueStatus.waiting;
        })
        .toList();
    waiting.sort((a, b) => a.id.compareTo(b.id));
    return waiting;
  }

  // --- Operator methods (callNext, recall, startServing, complete, skip) ---
  // REMOVED: These are now handled exclusively by the React Operator Web App.

  Queue? get latestCalling {
    final calling = queues
        .where((q) => q.status == QueueStatus.calling)
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
        .where((q) => q.status == QueueStatus.waiting)
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
    final bool isOperator = widget.currentUser.isOperator;

    if (isOperator) {
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

    // Khusus Pelanggan / User Biasa: HANYA antrean milik user ini sendiri
    final curName = widget.currentUser.name.trim().toLowerCase();
    final curUsername = widget.currentUser.username.trim().toLowerCase();

    final result = queues.where((q) {
      final bool isMyId = _myHistoryIds.contains(q.id);
      final bool isMyName = (curName.isNotEmpty && curName != 'pengguna' && q.customerName.trim().toLowerCase() == curName) ||
                            (curUsername.isNotEmpty && curUsername != 'tamu' && q.customerName.trim().toLowerCase() == curUsername);
      final bool isMyActive = myQueue != null && q.id == myQueue!.id;

      return isMyId || isMyName || isMyActive;
    }).toList();

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

  bool get _hasActiveTicket {
    if (myQueue == null) return false;
    final s = myQueue!.status;
    return s == QueueStatus.waiting ||
        s == QueueStatus.calling ||
        s == QueueStatus.serving;
  }

  void _openAmbilAntrean() {
    if (_hasActiveTicket) {
      _openTiket(myQueue!);
      showMessage(
          'Anda masih memiliki antrean aktif (${myQueue!.queueNumber}). Tidak dapat mengambil antrean baru.');
      return;
    }
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
          hasActiveTicket: _hasActiveTicket,
          activeQueue: myQueue,
        ),
      ),
    )
        .then((_) {
      if (mounted) setState(() {});
    });
  }

  void _openTiket(Queue queue) {
    final counter = counters.firstWhere((c) => c.id == queue.counterId);
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => TiketAntreanPage(
          queue: queue,
          counter: counter,
          aheadCount: queuesAhead(queue),
        ),
      ),
    )
        .then((_) async {
      await _loadSavedActiveQueue();
      if (mounted) setState(() {});
    });
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
    // Check if user is operator
    final bool isOperator = widget.currentUser.isOperator;

    if (isOperator) {
      // Operator pages - using new dedicated pages
      final List<Widget> pages = [
        OperatorPanelPage(),
        _buildMonitorTab(),
        _buildRiwayatTab(),
      ];

      final List<NavigationDestination> destinations = const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: 'Panel Operator',
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

    // Regular user pages
    final List<Widget> pages = [
      _buildUserHomeTab(),
      _buildMonitorTab(),
      _buildRiwayatTab(),
    ];

    final List<NavigationDestination> destinations = const [
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

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
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
            // ... (rest omitted, will close with paren and bracket)

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
          QueueStatusStepper(status: queue.status),
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
  // OPERATOR TAB - REMOVED
  // All operator UI widgets (_buildOperatorTab, _buildOperatorHeader,
  // _buildOperatorActiveCard, _buildOperatorWaitingList) have been moved
  // to the React Operator Web App (queuegoreact).
  // ===========================================================================


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
              const Expanded(
                child: Column(
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
    final bool isOperator = widget.currentUser.isOperator;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isOperator ? 'Riwayat Antrean Seluruh Loket' : 'Riwayat Antrean Saya',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            isOperator
                ? 'Daftar antrean seluruh loket yang telah selesai diproses atau dilewati'
                : 'Daftar riwayat antrean milik ${widget.currentUser.name}',
            style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
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
              isOperator ? 'Belum Ada Riwayat Antrean' : 'Belum Ada Riwayat Antrean Saya',
              isOperator
                  ? 'Antrean yang selesai atau dilewati akan muncul di sini.'
                  : 'Nomor antrean yang Anda ambil akan muncul di riwayat ini.',
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: data.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = data[index];
                final counter = counters.firstWhere(
                  (c) => c.id == item.counterId,
                  orElse: () => Counter(id: item.counterId, name: 'Loket ${item.counterId}'),
                );
                final color = item.status.color;

                return InkWell(
                  onTap: () => _openTiket(item),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
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
                                '${counter.name} • ${formatTime(item.createdAt)}',
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

