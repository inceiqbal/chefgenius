import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:intl/intl.dart';

class EditPostBottomSheet extends StatefulWidget {
  final Map<String, dynamic> post;

  const EditPostBottomSheet({super.key, required this.post});

  @override
  State<EditPostBottomSheet> createState() => _EditPostBottomSheetState();
}

class _EditPostBottomSheetState extends State<EditPostBottomSheet> {
  late TextEditingController _captionController;
  bool _isSaving = false;
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _captionController = TextEditingController(text: widget.post['caption'] ?? '');
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _savePost() async {
    final newCaption = _captionController.text.trim();
    if (newCaption.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      await supabase
          .from('posts')
          .update({
            'caption': newCaption,
            'is_edited': true,
          })
          .eq('id', widget.post['id']);

      if (mounted) {
        Navigator.pop(context, newCaption);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Gagal menyimpan perubahan.")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _formatTime(String? dateString) {
    if (dateString == null) return '';
    DateTime date = DateTime.parse(dateString);
    if (!date.isUtc && !dateString.endsWith('Z') && !dateString.contains('+')) {
      date = DateTime.utc(
        date.year, date.month, date.day, 
        date.hour, date.minute, date.second, 
        date.millisecond, date.microsecond
      );
    }
    final localDate = date.toLocal();
    final now = DateTime.now();
    final difference = now.difference(localDate);

    if (difference.inDays > 7) {
      return DateFormat('d MMMM yyyy', 'id').format(localDate);
    } else {
      return timeago.format(localDate, locale: 'id');
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subTextColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];

    // Media List
    final rawMedia = post['post_media'] as List?;
    final mediaList = rawMedia != null 
        ? List<Map<String, dynamic>>.from(rawMedia) 
        : <Map<String, dynamic>>[];
    
    // Sort media by position (handle null safely)
    mediaList.sort((a, b) {
      final posA = a['position'] ?? a['media_order'] ?? 0;
      final posB = b['position'] ?? b['media_order'] ?? 0;
      return (posA as int).compareTo(posB as int);
    });

    // Fallback if no media but image_url exists (legacy)
    if (mediaList.isEmpty && post['image_url'] != null) {
      mediaList.add({
        'url': post['image_url'],
        'type': 'image',
        'position': 0
      });
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.9, // Almost full screen
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // HEADER
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
                const Text(
                  "Edit Info",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: _isSaving 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check, color: Colors.blue),
                  onPressed: _isSaving ? null : _savePost,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          
          // CONTENT SCROLLABLE
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // USER INFO
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundImage: NetworkImage(post['author_avatar'] ?? 'https://ui-avatars.com/api/?name=${post['author_name']}'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                post['author_name'] ?? 'User',
                                style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                              ),
                              if (post['location'] != null || post['category'] != null)
                                Text(
                                  [post['location'], post['category']].where((e) => e != null).join(' • '),
                                  style: TextStyle(fontSize: 12, color: subTextColor),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          _formatTime(post['created_at']),
                          style: TextStyle(fontSize: 12, color: subTextColor),
                        ),
                      ],
                    ),
                  ),

                  // MEDIA (Simplified, just first image or carousel placeholder)
                  if (mediaList.isNotEmpty)
                    SizedBox(
                      height: 300,
                      width: double.infinity,
                      child: PageView.builder(
                        itemCount: mediaList.length,
                        itemBuilder: (context, index) {
                          final media = mediaList[index];
                            return CachedNetworkImage(
                              imageUrl: media['thumbnail_url'] ?? media['url'],
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: isDarkMode ? Colors.grey[850] : Colors.grey[200],
                              ),
                              errorWidget: (context, url, error) => const Icon(Icons.error),
                            );
                        },
                      ),
                    ),

                  // ACTION BUTTONS (DISABLED)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Opacity(
                      opacity: 0.5,
                      child: Row(
                        children: [
                          Icon(post['is_liked'] ? Icons.favorite : Icons.favorite_border, color: textColor),
                          const SizedBox(width: 16),
                          Icon(Icons.chat_bubble_outline, color: textColor),
                          const SizedBox(width: 16),
                          Icon(Icons.send, color: textColor),
                          const Spacer(),
                          Icon(post['is_saved'] ? Icons.bookmark : Icons.bookmark_border, color: textColor),
                        ],
                      ),
                    ),
                  ),

                  // CAPTION EDIT FIELD
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _captionController,
                      maxLines: null,
                      decoration: InputDecoration(
                        hintText: "Tulis caption...",
                        border: InputBorder.none,
                        filled: true,
                        fillColor: Theme.of(context).cardColor,
                        hintStyle: TextStyle(color: subTextColor),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      style: TextStyle(color: textColor, fontSize: 16),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // EDIT INDICATOR (Preview)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text(
                          "Telah diedit",
                          style: TextStyle(fontSize: 12, color: subTextColor, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
