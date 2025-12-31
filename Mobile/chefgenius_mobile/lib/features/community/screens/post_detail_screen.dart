import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../app/config/routes.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;
  // Parameter ini kita keep biar gak error kalau ada sisa panggilan lama di code lain, 
  // tapi sebenernya gak dipake lagi di logic redirect ini.
  final bool openComments;
  final String? highlightCommentId;

  const PostDetailScreen({
    super.key, 
    required this.postId,
    this.openComments = false,
    this.highlightCommentId,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    // Begitu halaman dibuka, langsung jalankan misi pencarian pemilik
    _redirectOwnerProfile();
  }

  Future<void> _redirectOwnerProfile() async {
    try {
      // 1. Cek User ID pemilik postingan ini
      // Kita cuma ambil kolom 'user_id', gak perlu fetch data lain (hemat kuota)
      final response = await supabase
          .from('posts')
          .select('user_id')
          .eq('id', widget.postId)
          .single();

      final ownerId = response['user_id'] as String;

      if (mounted) {
        // 2. Redirect (Lempar) user ke Profil Pemilik
        // Kita titipin 'initialPostId' biar pas Profil kebuka, postingannya langsung nongol.
        Navigator.pushReplacementNamed(
          context, 
          AppRoutes.profileRoute, 
          arguments: {
            'userId': ownerId, // Buka profil orang ini
            'initialPostId': widget.postId, // Tolong langsung bukain postingan ini
          }
        );
      }
    } catch (e) {
      debugPrint("Gagal redirect ke profil: $e");
      
      // Fallback: Kalau postingan gak ketemu (misal udah dihapus)
      // Jangan biarin user terjebak di loading selamanya. Balikin ke Splash/Home.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Postingan tidak ditemukan atau telah dihapus.")),
        );
        Navigator.pushReplacementNamed(context, AppRoutes.splashRoute);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tampilannya cuma loading doang, karena proses redirect ini cepet banget.
    // User gak bakal sempet liat halaman ini lama-lama.
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(color: Colors.orange),
      ),
    );
  }
}