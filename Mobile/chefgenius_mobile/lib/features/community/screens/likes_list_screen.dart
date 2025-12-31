import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../../app/data/providers/language_provider.dart';

class LikesListScreen extends StatefulWidget {
  final String postId;
  const LikesListScreen({super.key, required this.postId});

  @override
  State<LikesListScreen> createState() => _LikesListScreenState();
}

class _LikesListScreenState extends State<LikesListScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    _fetchLikes();
  }

  Future<void> _fetchLikes() async {
    setState(() => _isLoading = true);
    try {
      // Fetch likes and join with profiles
      final response = await supabase
          .from('likes')
          .select('profiles(id, username, full_name, avatar_url)')
          .eq('post_id', widget.postId);

      final List<Map<String, dynamic>> users = [];
      for (var item in response) {
        final profile = item['profiles'];
        if (profile != null) {
          users.add(profile);
        }
      }

      if (mounted) {
        setState(() {
          _users = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching likes: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.read<LanguageProvider>().getText('likes_load_fail'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    
    return Scaffold(
      appBar: AppBar(
        title: Text(lang.getText('likes_title'), style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? Center(child: Text(lang.getText('likes_empty')))
              : ListView.separated(
                  itemCount: _users.length,
                  separatorBuilder: (ctx, i) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: user['avatar_url'] != null
                            ? CachedNetworkImageProvider(user['avatar_url'])
                            : null,
                        child: user['avatar_url'] == null
                            ? Text((user['full_name'] ?? user['username'] ?? "?")[0].toUpperCase())
                            : null,
                      ),
                      title: Text(user['username'] ?? lang.getText('likes_unknown_user'), style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(user['full_name'] ?? ""),
                    );
                  },
                ),
    );
  }
}
