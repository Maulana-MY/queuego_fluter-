import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Singleton Service untuk mengontrol Panggilan Suara (Text-To-Speech)
/// Mengimplementasikan Aturan Bisnis Audio:
/// 1. Form User / Customer View: Suara AKTIF & BERBUNYI saat dipanggil.
/// 2. Panel Operator: 100% SILENT.
/// 3. Monitor & Riwayat: SILENT (Cegah double sound).
/// 4. Global Singleton Controller agar navigasi tab/halaman tidak mereload audio / double sound.
/// 5. Mechanism flag `queuego_announced_[TICKET_ID]` via SharedPreferences agar 1 event panggil hanya bersuara 1 kali.
class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;

  TtsService._internal() {
    _initTts();
  }

  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;

  Future<void> _initTts() async {
    if (_isInitialized) return;
    try {
      await _tts.awaitSpeakCompletion(true);
      await _tts.setLanguage('id-ID');
      await _tts.setSpeechRate(0.45);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing TTS: $e');
    }
  }

  /// Memanggil nomor antrean untuk tampilan User
  /// [queueId]: ID unik antrean
  /// [queueNumber]: Format misal "A-001"
  /// [counterName]: Nama loket misal "Loket 1"
  /// [isRecall]: Jika true (panggil ulang), abaikan flag penyimpanan dan suarakan
  Future<void> speakQueueCall({
    required dynamic queueId,
    required String queueNumber,
    required String counterName,
    bool isRecall = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final storageKey = 'queuego_announced_$queueId';

    // Jika ini Aksi Panggil Ulang (isRecall == true), HAPUS kunci sebelumnya!
    if (isRecall) {
      await prefs.remove(storageKey);
    }

    // Jika sudah pernah dibunyikan dan bukan panggil ulang, lewati
    if (!isRecall && (prefs.getBool(storageKey) ?? false)) {
      return;
    }

    try {
      await _initTts();
      await _tts.stop();

      // Format pembacaan jelas: A-001 -> "Nomor antrean A, 0 0 1, silakan menuju ke Loket 1"
      final parts = queueNumber.split('-');
      final prefix = parts[0];
      final numberPart = parts.length > 1 ? parts[1] : '';

      final prefixSpaced = prefix.split('').join(' ');
      final numberSpaced = numberPart.split('').join(' ');

      final speechText =
          'Nomor antrean $prefixSpaced $numberSpaced, silakan menuju $counterName';

      await _tts.speak(speechText);

      // Tandai sudah dibunyikan di SharedPreferences
      await prefs.setBool(storageKey, true);
    } catch (e) {
      debugPrint('TTS speak error: $e');
    }
  }

  /// Berhenti memutar suara
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  /// Bersihkan history pengumuman jika diperlukan
  Future<void> resetAnnouncedHistory(dynamic queueId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('queuego_announced_$queueId');
    } catch (_) {}
  }
}

