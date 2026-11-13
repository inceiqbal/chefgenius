import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../app/config/routes.dart';
import '../../../app/data/providers/connectivity_provider.dart';
import '../../../app/widgets/offline_banner.dart';
import '../../../app/data/providers/language_provider.dart';
import '../../../app/data/providers/notification_provider.dart';

class LoginScreen extends StatefulWidget {
  // Parameter initialDeepLinkPostId KITA HAPUS karena sekarang logic-nya via SharedPreferences
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(text: 'inceiqbals6@gmail.com');
  final _passwordController = TextEditingController(text: 'Ince674');
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  // 🔥 Helper: Ambil Deep Link ID yang "disimpan" oleh Splash Screen
  Future<String?> _getDeferredDeepLink() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('deferred_deeplink_post_id');
  }

  // 🔥 Helper: Bersihkan Deep Link setelah dipakai
  Future<void> _clearDeferredDeepLink() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('deferred_deeplink_post_id');
  }

  Future<void> _handleLogin() async {
    if (context.read<ConnectivityProvider>().isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Koneksi internet dibutuhkan untuk login!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    // ------------------------------------

    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      final AuthResponse res =
          await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (res.user != null) {
        // Buka box Hive yang diperlukan buat user ini
        await Hive.openBox<String>('pantry_$email');
        
        // FIX: Reinitialize notification provider for new user
        if (mounted) {
          context.read<NotificationProvider>().reinit();
        }
        
        // Set flag bahwa user sudah login manual
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('has_logged_in_${res.user!.id}', true);
        
        if (!mounted) return;
        
        // 🔥 LOGIKA DEFERRED DEEP LINK 🔥
        // Cek apakah tadi ada link yang "tertunda" karena user belum login
        final deferredPostId = await _getDeferredDeepLink();

        if (deferredPostId != null && deferredPostId.isNotEmpty) {
          debugPrint("🚀 Login Sukses! Melanjutkan ke Post ID: $deferredPostId");
          
          // Ada Deep Link tertunda! Buka halaman detail postingan.
          // Kita pakai pushReplacementNamed biar user gak balik ke login kalau back
          Navigator.pushReplacementNamed(
            context, 
            AppRoutes.deepLinkPostDetailRoute, 
            arguments: deferredPostId
          );
          
          await _clearDeferredDeepLink(); // Bersihkan agar tidak terbuka lagi nanti
          return;
        }

        // --- RUTE STANDAR JIKA TIDAK ADA DEEP LINK TERTUNDA ---
        // Arahkan ke SPLASH SCREEN (biar Splash yang ngatur mau ke Home/Intro)
        Navigator.pushReplacementNamed(context, AppRoutes.splashRoute);
        
        return;
      } else {
        throw const AuthException('Login berhasil tetapi data user tidak ditemukan.');
      }
    } on AuthException catch (error) {
      if (!mounted) return;
      String userMessage = 'Email atau password salah. Coba lagi ya!';
      final errorLower = error.message.toLowerCase();

      if (errorLower.contains('network') || errorLower.contains('socket')) {
          userMessage = 'Gagal login. Coba cek internet lo, bro.';
      } else if (!errorLower.contains('invalid login credentials')) {
        userMessage = error.message;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userMessage), 
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi kesalahan: ${error.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOffline = context.watch<ConnectivityProvider>().isOffline;
    final lang = context.watch<LanguageProvider>();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDarkMode
                ? [const Color(0xFF1A1A2E), const Color(0xFF16213E)]
                : [const Color(0xFFFFF8F0), const Color(0xFFFFE8D6)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const OfflineBanner(),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Logo with glow effect
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: isDarkMode 
                                    ? Colors.white.withOpacity(0.1)
                                    : Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFE67E22).withOpacity(0.3),
                                    blurRadius: 30,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: Image.asset(
                                'assets/images/icon_chefgenius.png',
                                height: 80,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          // Title
                          Text(
                            lang.getText('login_title'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            'Masuk ke akun Chef Genius kamu',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(height: 40),
                          
                          // Email Field
                          _buildModernTextField(
                            controller: _emailController,
                            label: lang.getText('email_label'),
                            hint: 'contoh@email.com',
                            icon: Icons.email_rounded,
                            keyboardType: TextInputType.emailAddress,
                            enabled: !isOffline,
                            isDarkMode: isDarkMode,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return lang.getText('email_empty');
                              }
                              if (!value.contains('@') || !value.contains('.')) {
                                return lang.getText('email_invalid');
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // Password Field
                          _buildModernTextField(
                            controller: _passwordController,
                            label: lang.getText('pass_label'),
                            hint: '••••••••',
                            icon: Icons.lock_rounded,
                            obscureText: !_isPasswordVisible,
                            enabled: !isOffline,
                            isDarkMode: isDarkMode,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordVisible
                                    ? Icons.visibility_rounded
                                    : Icons.visibility_off_rounded,
                                color: Colors.grey.shade500,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isPasswordVisible = !_isPasswordVisible;
                                });
                              },
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return lang.getText('pass_empty');
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          
                          // Forgot Password
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: isOffline ? null : () {
                                Navigator.pushNamed(
                                    context, AppRoutes.forgotPasswordRoute);
                              },
                              child: Text(
                                lang.getText('forgot_pass_title'),
                                style: TextStyle(
                                  color: isOffline ? Colors.grey : const Color(0xFFE67E22),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          // Login Button with gradient
                          Container(
                            decoration: BoxDecoration(
                              gradient: isOffline 
                                  ? null
                                  : const LinearGradient(
                                      colors: [Color(0xFFE67E22), Color(0xFFD35400)],
                                    ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: isOffline ? null : [
                                BoxShadow(
                                  color: const Color(0xFFE67E22).withOpacity(0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _isLoading || isOffline ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isOffline ? Colors.grey : Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      isOffline ? lang.getText('offline_mode') : lang.getText('login_btn'),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          // Register Link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Belum punya akun? ',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                              GestureDetector(
                                onTap: isOffline ? null : () =>
                                    Navigator.pushNamed(context, AppRoutes.registerRoute),
                                child: Text(
                                  'Daftar Sekarang',
                                  style: TextStyle(
                                    color: isOffline ? Colors.grey : const Color(0xFFE67E22),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDarkMode,
    TextInputType? keyboardType,
    bool obscureText = false,
    bool enabled = true,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: isDarkMode ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          enabled: enabled,
          validator: validator,
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400),
            prefixIcon: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE67E22).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: const Color(0xFFE67E22), size: 20),
            ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: isDarkMode 
                ? Colors.white.withOpacity(0.05)
                : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE67E22), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }
}