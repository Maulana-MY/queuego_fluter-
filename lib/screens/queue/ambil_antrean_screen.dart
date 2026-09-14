import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/counter_model.dart';
import '../../models/queue_model.dart';
import 'tiket_antrean_screen.dart';

class AmbilAntreanPage extends StatefulWidget {
  final List<Counter> counters;
  final TextEditingController customerController;
  final int? initialCounterId;
  final void Function(int counterId) onCounterSelected;
  final Queue Function(int counterId, String name) onSubmit;
  final int Function(Queue queue) aheadCounter;
  final int Function(int counterId)? waitingCounter;

  const AmbilAntreanPage({
    super.key,
    required this.counters,
    required this.customerController,
    required this.initialCounterId,
    required this.onCounterSelected,
    required this.onSubmit,
    required this.aheadCounter,
    this.waitingCounter,
  });

  @override
  State<AmbilAntreanPage> createState() => _AmbilAntreanPageState();
}

class _AmbilAntreanPageState extends State<AmbilAntreanPage> {
  int? selectedCounterId;

  @override
  void initState() {
    super.initState();
    selectedCounterId = widget.initialCounterId ??
        (widget.counters.isNotEmpty ? widget.counters.first.id : null);
  }

  void _showMsg(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _submit() {
    if (selectedCounterId == null) {
      _showMsg('Silakan pilih loket terlebih dahulu.');
      return;
    }
    widget.onCounterSelected(selectedCounterId!);
    final queue =
        widget.onSubmit(selectedCounterId!, widget.customerController.text);
    final counter =
        widget.counters.firstWhere((c) => c.id == queue.counterId);
    widget.customerController.clear();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => TiketAntreanPage(
          queue: queue,
          counter: counter,
          aheadCount: widget.aheadCounter(queue),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.textDark,
        title: const Text(
          'Ambil Nomor Antrean',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Header
                Container(
                  width: double.infinity,
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
                        child: const Icon(Icons.confirmation_number_rounded,
                            color: AppColors.primary, size: 24),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pilih Layanan / Loket',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Silakan pilih loket yang ingin Anda tuju',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.textGrey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Counter List / Grid
                const Text(
                  'Daftar Loket Tersedia',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 10),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: widget.counters.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final counter = widget.counters[index];
                    final selected = selectedCounterId == counter.id;
                    final waiting = widget.waitingCounter?.call(counter.id) ?? 0;

                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => setState(() => selectedCounterId = counter.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFFEFF6FF)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected
                                ? AppColors.primary
                                : AppColors.border,
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: selected
                                    ? AppColors.primary
                                    : Colors.transparent,
                                border: Border.all(
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.textFaint,
                                  width: 2,
                                ),
                              ),
                              child: selected
                                  ? const Icon(Icons.check,
                                      size: 16, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    counter.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: selected
                                          ? AppColors.primary
                                          : AppColors.textDark,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$waiting antrean sedang menunggu',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textGrey),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.primary.withOpacity(0.12)
                                    : AppColors.bg,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                selected ? 'Dipilih' : 'Pilih',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.textGrey,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Customer Name
                const Text(
                  'Nama Anda (Opsional)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: widget.customerController,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: 'Masukkan nama Anda',
                    prefixIcon: const Icon(Icons.person_outline),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _submit,
                    icon: const Icon(Icons.confirmation_number_rounded),
                    label: const Text(
                      'AMBIL ANTREAN',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Info footer
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: AppColors.primary, size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Nomor antrean akan otomatis dibuat dan Anda dapat memantau giliran secara real-time.',
                          style: TextStyle(
                              fontSize: 11.5, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
