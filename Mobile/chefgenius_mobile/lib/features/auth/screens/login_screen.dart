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
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
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

    return Scaffold(
      body: SafeArea(
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
                        Image.asset('assets/images/icon_chefgenius.png', height: 100),
                        const SizedBox(height: 16),
                        Text(
                          lang.getText('login_title'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 48),
                        TextFormField(
                          controller: _emailController,
                          enabled: !isOffline,
                          decoration: InputDecoration(
                            labelText: lang.getText('email_label'),
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.email),
                          ),
                          keyboardType: TextInputType.emailAddress,
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
                        TextFormField(
                          controller: _passwordController,
                          enabled: !isOffline,
                          decoration: InputDecoration(
                            labelText: lang.getText('pass_label'),
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isPasswordVisible = !_isPasswordVisible;
                                });
                              },
                            ),
                          ),
                          obscureText: !_isPasswordVisible,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return lang.getText('pass_empty');
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: isOffline ? null : () {
                              Navigator.pushNamed(
                                  context, AppRoutes.forgotPasswordRoute);
                            },
                            child: Text(lang.getText('forgot_pass_title')),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _isLoading || isOffline ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: isOffline ? Colors.grey[700] : null,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                                )
                              : Text(isOffline ? lang.getText('offline_mode') : lang.getText('login_btn')),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: isOffline ? null : () =>
                              Navigator.pushNamed(context, AppRoutes.registerRoute),
                          child: Text(lang.getText('register_link')),
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
    );
  }
}