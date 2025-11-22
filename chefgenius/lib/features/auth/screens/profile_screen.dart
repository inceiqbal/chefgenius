import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../app/widgets/custom_app_bar.dart';
import '../../../app/config/routes.dart';

class ProfileScreen extends StatefulWidget {
  final String email;
  const ProfileScreen({super.key, required this.email});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final supabase = Supabase.instance.client;

  bool _isLoading = true;
  String? _fullName;
  String? _username;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
  }

  Future<void> _fetchProfileData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final data = await supabase
          .from('profiles')
          .select('full_name, username, avatar_url')
          .eq('id', userId)
          .maybeSingle();

      if (mounted && data != null) {
        setState(() {
          _fullName = data['full_name'];
          _username = data['username'];
          _avatarUrl = data['avatar_url'];
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: const Text('Gagal muat profil. Cek internet lo, bro.'),
              backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  ImageProvider<Object>? _getAvatarImage() {
    if (_avatarUrl != null) {
      return CachedNetworkImageProvider(_avatarUrl!);
    }
    return null;
  }

  // --- INI DIA FUNGSI BARU BUAT NAMPILIN FOTO (FIX #3) ---
  void _showAvatarDialog() {
    if (_avatarUrl == null) return; // Kalo gak ada foto, gak usah ditampilin

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(10),
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(), // Klik buat nutup
            child: InteractiveViewer(
              // Biar bisa di-zoom
              panEnabled: false,
              minScale: 1.0,
              maxScale: 4.0,
              child: CachedNetworkImage(
                imageUrl: _avatarUrl!,
                fit: BoxFit.contain,
                placeholder: (context, url) =>
                    const Center(child: CircularProgressIndicator()),
                errorWidget: (context, url, error) =>
                    const Icon(Icons.broken_image, color: Colors.white),
              ),
            ),
          ),
        );
      },
    );
  }
  // --- AKHIR FUNGSI BARU ---

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        appBar: CustomAppBar(title: 'Profil Saya'),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final displayName = _fullName ?? _username ?? widget.email.split('@')[0];

    return Scaffold(
      appBar: const CustomAppBar(title: 'Profil Saya'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Column(
                children: [
                  // --- INI DIA PERBAIKANNYA (BISA DI-KLIK) ---
                  GestureDetector(
                    onTap: _showAvatarDialog, // Panggil fungsi dialog
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceVariant,
                      backgroundImage: _getAvatarImage(),
                      child: _avatarUrl == null
                          ? Icon(
                              Icons.person,
                              size: 70,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : null,
                    ),
                  ),
                  // --- AKHIR PERBAIKAN ---
                  const SizedBox(height: 16),
                  Text(
                    displayName,
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.email,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.pushNamed(
                        context,
                        AppRoutes.editProfileRoute,
                        arguments: widget.email,
                      );

                      if (result == true && mounted) {
                        _fetchProfileData();
                      }
                    },
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Edit Profil'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceVariant,
                      foregroundColor:
                          Theme.of(context).colorScheme.onSurface,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceVariant,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading:
                        const Icon(Icons.favorite, color: Colors.redAccent),
                    title: const Text('Resep Favorit Saya'),
                    trailing: const Icon(Icons.arrow_forward_ios,
                        size: 16, color: Colors.grey),
                    onTap: () {
                      Navigator.pushNamed(
                          context, AppRoutes.favoriteRecipesRoute);
                    },
                  ),
                  const Divider(height: 1, indent: 72),
                  ListTile(
                    leading:
                        const Icon(Icons.settings, color: Colors.blueGrey),
                    title: const Text('Pengaturan'),
                    trailing: const Icon(Icons.arrow_forward_ios,
                        size: 16, color: Colors.grey),
                    onTap: () {
                      Navigator.pushNamed(context, AppRoutes.settingsRoute);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              icon: Icon(Icons.logout,
                  color: Theme.of(context).colorScheme.error),
              label: Text(
                'Logout',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    Theme.of(context).colorScheme.errorContainer,
                foregroundColor:
                    Theme.of(context).colorScheme.onErrorContainer,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                      color: Theme.of(context)
                          .colorScheme
                          .error
                          .withOpacity(0.3)),
                ),
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (BuildContext dialogContext) {
                    return AlertDialog(
                      title: const Text('Konfirmasi Logout'),
                      content:
                          const Text('Apakah Anda yakin ingin keluar?'),
                      actions: <Widget>[
                        TextButton(
                          child: const Text('Batal'),
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                          },
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            try {
                              await Supabase.instance.client.auth.signOut();
                              if (!dialogContext.mounted) return;
                              Navigator.of(dialogContext).pop();
                              if (!context.mounted) return;
                              Navigator.pushNamedAndRemoveUntil(
                                context,
                                AppRoutes.loginRoute,
                                (route) => false,
                              );
                            } catch (error) {
                              if (!dialogContext.mounted) return;
                              Navigator.of(dialogContext).pop();
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Gagal logout. Cek internet lo, bro.'),
                                  backgroundColor:
                                      Theme.of(context).colorScheme.error,
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[600],
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Logout'),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}