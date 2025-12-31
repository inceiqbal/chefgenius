import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart'; // IMPORT PROVIDER
import '../../../app/widgets/custom_app_bar.dart';
import '../../../app/data/providers/language_provider.dart'; // IMPORT LANG PROVIDER

class ChangePasswordScreen extends StatefulWidget {
  // Kita daftarin nama rutenya
  static const String routeName = '/change-password';

  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  Future<void> _handleChangePassword() async {
    // Ambil provider bahasa
    final lang = context.read<LanguageProvider>();

    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final newPassword = _passwordController.text.trim();

      // Langsung update password user yang lagi login
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lang.getText('change_success_msg')), // Teks dinamis
          backgroundColor: Colors.green,
        ),
      );
      // Balik ke halaman settings
      Navigator.pop(context);
    } on AuthException catch (error) {
      if (!mounted) return;
      String userMessage;
      final errorLower = error.message.toLowerCase();

      // Kita mapping errornya ke kamus bahasa biar konsisten
      if (errorLower.contains('password should be longer')) {
        userMessage = lang.getText('pass_short');
      } else if (errorLower.contains('weak password')) {
        userMessage = lang.getText('pass_weak');
      } else if (errorLower.contains('network') || errorLower.contains('socket')) {
        userMessage = lang.getText('network_error');
      } else {
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
          content: Text('Error: ${error.toString()}'),
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
    // WAJIB WATCH DISINI
    final lang = context.watch<LanguageProvider>();

    return Scaffold(
      appBar: CustomAppBar(title: lang.getText('change_pass_title')), // Dinamis
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
                  lang.getText('reset_pass_header'), // Reuse dari Reset Password ("Masukkan Pass Baru..")
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  lang.getText('change_pass_desc'), // Dinamis
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: lang.getText('new_pass_label'), // Reuse
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
                    labelText: lang.getText('confirm_new_pass_label'), // Reuse
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
                  onPressed: _isLoading ? null : _handleChangePassword,
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
                      : Text(lang.getText('save_pass_btn')), // Reuse ("Simpan Password Baru")
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}