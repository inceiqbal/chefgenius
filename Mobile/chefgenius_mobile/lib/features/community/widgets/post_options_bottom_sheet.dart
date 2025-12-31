import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'edit_post_bottom_sheet.dart';
import 'report_dialog.dart';
import 'dialog_utils.dart';

class PostOptionsBottomSheet extends StatelessWidget {
  final Map<String, dynamic> post;
  final int index;
  final Function(String, int) onDelete;
  final Function(Map<String, dynamic>, int) onEditSuccess;

  const PostOptionsBottomSheet({
    super.key,
    required this.post,
    required this.index,
    required this.onDelete,
    required this.onEditSuccess,
  });

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    final isMyPost = post['user_id'] == userId;
    
    final createdAt = DateTime.parse(post['created_at']);
    final now = DateTime.now();
    final isEditable = now.difference(createdAt.toLocal()).inHours < 24;

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle Bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[600] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          if (isMyPost) ...[
            if (isEditable)
              ListTile(
                leading: Icon(Icons.edit, color: isDarkMode ? Colors.white70 : Colors.black87),
                title: Text("Edit Postingan", style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87)),
                onTap: () async {
                  debugPrint('POST_OPTIONS: edit tapped for post id=${post['id']}');
                  Navigator.pop(context);
                  debugPrint('POST_OPTIONS: opening EditPostBottomSheet for post id=${post['id']}');
                  final newCaption = await showModalBottomSheet<String>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => EditPostBottomSheet(post: post),
                  );
                  
                  if (newCaption != null) {
                    final updatedPost = Map<String, dynamic>.from(post);
                    updatedPost['caption'] = newCaption;
                    updatedPost['is_edited'] = true;
                    onEditSuccess(updatedPost, index);
                  }
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text("Hapus Postingan", style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                showInstagramDialog(
                  context: context,
                  title: "Hapus Postingan?",
                  content: "Yakin mau hapus? Postingan yang udah dihapus gak bisa balik lagi lho.",
                  primaryActionText: "Hapus",
                  isDestructive: true,
                  onPrimaryAction: () => onDelete(post['id'], index),
                );
              },
            ),
          ],
          if (!isMyPost)
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: Colors.red),
              title: const Text("Laporin Postingan", style: TextStyle(color: Colors.red)),
              onTap: () {
                debugPrint('POST_OPTIONS: report tapped for post id=${post['id']}');
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (context) => ReportDialog(
                    postId: post['id'],
                    reportedUserId: post['user_id'],
                  ),
                );
              },
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
