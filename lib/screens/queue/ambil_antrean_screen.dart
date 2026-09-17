import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/app_colors.dart';
import '../../models/counter_model.dart';
import '../../models/queue_model.dart';
import '../../services/storage_service.dart';
import 'tiket_antrean_screen.dart';

class AmbilAntreanPage extends StatefulWidget {
  final List<Counter> counters;
  final TextEditingController customerController;
  final int? initialCounterId;
  final void Function(int counterId) onCounterSelected;
  final Queue Function(int counterId, String name) onSubmit;
  final int Function(Queue queue) aheadCounter;
  final int Function(int counterId)? waitingCounter;
  final bool hasActiveTicket;
  final Queue? activeQueue;

  const AmbilAntreanPage({
    super.key,
    required this.counters,
    required this.customerController,
    required this.initialCounterId,
    required this.onCounterSelected,
    required this.onSubmit,
    required this.aheadCounter,
    this.waitingCounter,
    this.hasActiveTicket = false,
    this.activeQueue,
  });

  @override
  State<AmbilAntreanPage> createState() => _AmbilAntreanPageState();
}

class _AmbilAntreanPageState extends State<AmbilAntreanPage> {
  int? selectedCounterId;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    selectedCounterId = widget.initialCounterId ??
        (widget.counters.isNotEmpty ? widget.counters.first.id : null);

    if (widget.hasActiveTicket && widget.activeQueue != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final counter = widget.counters.firstWhere(
          (c) => c.id == widget.activeQueue!.counterId,
          orElse: () => Counter(
            id: widget.activeQueue!.counterId,
            name: 'Loket ${widget.activeQueue!.counterId}',
          ),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => TiketAntreanPage(
              queue: widget.activeQueue!,
              counter: counter,
              aheadCount: widget.aheadCounter(widget.activeQueue!),
            ),
          ),
        );
      });
    }
  }

  void _showMsg(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? AppColors.red : AppColors.green,
      ),
    );
  }

  void _submit() {
    if (widget.hasActiveTicket) {
      _showMsg('Anda masih memiliki tiket antrean aktif. Form dikunci.');
      return;
    }

    if (selectedCounterId == null) {
      _showMsg('Silakan pilih loket terlebih dahulu.');
      return;
    }

    final nameText = widget.customerController.text.trim();
    if (nameText.isNotEmpty && nameText.length < 2) {
      setState(() {
        _nameError = 'Nama minimal 2 karakter (hanya huruf, spasi, titik, strip).';
      });
      _showMsg(_nameError!);
      return;
    }

    setState(() => _nameError = null);
    widget.onCounterSelected(selectedCounterId!);
    final queue =
        widget.onSubmit(selectedCounterId!, widget.customerController.text);
    StorageService.saveActiveQueue(queue);
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

                if (widget.hasActiveTicket) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: AppColors.red),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Anda masih memiliki tiket antrean aktif. Form dikunci hingga antrean selesai/dibatalkan.',
                            style: TextStyle(fontSize: 12, color: AppColors.red, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Customer Name
                const Text(
                  'Nama Pelanggan (Opsional)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Hanya huruf, spasi, titik (.), dan strip (-) yang diizinkan.',
                  style: TextStyle(fontSize: 11, color: AppColors.textGrey),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: widget.customerController,
                  enabled: !widget.hasActiveTicket,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s.\-]')),
                  ],
                  onChanged: (val) {
                    if (val.trim().isNotEmpty && val.trim().length < 2) {
                      setState(() => _nameError = 'Nama minimal 2 karakter.');
                    } else {
                      setState(() => _nameError = null);
                    }
                  },
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: 'Masukkan nama Anda (misal: Budi Santoso)',
                    prefixIcon: const Icon(Icons.person_outline),
                    errorText: _nameError,
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
                      backgroundColor: widget.hasActiveTicket ? AppColors.textFaint : AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: widget.hasActiveTicket ? null : _submit,
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
