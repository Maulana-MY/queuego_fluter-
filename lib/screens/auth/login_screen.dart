import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/user_store.dart';
import '../../services/api_service.dart';
import '../home/home_shell.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final ApiService _apiService = ApiService();
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  final _opCodeController = TextEditingController();
  bool _obscure = true;
  bool _obscureOpCode = true;
  bool _loading = false;
  bool _isOperatorMode = false;

  @override
  void dispose() {
    _userController.dispose();
    _passController.dispose();
    _opCodeController.dispose();
    _apiService.dispose();
    super.dispose();
  }

  void _showMsg(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _login() async {
    final identifier = _userController.text.trim();
    final password = _passController.text.trim();
    final opCode = _opCodeController.text.trim();

    if (identifier.isEmpty || password.isEmpty) {
      _showMsg('Masukkan email/nama pengguna dan kata sandi.');
      return;
    }

    if (_isOperatorMode) {
      if (opCode.isEmpty) {
        _showMsg('Kode Akses Operator wajib diisi untuk masuk!');
        return;
      }
      if (opCode.trim() != 'BETA12') {
        _showMsg('Kode Akses Operator tidak valid! Hubungi Administrator.');
        return;
      }
    }

    setState(() => _loading = true);

    try {
      // 1. Coba login ke database MySQL melalui Backend Go
      final user = await _apiService.login(
        email: identifier,
        password: password,
      );

      if (!mounted) return;

      // Jika mode operator tapi user bukan operator, tolak
      if (_isOperatorMode && !user.isOperator) {
        setState(() => _loading = false);
        _showMsg('Akun ini bukan akun Operator. Silakan daftar sebagai Operator terlebih dahulu.');
        return;
      }

      // Jika akun adalah akun Operator, WAJIB memasukkan kode operator yang valid
      if (user.isOperator && opCode.trim() != 'BETA12') {
        setState(() => _loading = false);
        _showMsg('Akun ini adalah akun Operator. Silakan aktifkan switch Operator dan masukkan Kode Akses Operator.');
        return;
      }

      setState(() => _loading = false);

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomeShell(currentUser: user)),
      );
      return;
    } catch (e) {
      // 2. Fallback: Coba akun demo / lokal jika server offline atau akun demo bawaan
      final localUser = UserStore.login(identifier, password);
      if (localUser != null) {
        if (_isOperatorMode && !localUser.isOperator) {
          if (!mounted) return;
          setState(() => _loading = false);
          _showMsg('Akun ini bukan akun Operator.');
          return;
        }

        // Jika akun lokal adalah akun Operator, WAJIB memasukkan kode operator
        if (localUser.isOperator && opCode.trim() != 'BETA12') {
          if (!mounted) return;
          setState(() => _loading = false);
          _showMsg('Akun ini adalah akun Operator. Silakan aktifkan switch Operator dan masukkan Kode Akses Operator.');
          return;
        }

        if (!mounted) return;
        setState(() => _loading = false);

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => HomeShell(currentUser: localUser)),
        );
        return;
      }

      if (!mounted) return;
      setState(() => _loading = false);

      if (e is ApiException) {
        _showMsg(e.message);
      } else {
        _showMsg('Email / Nama pengguna atau kata sandi salah.');
      }
    }
  }

  void _loginAsGuest() {
    final guest = UserStore.createGuest();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => HomeShell(currentUser: guest)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 10),
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(Icons.confirmation_number_rounded,
                          color: AppColors.primary, size: 32),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Selamat Datang',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Masuk untuk melanjutkan ke QueueGo',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textGrey, fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  const Text('Nama Pengguna',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _userController,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      hintText: 'Masukkan nama pengguna',
                      prefixIcon: const Icon(Icons.person_outline),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Kata Sandi',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _passController,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _login(),
                    decoration: InputDecoration(
                      hintText: 'Masukkan kata sandi',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Toggle Operator Mode
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Masuk sebagai Operator",
                          style: TextStyle(color: AppColors.textGrey)),
                      Switch(
                        value: _isOperatorMode,
                        onChanged: (val) {
                          setState(() {
                            _isOperatorMode = val;
                            if (!val) _opCodeController.clear();
                          });
                        },
                        activeColor: AppColors.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Kode Verifikasi Operator (hanya tampil jika mode operator)
                  AnimatedCrossFade(
                    firstChild: const SizedBox.shrink(),
                    secondChild: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: TextField(
                        controller: _opCodeController,
                        obscureText: _obscureOpCode,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          hintText: 'Masukkan kode otorisasi / keamanan operator',
                          prefixIcon: const Icon(Icons.shield_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(_obscureOpCode
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined),
                            onPressed: () =>
                                setState(() => _obscureOpCode = !_obscureOpCode),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: AppColors.border),
                          ),
                        ),
                      ),
                    ),
                    crossFadeState:
                        _isOperatorMode ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 300),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _loading ? null : _login,
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.4),
                            )
                          : const Text(
                              'Masuk',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: const [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text('atau',
                            style: TextStyle(color: AppColors.textGrey, fontSize: 12)),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 14),

                  SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _loginAsGuest,
                      icon: const Icon(Icons.person_outline),
                      label: const Text('Masuk sebagai Tamu'),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Belum punya akun? ',
                          style: TextStyle(color: AppColors.textGrey)),
                      GestureDetector(
                        onTap: () async {
                          final registeredUser =
                              await Navigator.of(context).push<String>(
                            MaterialPageRoute(
                                builder: (_) => const RegisterScreen()),
                          );
                          if (registeredUser != null && mounted) {
                            _userController.text = registeredUser;
                            _passController.clear();
                          }
                        },
                        child: const Text(
                          'Daftar Akun',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),

                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
