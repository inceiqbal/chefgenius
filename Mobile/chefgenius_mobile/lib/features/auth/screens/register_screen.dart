import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../../app/config/routes.dart';
import '../../../app/data/providers/language_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _isCooldown = false;
  int _cooldown = 0;
  
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  // Daftar domain email disposable
  static const List<String> _blockedEmailDomains = [
    'tempmail.com', 'temp-mail.org', 'guerrillamail.com', 'mailinator.com',
    '10minutemail.com', 'throwaway.email', 'fakeinbox.com', 'trashmail.com',
    'yopmail.com', 'getnada.com', 'mohmal.com', 'tempail.com', 'dispostable.com',
    'mailnesia.com', 'mintemail.com', 'spamgourmet.com', 'mytrashmail.com',
    'sharklasers.com', 'guerrillamail.info', 'grr.la', 'spam4.me',
  ];

  void _startCooldown([int seconds = 30]) async {
    setState(() {
      _isCooldown = true;
      _cooldown = seconds;
    });
    while (_cooldown > 0) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() => _cooldown--);
    }
    if (mounted) setState(() => _isCooldown = false);
  }

  String? _validateEmail(String? value, LanguageProvider lang) {
    if (value == null || value.trim().isEmpty) {
      return lang.getText('email_empty');
    }
    
    final email = value.trim().toLowerCase();
    
    // Regex email standard
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    
    if (!emailRegex.hasMatch(email)) {
      return lang.getText('email_invalid');
    }
    
    final domain = email.split('@').last;
    if (_blockedEmailDomains.contains(domain)) {
      return 'Email temporary tidak diperbolehkan. Gunakan email asli ya! 📧';
    }
    
    final similarDomains = {
      'gmial.com': 'gmail.com', 'gmal.com': 'gmail.com', 'gmaill.com': 'gmail.com',
      'gmali.com': 'gmail.com', 'gamil.com': 'gmail.com', 'gnail.com': 'gmail.com',
      'yahooo.com': 'yahoo.com', 'yaho.com': 'yahoo.com', 'yhoo.com': 'yahoo.com',
      'hotmal.com': 'hotmail.com', 'hotmial.com': 'hotmail.com', 
      'outlok.com': 'outlook.com', 'outloo.com': 'outlook.com',
    };
    
    if (similarDomains.containsKey(domain)) {
      return 'Mungkin maksudmu ${similarDomains[domain]}? 🤔';
    }
    
    return null;
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final fullName = _fullNameController.text.trim();
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      // --- UPGRADE DISINI SOB ---
      // Kita simpan full_name ke 'data' (User Metadata).
      // Ini aman banget kalau insert profile gagal karena RLS atau email belum verified.
      final AuthResponse res = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: { 'full_name': fullName }, // <--- SAFETY NET
      );

      if (res.user != null) {
        // Coba bikin profile manual (Berhasil kalau Auto-Confirm ON)
        try {
          // PENTING: 'id' harus ada biar lolos RLS (auth.uid() = id)
          await Supabase.instance.client.from('profiles').upsert({
            'id': res.user!.id, 
            'full_name': fullName,
            'username': email.split('@')[0],
          });
          debugPrint("✅ Profile created successfully via RegisterScreen");
        } catch (e) {
          // Kalau gagal (misal karena belum verified email), gak masalah.
          // Metadata 'full_name' udah aman, nanti dibikin pas login pertama.
          debugPrint("⚠️ Profile creation skipped (likely unverified email/RLS): $e");
        }

        if (mounted) setState(() => _isLoading = false);
        if (!mounted) return;
        
        // Tampilkan dialog verifikasi
        await _showVerificationDialog(email);
      }
    } on AuthException catch (error) {
      if (!mounted) return;
      _handleAuthError(error);
    } on PostgrestException catch (error) {
      debugPrint("⚠️ PostgrestException ignored: ${error.message}");
    } catch (error) {
      if (!mounted) return;
      _handleGenericError(error);
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  // Helper functions biar codingan utama bersih
  Future<void> _showVerificationDialog(String email) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.mark_email_read_outlined, color: Colors.orange, size: 28),
            const SizedBox(width: 10),
            const Text("Cek Email Kamu! 📬"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Yeay! Tinggal selangkah lagi nih! 🎉",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Text(
              "Kami udah kirim link verifikasi ke:",
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                email,
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange[800]),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Klik link di email buat aktivasi akunmu, terus balik lagi ke sini buat login ya! 😊",
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 12),
            Text(
              "💡 Tips: Cek folder Spam/Junk kalau gak nemu emailnya.",
              style: TextStyle(fontSize: 12, color: Colors.grey[500], fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.of(context).pop(); 
                Navigator.of(context).pop(); 
              },
              child: const Text("Oke, Mengerti! 👍", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _handleAuthError(AuthException error) {
    String userMessage;
    final errorLower = error.message.toLowerCase();

    if (errorLower.contains('user already registered')) {
      userMessage = "Email ini udah terdaftar nih. Coba login aja atau pake email lain! 📧";
    } else if (errorLower.contains('network') || errorLower.contains('socket')) {
      userMessage = "Sinyal ilang-ilangan nih. Cek koneksi internetmu dulu ya! 📡";
    } else if (errorLower.contains('password should be longer')) {
      userMessage = "Passwordnya kependekan nih! Minimal 6 karakter ya. 📏";
    } else {
      userMessage = "Yah, gagal daftar: ${error.message} 😓";
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(userMessage),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  void _handleGenericError(Object error) {
    final errorStr = error.toString().toLowerCase();
    if (errorStr.contains('profiles') || errorStr.contains('security policy')) {
      debugPrint("⚠️ RLS error ignored: $error");
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Waduh, ada error nih: ${error.toString()}. Coba lagi nanti ya! 😵'),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.getText('register_title')),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                Image.asset('assets/images/icon_chefgenius.png', height: 80),
                const SizedBox(height: 16),
                Text(lang.getText('register_subtitle'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _fullNameController,
                  decoration: InputDecoration(
                      labelText: lang.getText('full_name_label'),
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.person_outline)),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return lang.getText('full_name_empty');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                      labelText: lang.getText('email_label'),
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.email_outlined)),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) => _validateEmail(value, lang),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: lang.getText('pass_label'),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
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
                    if (value.length < 6) {
                      return lang.getText('pass_short');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: InputDecoration(
                    labelText: lang.getText('pass_confirm_label'),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_person_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                        });
                      },
                    ),
                  ),
                  obscureText: !_isConfirmPasswordVisible,
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return lang.getText('pass_mismatch');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: (_isLoading || _isCooldown) ? null : () async {
                    await _handleRegister();
                    _startCooldown();
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : _isCooldown
                          ? Text('Tunggu $_cooldown detik...')
                          : Text(lang.getText('register_btn')),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: Theme.of(context).textTheme.bodySmall,
                      children: [
                        TextSpan(text: lang.getText('terms_agree')),
                        TextSpan(
                          text: lang.getText('terms_link'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              Navigator.pushNamed(context, AppRoutes.termsRoute);
                            },
                        ),
                        TextSpan(text: lang.getText('terms_and')),
                        TextSpan(
                          text: lang.getText('privacy_link'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              Navigator.pushNamed(context, AppRoutes.privacyPolicyRoute);
                            },
                        ),
                        TextSpan(text: lang.getText('terms_us')),
                      ],
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(lang.getText('login_link')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}