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
  final _bioController = TextEditingController();

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
          .select('full_name, username, avatar_url, bio')
          .eq('id', userId)
          .maybeSingle();

      final defaultUsername = widget.email.split('@')[0];

      if (mounted) {
        if (response != null) {
          _nameController.text = response['full_name'] ?? '';
          _usernameController.text = response['username'] ?? defaultUsername;
          _bioController.text = response['bio'] ?? '';
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
        'bio': _bioController.text.trim(),
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
      if (_avatarUrl!.startsWith('asset:')) {
        return AssetImage(_avatarUrl!.substring(6));
      }
      return NetworkImage(_avatarUrl!);
    }
    return null;
  }

  void _showImageSourceDialog() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFE67E22), Color(0xFFD35400)]),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(color: const Color(0xFFE67E22).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'Pilih Foto Profil',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Options
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Column(
                    children: [
                      _buildModernOptionTile(
                        icon: Icons.photo_library_rounded,
                        title: 'Galeri',
                        subtitle: 'Pilih dari galeri foto',
                        gradient: const [Color(0xFFE67E22), Color(0xFFD35400)],
                        isDarkMode: isDarkMode,
                        onTap: () {
                          Navigator.pop(context);
                          _pickImage();
                        },
                      ),
                      const SizedBox(height: 8),
                      _buildModernOptionTile(
                        icon: Icons.emoji_emotions_rounded,
                        title: 'Avatar Kartun',
                        subtitle: 'Pilih avatar lucu',
                        gradient: const [Color(0xFFF39C12), Color(0xFFE67E22)],
                        isDarkMode: isDarkMode,
                        onTap: () {
                          Navigator.pop(context);
                          _showEmojiPickerDialog();
                        },
                      ),
                      if (_avatarUrl != null || _avatarImageFile != null) ...[
                        const SizedBox(height: 8),
                        _buildModernOptionTile(
                          icon: Icons.delete_rounded,
                          title: 'Hapus Foto',
                          subtitle: 'Kembali ke default',
                          gradient: const [Color(0xFFE67E22), Color(0xFFD35400)],
                          isDarkMode: isDarkMode,
                          onTap: () {
                            Navigator.pop(context);
                            _deleteImage();
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildModernOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradient,
    required bool isDarkMode,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  void _showEmojiPickerDialog() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // List emoji assets
    final List<String> emojis = [
      'excited.png', 'genit.png', 'marah.png', 'nyapa.png', 'wow.png'
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFF39C12), Color(0xFFE67E22)]),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFFF39C12).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: const Icon(Icons.emoji_emotions_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      'Pilih Avatar Kartun',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Emoji Grid
              Container(
                height: 180,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: emojis.length,
                  itemBuilder: (context, index) {
                    final emojiName = emojis[index];
                    final assetPath = 'assets/images/emoji/$emojiName';
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _avatarUrl = 'asset:$assetPath';
                          _avatarImageFile = null;
                          _isAvatarMarkedForDeletion = false;
                        });
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300),
                        ),
                        child: Image.asset(assetPath),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasAvatar = (_avatarImageFile != null || _avatarUrl != null);
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
              // Modern AppBar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.white.withOpacity(0.1) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Icon(Icons.arrow_back_ios_new_rounded, 
                          color: isDarkMode ? Colors.white : Colors.black87, size: 20),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFE67E22), Color(0xFFD35400)]),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFFE67E22).withOpacity(0.3), blurRadius: 8),
                        ],
                      ),
                      child: const Icon(Icons.person_outline_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Edit Profil',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Avatar Section
                        Center(
                          child: Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFFE67E22), 
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFE67E22).withOpacity(0.3),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 60,
                                  backgroundColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                                  backgroundImage: _getAvatarImage(),
                                  child: !hasAvatar
                                      ? Icon(Icons.person_rounded,
                                          size: 60, color: Colors.grey.shade400)
                                      : null,
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: _showImageSourceDialog,
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFFE67E22), Color(0xFFD35400)]
                                      ),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(color: const Color(0xFFE67E22).withOpacity(0.4), blurRadius: 8),
                                      ],
                                    ),
                                    child: const Icon(Icons.camera_alt_rounded,
                                        color: Colors.white, size: 18),
                                  ),
                                ),
                              ),
                              if (hasAvatar)
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  child: GestureDetector(
                                    onTap: _deleteImage,
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFFE67E22), Color(0xFFD35400)]
                                        ),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(color: const Color(0xFFE67E22).withOpacity(0.4), blurRadius: 8),
                                        ],
                                      ),
                                      child: const Icon(Icons.delete_rounded,
                                          color: Colors.white, size: 18),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        
                        // Email (read-only) with modern style
                        _buildModernTextField(
                          initialValue: widget.email,
                          label: 'Email',
                          hint: '',
                          icon: Icons.email_outlined,
                          isDarkMode: isDarkMode,
                          readOnly: true,
                          enabled: false,
                        ),
                        const SizedBox(height: 20),
                        
                        // Section header
                        Text(
                          'Informasi Pribadi',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Name Field
                        _buildModernTextField(
                          controller: _nameController,
                          label: 'Nama Lengkap',
                          hint: 'Masukkan nama lengkap',
                          icon: Icons.person_rounded,
                          isDarkMode: isDarkMode,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Nama tidak boleh kosong';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // Username Field
                        _buildModernTextField(
                          controller: _usernameController,
                          label: 'Username',
                          hint: '@username',
                          icon: Icons.alternate_email_rounded,
                          isDarkMode: isDarkMode,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Username tidak boleh kosong';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // Bio Field
                        _buildModernTextField(
                          controller: _bioController,
                          label: 'Bio',
                          hint: 'Tulis sesuatu tentang diri kamu...',
                          icon: Icons.info_outline_rounded,
                          isDarkMode: isDarkMode,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 32),
                        
                        // Save Button
                        Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFE67E22), Color(0xFFD35400)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFE67E22).withOpacity(0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _updateProfile,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.save_rounded, color: Colors.white),
                            label: Text(
                              _isLoading ? 'Menyimpan...' : 'Simpan Perubahan',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ],
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
    TextEditingController? controller,
    String? initialValue,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDarkMode,
    bool readOnly = false,
    bool enabled = true,
    int maxLines = 1,
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
          initialValue: controller == null ? initialValue : null,
          readOnly: readOnly,
          enabled: enabled,
          maxLines: maxLines,
          validator: validator,
          style: TextStyle(
            color: enabled 
                ? (isDarkMode ? Colors.white : Colors.black87)
                : Colors.grey,
          ),
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
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
              ),
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
