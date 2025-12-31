import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LikesBottomSheet extends StatelessWidget {
  final String postId;

  const LikesBottomSheet({super.key, required this.postId});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Disukai oleh",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: FutureBuilder(
              future: supabase
                  .from('likes')
                  .select('profiles(full_name, username, avatar_url)')
                  .eq('post_id', postId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.orange));
                }
                if (snapshot.hasError) {
                  return Center(child: Text("Gagal memuat: ${snapshot.error}"));
                }
                
                final data = snapshot.data as List<dynamic>;
                if (data.isEmpty) {
                  return const Center(child: Text("Belum ada yang like."));
                }

                return ListView.builder(
                  itemCount: data.length,
                  itemBuilder: (context, index) {
                    final profile = data[index]['profiles'];
                    if (profile == null) return const SizedBox.shrink();
                    
                    final name = profile['full_name'] ?? profile['username'] ?? 'User';
                    final avatarUrl = profile['avatar_url'];

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isDarkMode ? Colors.orange.withOpacity(0.2) : Colors.orange.shade50,
                        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                        child: avatarUrl == null 
                            ? Text(
                                name[0].toUpperCase(), 
                                style: TextStyle(color: isDarkMode ? Colors.orangeAccent : Colors.orange)
                              ) 
                            : null,
                      ),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
