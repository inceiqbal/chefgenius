import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../app/widgets/custom_app_bar.dart';

class EditProfileScreen extends StatefulWidget {
  final String email;
  const EditProfileScreen({super.key, required this.email});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();

  bool _isLoading = false;
  final supabase = Supabase.instance.client;

  String? _avatarUrl;
  File? _avatarImageFile;
  // --- STATE BARU BUAT NGE-TRACK PENGHAPUSAN ---
  bool _isAvatarMarkedForDeletion = false;
  // ------------------------------------------

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final response = await supabase
          .from('profiles')
          .select('full_name, username, avatar_url')
          .eq('id', userId)
          .maybeSingle();

      final defaultUsername = widget.email.split('@')[0];

      if (mounted) {
        if (response != null) {
          _nameController.text = response['full_name'] ?? '';
          _usernameController.text = response['username'] ?? defaultUsername;
          _avatarUrl = response['avatar_url'];
        } else {
          _usernameController.text = defaultUsername;
        }
        setState(() {});
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Gagal memuat data profil. Coba cek internet lo.')),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    try {
      final xFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        imageQuality: 75,
      );

      if (xFile != null) {
        setState(() {
          _avatarImageFile = File(xFile.path);
          _isAvatarMarkedForDeletion = false; // Batalin hapus kalo milih foto baru
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal milih foto, coba lagi.')),
        );
      }
    }
  }

  // --- FUNGSI BARU BUAT HAPUS FOTO ---
  void _deleteImage() {
    setState(() {
      _avatarImageFile = null; // Hapus file lokal (kalo ada)
      _avatarUrl = null; // Hapus URL lama
      _isAvatarMarkedForDeletion = true; // Tandain buat dihapus pas 'Simpan'
    });
  }
  // --- AKHIR FUNGSI BARU ---

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isLoading = true);

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User tidak terautentikasi!')),
        );
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      String? newAvatarUrl;

      // Kalo user milih file baru, upload
      if (_avatarImageFile != null) {
        final file = _avatarImageFile!;
        final fileExt = file.path.split('.').last;
        final filePath = '$userId/avatar.$fileExt';

        await supabase.storage.from('avatars').upload(
              filePath,
              file,
              fileOptions: const FileOptions(
                cacheControl: '3600',
                upsert: true,
              ),
            );

        final String publicUrl =
            supabase.storage.from('avatars').getPublicUrl(filePath);
        final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        newAvatarUrl = '$publicUrl?t=$timestamp';
      } 
      // Kalo user nge-klik HAPUS
      else if (_isAvatarMarkedForDeletion) {
        newAvatarUrl = null; // Kirim 'null' ke database
      } 
      // Kalo user gak ngapa-ngapain
      else {
        newAvatarUrl = _avatarUrl; // Pake URL lama
      }

      final updates = {
        'id': userId,
        'full_name': _nameController.text.trim(),
        'username': _usernameController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
        'avatar_url': newAvatarUrl, // Kirim URL baru (atau null)
      };

      await supabase.from('profiles').upsert(updates);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil berhasil diperbarui!')),
        );
        Navigator.pop(context, true); // Kirim 'true' biar profile_screen nge-refresh
      }
    } on PostgrestException catch (error) {
      if (mounted) {
        String userMessage = 'Error: ${error.message}';
        final errorLower = error.message.toLowerCase();

        if (errorLower.contains('profiles_username_key')) {
          userMessage =
              'Username "${_usernameController.text}" udah dipake orang. Ganti yang lain, bro!';
        } else if (errorLower.contains('network') ||
            errorLower.contains('socket')) {
          userMessage = 'Gagal nyimpen profil. Coba cek internet lo.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(userMessage),
              backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Terjadi kesalahan: ${error.toString()}'),
              backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  ImageProvider<Object>? _getAvatarImage() {
    if (_avatarImageFile != null) {
      return FileImage(_avatarImageFile!);
    }
    if (_avatarUrl != null) {
      return NetworkImage(_avatarUrl!);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Cek apakah ada foto yang nampil
    final bool hasAvatar = (_avatarImageFile != null || _avatarUrl != null);

    return Scaffold(
      appBar: const CustomAppBar(title: 'Edit Profil'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey.shade300,
                      backgroundImage: _getAvatarImage(),
                      child: !hasAvatar // Cuma nampilin ikon kalo gak ada foto
                          ? const Icon(Icons.person,
                              size: 70, color: Colors.white)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: CircleAvatar(
                        backgroundColor: Theme.of(context).primaryColor,
                        child: IconButton(
                          icon: const Icon(Icons.edit,
                              color: Colors.white, size: 20),
                          onPressed: _pickImage, // Tombol Edit (pensil)
                          tooltip: 'Ganti Foto',
                        ),
                      ),
                    ),
                    // --- INI DIA TOMBOL HAPUS BARUNYA ---
                    Positioned(
                      bottom: 0,
                      left: 0,
                      child: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.error,
                        child: IconButton(
                          icon: const Icon(Icons.delete,
                              color: Colors.white, size: 20),
                          onPressed: hasAvatar ? _deleteImage : null, // Tombol Hapus (tong sampah)
                          tooltip: 'Hapus Foto',
                        ),
                      ),
                    ),
                    // --- AKHIR TOMBOL HAPUS ---
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Perbarui data pribadi Anda:',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Lengkap',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nama tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.alternate_email),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Username tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _updateProfile,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save),
                label: Text(_isLoading ? 'Menyimpan...' : 'Simpan Perubahan'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}