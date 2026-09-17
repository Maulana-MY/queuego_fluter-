import 'package:flutter/material.dart';
// Removed unused import: 'package:provider/provider.dart'
import '../../constants/app_colors.dart';
import '../../models/queue_model.dart';
import '../../models/queue_status.dart';
import '../../services/queue_service.dart';

class AnalyticsHistoryPage extends StatefulWidget {
  const AnalyticsHistoryPage({super.key});

  @override
  State<AnalyticsHistoryPage> createState() => _AnalyticsHistoryPageState();
}

class _AnalyticsHistoryPageState extends State<AnalyticsHistoryPage> {
  final QueueService _queueService = QueueService();
  final TextEditingController _searchController = TextEditingController();

  List<Queue> _queues = [];
  bool _isLoading = false;
  String _searchQuery = '';
  int _selectedCounter = 0;

  @override
  void initState() {
    super.initState();
    _loadQueues();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadQueues() async {
    setState(() => _isLoading = true);
    try {
      final queues = (await _queueService.getQueuesToday()).map((item) => Queue.fromJson(item)).toList();
      if (mounted) {
        setState(() => _queues = queues);
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  List<Queue> get _filteredQueues {
    var filtered = _queues;
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();
      filtered = filtered
          .where((q) =>
              q.customerName.toLowerCase().contains(query) ||
              q.queueNumber.toLowerCase().contains(query))
          .toList();
    }
    if (_selectedCounter != 0) {
      filtered = filtered.where((q) => q.counterId == _selectedCounter).toList();
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final totalCount = _queues.length;
    final completedCount = _queues.where((q) => q.status == QueueStatus.completed).length;
    final skippedCount = _queues.where((q) => q.status == QueueStatus.skipped).length;
    final cancelledCount = _queues.where((q) => q.status == QueueStatus.cancelled).length;

    final successRate = totalCount == 0 ? 0.0 : (completedCount / totalCount * 100).round();

    final counter1Count = _queues.where((q) => q.counterId == 1).length;
    final counter2Count = _queues.where((q) => q.counterId == 2).length;
    final counter3Count = _queues.where((q) => q.counterId == 3).length;

    final counter1Completed = _queues.where((q) => q.counterId == 1 && q.status == QueueStatus.completed).length;
    final counter2Completed = _queues.where((q) => q.counterId == 2 && q.status == QueueStatus.completed).length;
    final counter3Completed = _queues.where((q) => q.counterId == 3 && q.status == QueueStatus.completed).length;

    final counter1Percent = totalCount == 0 ? 0.0 : (counter1Count / totalCount * 100);
    final counter2Percent = totalCount == 0 ? 0.0 : (counter2Count / totalCount * 100);
    final counter3Percent = totalCount == 0 ? 0.0 : (counter3Count / totalCount * 100);

    final counter1CompletedPercent = counter1Count == 0 ? 0.0 : (counter1Completed / counter1Count * 100);
    final counter2CompletedPercent = counter2Count == 0 ? 0.0 : (counter2Completed / counter2Count * 100);
    final counter3CompletedPercent = counter3Count == 0 ? 0.0 : (counter3Completed / counter3Count * 100);

    final filteredQueues = _filteredQueues;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Riwayat & Analytics Antrean'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStatCard(icon: Icons.queue, label: 'TOTAL ANTREAN', value: '$totalCount', color: AppColors.primary),
          const SizedBox(height: 12),
          _buildStatCard(icon: Icons.check_circle, label: 'SELESAI', value: '$completedCount', color: AppColors.green),
          const SizedBox(height: 12),
          _buildStatCard(icon: Icons.skip_next, label: 'DILEWATI', value: '$skippedCount', color: AppColors.red),
          const SizedBox(height: 12),
          _buildStatCard(icon: Icons.percent, label: 'KEBERHASILAN', value: '$successRate%', color: AppColors.orange),
          const SizedBox(height: 24),
          _buildLoketBarChart(counter: 1, count: counter1Count, completed: counter1Completed, percent: counter1Percent, completedPercent: counter1CompletedPercent, totalCount: totalCount),
          const SizedBox(height: 16),
          _buildLoketBarChart(counter: 2, count: counter2Count, completed: counter2Completed, percent: counter2Percent, completedPercent: counter2CompletedPercent, totalCount: totalCount),
          const SizedBox(height: 16),
          _buildLoketBarChart(counter: 3, count: counter3Count, completed: counter3Completed, percent: counter3Percent, completedPercent: counter3CompletedPercent, totalCount: totalCount),
          const SizedBox(height: 24),
          _buildStatusRadar(completedCount, skippedCount, cancelledCount),
          const SizedBox(height: 24),
          _buildFilterSection(),
          const SizedBox(height: 16),
          _buildQueueList(filteredQueues),
        ],
      ),
    );
  }

  Widget _buildStatCard({required IconData icon, required String label, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textGrey)),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoketBarChart({required int counter, required int count, required int completed, required double percent, required double completedPercent, required int totalCount}) {
        final counterName = 'Loket $counter';
    final counterColor = [AppColors.primary, AppColors.purple, AppColors.orange][counter - 1];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 40, height: 40, decoration: BoxDecoration(color: counterColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.storefront, color: counterColor)),
              const SizedBox(width: 12),
              Expanded(child: Text(counterName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark))),
              Text('$count tiket', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: totalCount == 0 ? 0 : percent / 100, minHeight: 12, backgroundColor: Colors.grey.shade200, color: counterColor),
          ),
          const SizedBox(height: 8),
          Row(children: [const Text('Jumlah Tiket: ', style: TextStyle(fontWeight: FontWeight.w600)), Text('$count / $completed')]),
          const SizedBox(height: 6),
          Row(children: [const Text('Selesai: ', style: TextStyle(fontWeight: FontWeight.w600)), Text('$completed / $count')]),
        ],
      ),
    );
  }

  Widget _buildStatusRadar(int completedCount, int skippedCount, int cancelledCount) {
    final totalCount = completedCount + skippedCount + cancelledCount;
    final completedPercent = totalCount == 0 ? 0.0 : (completedCount / totalCount * 100);
    final skippedPercent = totalCount == 0 ? 0.0 : (skippedCount / totalCount * 100);
    final cancelledPercent = totalCount == 0 ? 0.0 : (cancelledCount / totalCount * 100);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Rasio Status Pelayanan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildStatusMiniCard(label: 'Selesai', count: completedCount, percent: completedPercent, color: AppColors.green),
          const SizedBox(height: 8),
          _buildStatusMiniCard(label: 'Dilewati', count: skippedCount, percent: skippedPercent, color: AppColors.red),
          const SizedBox(height: 8),
          _buildStatusMiniCard(label: 'Dibatalkan', count: cancelledCount, percent: cancelledPercent, color: AppColors.orange),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: totalCount == 0 ? 0 : (completedCount + skippedCount) / totalCount, minHeight: 8, backgroundColor: Colors.grey.shade200, color: AppColors.green),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusMiniCard({required String label, required int count, required double percent, required Color color}) {
    return Row(
      children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontWeight: FontWeight.w600)), Text('$count antrean', style: const TextStyle(color: AppColors.textGrey))])),
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text('${percent.toStringAsFixed(1)}%', style: TextStyle(color: color, fontWeight: FontWeight.bold))),
      ],
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(hintText: 'Cari berdasarkan nama pelanggan atau nomor antrean', prefixIcon: const Icon(Icons.search), border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _selectedCounter,
            decoration: const InputDecoration(labelText: 'Filter Loket', border: OutlineInputBorder(), prefixIcon: Icon(Icons.storefront)),
            items: const [DropdownMenuItem(value: 0, child: Text('Semua Loket')), DropdownMenuItem(value: 1, child: Text('Loket 1')), DropdownMenuItem(value: 2, child: Text('Loket 2')), DropdownMenuItem(value: 3, child: Text('Loket 3'))],
            onChanged: (value) => setState(() => _selectedCounter = value!),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: null,
            decoration: const InputDecoration(labelText: 'Filter Status', border: OutlineInputBorder(), prefixIcon: Icon(Icons.filter_list)),
            items: const [DropdownMenuItem(value: null, child: Text('Semua Status')), DropdownMenuItem(value: 'waiting', child: Text('Menunggu')), DropdownMenuItem(value: 'calling', child: Text('Dipanggil')), DropdownMenuItem(value: 'serving', child: Text('Dilayani')), DropdownMenuItem(value: 'completed', child: Text('Selesai')), DropdownMenuItem(value: 'skipped', child: Text('Dilewati')), DropdownMenuItem(value: 'cancelled', child: Text('Dibatalkan'))],
            onChanged: (value) {},
          ),
        ],
      ),
    );
  }

  Widget _buildQueueList(List<Queue> queues) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Daftar Antrean Hari Ini', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (_isLoading) const Center(child: CircularProgressIndicator())
          else if (queues.isEmpty) const Center(child: Text('Tidak ada data antrean'))
          else SingleChildScrollView(child: Column(children: queues.map((q) => _buildQueueRow(q)).toList())),
        ],
      ),
    );
  }

  Widget _buildQueueRow(Queue queue) {
    final statusColor = {
      QueueStatus.waiting: AppColors.orange,
      QueueStatus.calling: AppColors.purple,
      QueueStatus.serving: AppColors.primary,
      QueueStatus.completed: AppColors.green,
      QueueStatus.skipped: AppColors.red,
      QueueStatus.cancelled: AppColors.textGrey,
    }[queue.status];

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      leading: CircleAvatar(backgroundColor: statusColor?.withOpacity(0.15) ?? Colors.transparent, child: Text(queue.queueNumber, style: TextStyle(color: statusColor ?? Colors.black, fontWeight: FontWeight.bold))),
      title: Text(queue.customerName),
      subtitle: Text('Loket ${queue.counterId} - ${queue.status.name}'),
      trailing: Text(queue.queueNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}



