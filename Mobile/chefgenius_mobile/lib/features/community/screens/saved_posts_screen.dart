import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:chefgenius/app/config.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../../app/data/providers/language_provider.dart';
import '../../../app/widgets/offline_banner.dart';
import '../../../app/config/routes.dart';
import '../widgets/post_card.dart';
import '../widgets/post_options_bottom_sheet.dart';
import '../widgets/save_collection_dialog.dart';
import '../widgets/share_bottom_sheet.dart';
import '../widgets/likes_bottom_sheet.dart'; // Tambahkan ini agar _handleLikesTap bisa jalan

class SavedPostsScreen extends StatefulWidget {
  const SavedPostsScreen({super.key});

  @override
  State<SavedPostsScreen> createState() => _SavedPostsScreenState();
}

class _SavedPostsScreenState extends State<SavedPostsScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _posts = [];
  
  // Collections State
  List<Map<String, dynamic>> _collections = [];
  String? _selectedCollectionId; // null means "All"
  bool _isLoadingCollections = true;

  @override
  void initState() {
    super.initState();
    _fetchCollections();
    _fetchSavedPosts();
  }

  Future<void> _fetchCollections() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await supabase
          .from('collections')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _collections = List<Map<String, dynamic>>.from(response);
          _isLoadingCollections = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching collections: $e");
      if (mounted) setState(() => _isLoadingCollections = false);
    }
  }

  Future<void> _createCollection() async {
    final TextEditingController controller = TextEditingController();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final String? name = await showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  "Buat Koleksi Baru",
                  style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: "Nama Koleksi",
                  hintStyle: TextStyle(color: isDarkMode ? Colors.grey[500] : Colors.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isDarkMode ? Colors.grey[700]! : Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isDarkMode ? Colors.grey[700]! : Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.orange, width: 2),
                  ),
                  filled: true,
                  fillColor: isDarkMode ? Colors.grey[800] : Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: isDarkMode ? Colors.grey[700]! : Colors.grey.shade300),
                        ),
                      ),
                      child: Text("Batal", style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.black87)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, controller.text.trim()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text("Buat"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (name != null && name.isNotEmpty) {
      try {
        final userId = supabase.auth.currentUser?.id;
        if (userId == null) return;

        final res = await supabase
            .from('collections')
            .insert({'user_id': userId, 'name': name})
            .select()
            .single();
        
        if (mounted) {
          setState(() {
            _collections.insert(0, res);
            _selectedCollectionId = res['id']; // Auto select new collection
          });
          _fetchSavedPosts(); // Refresh posts (will be empty for new collection)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Koleksi baru siap diisi! 🎉")),
          );
        }
      } catch (e) {
        debugPrint("Error creating collection: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Yah, gagal bikin koleksi. Coba lagi yuk! 😅")),
          );
        }
      }
    }
  }

  Future<void> _fetchSavedPosts() async {
    setState(() => _isLoading = true);
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      var query = supabase
          .from('saved_posts')
          .select('''
            id,
            created_at,
            posts (
              *,
              post_media(*),
              profiles (full_name, username, avatar_url),
              likes (user_id),
              saved_posts (user_id),
              comments (id)
            )
          ''')
          .eq('user_id', userId);

      // Filter by Collection
      if (_selectedCollectionId != null) {
        query = query.eq('collection_id', _selectedCollectionId!);
      }

      final response = await query.order('created_at', ascending: false);

      final List<Map<String, dynamic>> formattedPosts = [];

      final mysteryChefText = mounted 
          ? context.read<LanguageProvider>().getText('comm_chef_mystery') 
          : 'Chef Misterius';

      for (var item in response) {
        // Karena strukturnya nested (saved_posts -> posts), kita harus bongkar dulu
        final post = item['posts'];
        
        if (post != null) {
          final List likes = post['likes'] ?? [];
          final List saves = post['saved_posts'] ?? [];
          final List comments = post['comments'] ?? [];
          
          final bool isLiked = likes.any((like) => like['user_id'] == userId);
          final bool isSaved = saves.any((save) => save['user_id'] == userId);
          
          final profile = post['profiles'] ?? {};
          
          formattedPosts.add({
            ...post, // Ambil semua data post (image_url, caption, dll)
            // Gunakan nilai dari DB jika ada, fallback ke count relasi
            'like_count': post['like_count'] ?? likes.length,
            'comment_count': post['comment_count'] ?? comments.length,
            'save_count': post['save_count'] ?? saves.length,
            'is_liked': isLiked,
            'is_saved': isSaved,
            'author_name': profile['full_name'] ?? profile['username'] ?? mysteryChefText,
            'author_avatar': profile['avatar_url'],
            'saved_record_id': item['id'], // ID dari tabel saved_posts (buat hapus nanti)
          });
        }
      }

      if (mounted) {
        setState(() {
          _posts = formattedPosts;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetch saved posts: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Fitur Like
  Future<void> _toggleLike(int index, String postId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    debugPrint('[SAVED_POSTS] Sebelum toggle: postId=$postId, like_count=${_posts[index]['like_count']}, is_liked=${_posts[index]['is_liked']}');
    final isCurrentlyLiked = _posts[index]['is_liked'];
    
    setState(() {
      _posts[index]['is_liked'] = !isCurrentlyLiked;
      _posts[index]['like_count'] += isCurrentlyLiked ? -1 : 1;
    });

    debugPrint('[SAVED_POSTS] Setelah toggle: postId=$postId, like_count=${_posts[index]['like_count']}, is_liked=${_posts[index]['is_liked']}');

    try {
      if (isCurrentlyLiked) {
        await supabase.from('likes').delete().match({'user_id': userId, 'post_id': postId});
      } else {
        await supabase.from('likes').insert({'user_id': userId, 'post_id': postId});
      }
      // Fetch like_count terbaru dari DB
      final updated = await supabase.from('posts').select('like_count').eq('id', postId).maybeSingle();
      if (updated != null) {
        setState(() {
          _posts[index]['like_count'] = updated['like_count'];
        });
        debugPrint('[SAVED_POSTS] Setelah fetch DB: postId=$postId, like_count=${_posts[index]['like_count']}, is_liked=${_posts[index]['is_liked']}');
      }
    } catch (e) {
      if (mounted) {
        setState(() { // Revert UI kalo gagal
          _posts[index]['is_liked'] = isCurrentlyLiked;
        });
      }
    }
  }

  // Fitur Hapus dari Saved (Unsave)
  Future<void> _toggleSave(int index, String postId) async {
    final userId = supabase.auth.currentUser?.id;
    // final lang = context.read<LanguageProvider>();
    if (userId == null) return;

    final isCurrentlySaved = _posts[index]['is_saved'];

    if (isCurrentlySaved) {
      // Unsave
      setState(() {
        _posts[index]['is_saved'] = false;
        _posts[index]['save_count'] = ((_posts[index]['save_count'] ?? 1) - 1).clamp(0, double.infinity).toInt();
      });

      try {
        await supabase.from('saved_posts').delete().match({'user_id': userId, 'post_id': postId});
        // Update save_count via RPC
        await supabase.rpc('decrement_save_count', params: {'post_id_param': postId}).catchError((_) async {
          await supabase.from('posts').update({
            'save_count': _posts[index]['save_count']
          }).eq('id', postId);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Oke, udah dihapus dari simpanan! 👋")),
          );
        }
      } catch (e) {
        // Revert
        if (mounted) {
          setState(() {
            _posts[index]['is_saved'] = true;
            _posts[index]['save_count'] = (_posts[index]['save_count'] ?? 0) + 1;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Duh, gagal ngehapus. Coba lagi ya! 🙈")),
          );
        }
      }
    } else {
      // Save back (Undo) -> Show Dialog
      final result = await showDialog<String>(
        context: context,
        builder: (context) => SaveCollectionDialog(userId: userId),
      );

      if (result == null) return; // Dismissed

      final String? collectionId = result == 'all_posts' ? null : result;

      setState(() {
        _posts[index]['is_saved'] = true;
        _posts[index]['save_count'] = (_posts[index]['save_count'] ?? 0) + 1;
      });

      try {
        await supabase.from('saved_posts').insert({
          'user_id': userId, 
          'post_id': postId,
          'collection_id': collectionId
        });
        // Update save_count via RPC
        await supabase.rpc('increment_save_count', params: {'post_id_param': postId}).catchError((_) async {
          await supabase.from('posts').update({
            'save_count': _posts[index]['save_count']
          }).eq('id', postId);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Sip! Udah disimpen biar gak ilang! 📚")),
          );
        }
      } catch (e) {
        // Revert
        if (mounted) {
          setState(() {
            _posts[index]['is_saved'] = false;
            _posts[index]['save_count'] = ((_posts[index]['save_count'] ?? 1) - 1).clamp(0, double.infinity).toInt();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Waduh, gagal nyimpen nih. Ulangi lagi dong! 🥺")),
          );
        }
      }
    }
  }

  // --- HELPER FUNCTIONS FOR POST CARD ---
  Future<void> _handleShare(Map<String, dynamic> post, int index) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => ShareBottomSheet(
        post: post,
        index: index,
        onShareSuccess: (p, i) {}, 
      ),
    );
    if (!mounted || result == null) return;

    final lang = context.read<LanguageProvider>();

    if (result == 'image_text') {
      final String postLink = '$SHARE_BASE_URL${post['id']}';
      final String text = "Cek resep keren ini dari ${post['author_name']} di Inzara!\n\nCaption: ${post['caption'] ?? ''}\n\nLihat selengkapnya: $postLink";
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lang.getText('share_caption_copied'))),
        );
      }
      _performShare(post, index, withImage: true);
    } else if (result == 'text_only') {
      _performShare(post, index, withImage: false);
    } else if (result == 'copy_caption') {
      final String caption = post['caption'] ?? '';
      await Clipboard.setData(ClipboardData(text: caption));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.getText('share_caption_copied'))));
    } else if (result == 'copy_link') {
      _copyLink(post, index);
    }
  }

  Future<void> _performShare(Map<String, dynamic> post, int index, {bool withImage = true}) async {
    // UPDATED: Ganti domain share link
    final String postLink = '$SHARE_BASE_URL${post['id']}';
    final String text = "Cek resep keren ini dari ${post['author_name']} di Inzara!\n\nCaption: ${post['caption'] ?? ''}\n\nLihat selengkapnya: $postLink";
    final List mediaList = post['post_media'] ?? [];

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bentar ya, lagi nyiapin file... 🎨"), duration: Duration(seconds: 1)),
      );
    }

    try {
      final documentDirectory = await getTemporaryDirectory();
      List<XFile> files = [];
      for (int i = 0; i < mediaList.length; i++) {
        final media = mediaList[i];
        final url = media['url'];
        final type = media['type'];
        if (url == null) continue;
        final ext = type == 'video' ? '.mp4' : '.jpg';
        final filePath = '${documentDirectory.path}/shared_media_${i}$ext';
        final response = await http.get(Uri.parse(url));
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        final mimeType = type == 'video' ? 'video/mp4' : 'image/jpeg';
        files.add(XFile(file.path, mimeType: mimeType));
      }
      if (withImage && files.isNotEmpty) {
        await Share.shareXFiles(files, text: text);
      } else {
        await Share.share(text);
      }
      _incrementShareCount(post, index);
    } catch (e) {
      debugPrint("Gagal share media: $e");
      await Share.share(text);
      _incrementShareCount(post, index);
    }
  }

  Future<void> _copyLink(Map<String, dynamic> post, int index) async {
    // UPDATED: Ganti domain copy link
    final String postLink = '$SHARE_BASE_URL${post['id']}';
    await Clipboard.setData(ClipboardData(text: postLink));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Link udah disalin! Tinggal paste deh! 📋")),
      );
      _incrementShareCount(post, index);
    }
  }

  Future<void> _incrementShareCount(Map<String, dynamic> post, int index) async {
    setState(() {
      _posts[index]['share_count'] = (_posts[index]['share_count'] ?? 0) + 1;
    });
    
    final userId = supabase.auth.currentUser?.id;
    final postOwnerId = post['user_id'];
    
    try {
      await supabase.rpc('increment_share_count', params: {'post_id': post['id']});
      
      // FIX: Kirim notifikasi share ke pemilik postingan
      if (userId != null && postOwnerId != null && userId != postOwnerId) {
        try {
          // FIX: Tambahkan timestamp agar setiap share notification unik
          final timestamp = DateTime.now().toIso8601String();
          await supabase.from('notifications').insert({
            'user_id': postOwnerId,
            'actor_id': userId,
            'type': 'share',
            'message': 'membagikan postingan Anda.',
            'related_id': '${post['id']}|$timestamp', // Unique per share event
            'post_id': post['id'],
            'is_read': false
          });
          debugPrint("DEBUG: ✅ Share notification sent to post owner: $postOwnerId");
        } catch (e) {
          debugPrint("DEBUG: Error sending share notification: $e");
        }
      }
    } catch (e) {
      debugPrint("Error increment share: $e");
    }
  }

  void _handleOptions(Map<String, dynamic> post, int index) {
    showModalBottomSheet(
      context: context,
      builder: (context) => PostOptionsBottomSheet(
        post: post,
        index: index,
        onDelete: (postId, idx) async {
          // Logic delete post (if user owns it) or remove from saved?
          // Since this is "Saved Posts", if the user deletes their own post, it should disappear.
          // The PostOptionsBottomSheet handles checking if the user is the owner.
          
          if (post['user_id'] == supabase.auth.currentUser?.id) {
              try {
                await supabase.from('posts').delete().eq('id', postId);
                setState(() {
                  _posts.removeAt(idx);
                });
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Oke, postingan udah dihapus! 🗑️")));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Yah, gagal ngehapus. Coba lagi nanti ya! 😓")));
              }
          }
          // Note: If the user is NOT the owner, the options sheet should handle actions like Report/Unsave, 
          // but Unsave is already handled by _toggleSave via the PostCard save button.
        },
        onEditSuccess: (updatedPost, idx) {
          setState(() {
            _posts[idx] = updatedPost;
          });
        },
      ),
    );
  }

  void _handleRecookTap(int recipeId) {
    // Navigasi ke PostDetailScreen, diasumsikan PostDetailScreen handle fetch Recipe
    Navigator.pushNamed(context, AppRoutes.recipeDetailRoute, arguments: recipeId);
  }

  void _handleCommentTap(String postId) {
    Navigator.pushNamed(
      context, 
      AppRoutes.commentsRoute,
      arguments: postId, 
    );
  }

  void _handleLikesTap(String postId) {
     showModalBottomSheet(
       context: context,
       shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
       builder: (context) => LikesBottomSheet(postId: postId),
     );
  }

  String _formatTime(String? dateString) {
    if (dateString == null) return '';
    final date = DateTime.parse(dateString).toLocal();
    return timeago.format(date, locale: 'id');
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Koleksi Inspirasi", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: "Buat Koleksi Baru",
            onPressed: _createCollection,
          ),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          
          // Collections Horizontal List
          Container(
            height: 50,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCollectionId = null;
                      _fetchSavedPosts();
                    });
                  },
                  child: _buildCollectionChip("Semua Postingan", _selectedCollectionId == null, isDarkMode),
                ),
                const SizedBox(width: 8),
                if (_isLoadingCollections)
                  const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                else
                  ..._collections.map((collection) {
                    final isSelected = _selectedCollectionId == collection['id'];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedCollectionId = collection['id'];
                            _fetchSavedPosts();
                          });
                        },
                        child: _buildCollectionChip(collection['name'], isSelected, isDarkMode),
                      ),
                    );
                  }),
              ],
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await _fetchCollections();
                await _fetchSavedPosts();
              },
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _posts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.bookmark_border, size: 60, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(lang.getText('saved_empty'), style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 20),
                        itemCount: _posts.length,
                        itemBuilder: (context, index) {
                          final post = _posts[index];
                          return PostCard(
                            post: post,
                            index: index,
                            onLike: _toggleLike,
                            onSave: _toggleSave,
                            onShare: _handleShare,
                            onOptions: _handleOptions,
                            onRecookTap: _handleRecookTap,
                            onCommentTap: _handleCommentTap,
                            onLikesTap: _handleLikesTap,
                            formatTime: _formatTime,
                          );
                        },
                      ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionChip(String label, bool isSelected, bool isDarkMode) {
    return Chip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : (isDarkMode ? Colors.white70 : Colors.black87),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      backgroundColor: isSelected 
          ? Colors.orange 
          : (isDarkMode ? Colors.grey[800] : Colors.grey[200]),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}