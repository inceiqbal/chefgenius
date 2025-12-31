import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart'; // IMPORT PROVIDER
import '../../../app/config/routes.dart'; 
import '../../../app/widgets/custom_app_bar.dart';
import '../../../app/data/providers/language_provider.dart'; // IMPORT LANG PROVIDER

class ResetPasswordFormScreen extends StatefulWidget {
  const ResetPasswordFormScreen({super.key});

  @override
  State<ResetPasswordFormScreen> createState() =>
      _ResetPasswordFormScreenState();
}

class _ResetPasswordFormScreenState extends State<ResetPasswordFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  Future<void> _handlePasswordUpdate() async {
    // final lang = context.read<LanguageProvider>();

    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final newPassword = _passwordController.text;

      // Perbarui password pengguna di Supabase
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Sip! Password baru udah disimpen. Jangan lupa lagi ya! 🔐"), 
          backgroundColor: Colors.green,
        ),
      );

      // Arahkan kembali ke halaman Login setelah berhasil
      Navigator.pushNamedAndRemoveUntil(
          context, AppRoutes.loginRoute, (route) => false);
    } on AuthException catch (error) {
      if (!mounted) return;
      String userMessage;
      final errorLower = error.message.toLowerCase();

      if (errorLower.contains('password should be longer')) {
        userMessage = "Passwordnya kependekan nih! Minimal 6 karakter ya. 📏";
      } else if (errorLower.contains('weak password')) {
        userMessage = "Passwordnya terlalu lemah. Tambahin angka atau simbol biar kuat! 💪";
      } else if (errorLower.contains('network') ||
          errorLower.contains('socket')) {
        userMessage = "Sinyal ilang-ilangan nih. Cek koneksi internetmu dulu ya! 📡";
      } else {
        userMessage = "Yah, gagal reset password: ${error.message} 😓"; 
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
          content: Text('Waduh, ada error nih: ${error.toString()}. Coba lagi nanti ya! 😵'),
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
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // WATCH PROVIDER
    final lang = context.watch<LanguageProvider>();

    return Scaffold(
      appBar: CustomAppBar(title: lang.getText('reset_pass_title')), // Dinamis
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                Text(
                  lang.getText('reset_pass_header'), // Dinamis
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: lang.getText('new_pass_label'), // Dinamis
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline),
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
                      return lang.getText('pass_empty'); // Reuse
                    }
                    if (value.length < 6) {
                      return lang.getText('pass_short'); // Reuse
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: InputDecoration(
                    labelText: lang.getText('confirm_new_pass_label'), // Dinamis
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_person_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isConfirmPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
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
                      return lang.getText('pass_mismatch'); // Reuse
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handlePasswordUpdate,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(lang.getText('save_pass_btn')), // Dinamis
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}