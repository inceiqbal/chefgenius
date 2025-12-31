import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart'; // IMPORT PROVIDER
import '../../../app/data/providers/language_provider.dart'; // IMPORT LANG PROVIDER

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _isCooldown = false;
  int _cooldown = 0;

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

  Future<void> _handleForgotPassword() async {
    final lang = context.read<LanguageProvider>();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();

      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'io.supabase.chefgenius://login-callback/',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lang.getText('forgot_success_msg')), // Dinamis
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context); // Balik ke halaman login
    } on AuthException catch (error) {
      if (!mounted) return;
      String userMessage;
      final errorLower = error.message.toLowerCase();

      if (errorLower.contains('user not found')) {
        // Kita ganti pesan custom "email ... gak kedaftar" jadi pesan generic biar gampang translate
        userMessage = lang.getText('email_not_found'); 
      } else if (errorLower.contains('rate limit') ||
          errorLower.contains('rate_limit') ||
          errorLower.contains('too many requests') ||
          errorLower.contains('exceeded')) {
        userMessage = lang.getText('rate_limit_exceeded');
      } else if (errorLower.contains('network') ||
          errorLower.contains('socket')) {
        userMessage = lang.getText('network_error'); // Reuse
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
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // WATCH PROVIDER
    final lang = context.watch<LanguageProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.getText('forgot_pass_title')), // Dinamis
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
                Text(
                  lang.getText('forgot_pass_header'), // Dinamis
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  lang.getText('forgot_pass_desc'), // Dinamis
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: lang.getText('email_label'), // Reuse
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return lang.getText('email_empty'); // Reuse
                    }
                    if (!value.contains('@') || !value.contains('.')) {
                      return lang.getText('email_invalid'); // Reuse
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: (_isLoading || _isCooldown) ? null : () async {
                    await _handleForgotPassword();
                    _startCooldown();
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : _isCooldown
                          ? Text('Tunggu $_cooldown detik...')
                          : Text(lang.getText('send_reset_btn')), // Dinamis
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context), 
                  child: Text(lang.getText('back_to_login_btn')), // Dinamis
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}