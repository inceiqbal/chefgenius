// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:chefgenius/app/config.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../../../app/data/models/recipe_model.dart';
import '../../../app/data/providers/connectivity_provider.dart';
import '../../../app/data/providers/language_provider.dart';
import '../../../app/widgets/offline_banner.dart';
import '../../../app/config/routes.dart';
import '../widgets/post_card.dart';
import '../widgets/likes_bottom_sheet.dart';
import '../widgets/share_bottom_sheet.dart';
import '../widgets/post_options_bottom_sheet.dart';
import '../../community/providers/community_provider.dart';
import '../widgets/save_collection_dialog.dart';
import '../mixins/sanction_mixin.dart';
import '../widgets/community_app_bar.dart';
import '../widgets/community_filter_bar.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => CommunityScreenState();
}

class CommunityScreenState extends State<CommunityScreen> with SanctionMixin {
  // Pagination Variables
  final ScrollController _scrollController = ScrollController();

  // Search Variables
  bool _isSearchingMode = false;
  final TextEditingController _searchController = TextEditingController();

  // Realtime
  // _notificationChannel dihapus karena sudah dihandle global,
  // tapi _profileChannel PENTING buat update status sanksi realtime.
  RealtimeChannel? _profileChannel;

  Future<void> refresh() async {
    _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    await context.read<CommunityProvider>().refreshPosts();
    checkRestriction('check_only'); 
  }

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id', null);
    timeago.setLocaleMessages('id', timeago.IdMessages());
    
    // Initial Fetch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CommunityProvider>().refreshPosts();
    });

    checkRestriction('check_only'); 
    
    // ⭐ PENTING: Ini HARUS dipanggil buat listener Sanksi/Profil.
    // Tenang aja, listener Notifikasi di dalamnya udah kita hapus kok.
    _setupRealtimeListeners(); 
    
    _scrollController.addListener(_onScroll);
  }
  
  void _setupRealtimeListeners() {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    // --- NOTE: Listener Notifikasi SUDAH DIHAPUS dari sini ---
    // Jadi aman, gak bakal ada notifikasi ganda.

    // 2. Listen Perubahan Status Akun (Sanksi dicabut/ditambah) -> INI TETAP PENTING
    _profileChannel = supabase.channel('public:profiles:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: userId,
          ),
          callback: (payload) {
            final newRecord = payload.newRecord;
            final oldRecord = payload.oldRecord;
            
            final oldLevel = oldRecord['warning_level'] as int? ?? 0;
            final newLevel = newRecord['warning_level'] as int? ?? 0;

            if (oldLevel > 0 && newLevel == 0) {
              // Kalau sanksi dicabut admin saat user lagi buka layar ini
              if (mounted) {
                setState(() => sanctionEndTime = null);
                showSanctionOverDialog(); 
                showSanctionOverNotification(); 
              }
            } else {
              checkRestriction('check_only');
            }
          },
        )
        .subscribe();
  }

  String _formatPostTime(String? dateString) {
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
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    if (_profileChannel != null) {
      supabase.removeChannel(_profileChannel!);
    }
    super.dispose();
  }

  void _onScroll() {
    final provider = context.read<CommunityProvider>();
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !provider.isLoadingMore &&
        provider.hasMore) {
      provider.loadMorePosts();
    }
  }

  void _showLikesList(String postId) {
    debugPrint('COMMUNITY: showLikesList for postId=$postId');
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => LikesBottomSheet(postId: postId),
    );
    debugPrint('COMMUNITY: showLikesList called for postId=$postId');
  }

  Future<void> _toggleLike(int index, String postId) async {
    if (await checkRestriction('like')) return;
    
    final success = await context.read<CommunityProvider>().toggleLike(index, postId);
    if (!success && mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Gagal like postingan. Cek koneksi kamu ya!")),
       );
    }
  }

  Future<void> _deletePost(String postId, int index) async {
    try {
      await context.read<CommunityProvider>().deletePost(postId, index);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Oke, postingan udah dihapus!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Waduh, gagal hapus postingan. Coba lagi ya!")),
        );
      }
    }
  }

  void _showPostOptions(Map<String, dynamic> post, int index) {
    debugPrint('COMMUNITY: showPostOptions for postId=${post['id']} index=$index');
    showModalBottomSheet(
      context: context,
      builder: (context) => PostOptionsBottomSheet(
        post: post,
        index: index,
        onDelete: _deletePost,
        onEditSuccess: (updatedPost, idx) {
          context.read<CommunityProvider>().updatePost(idx, updatedPost); 
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Sip! Postingan berhasil diperbarui.")),
          );
        },
      ),
    );
    debugPrint('COMMUNITY: showPostOptions called for postId=${post['id']} index=$index');
  }

  Future<void> _sharePost(Map<String, dynamic> post, int index) async {
    debugPrint('COMMUNITY: sharePost requested for postId=${post['id']} index=$index');
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
    debugPrint('COMMUNITY: sharePost bottom sheet closed for postId=${post['id']} result=$result');
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
    final String postLink = '$SHARE_BASE_URL${post['id']}';
    final String text = "Cek resep keren ini dari ${post['author_name']} di Inzara!\n\nCaption: ${post['caption'] ?? ''}\n\nLihat selengkapnya: $postLink";
    final List mediaList = post['post_media'] ?? [];

    if (withImage && mediaList.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Bentar ya, lagi nyiapin file..."), duration: Duration(seconds: 1)),
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
        if (files.isNotEmpty) {
          await Share.shareXFiles(files, text: text);
        } else {
          await Share.share(text);
        }
        if (mounted) {
          context.read<CommunityProvider>().incrementShareCount(index, post['id']);
        }
      } catch (e) {
        debugPrint("Gagal share media: $e");
        await Share.share(text);
        if (mounted) {
          context.read<CommunityProvider>().incrementShareCount(index, post['id']);
        }
      }
    } else {
      // Share hanya teks & link
      await Share.share(text);
      if (mounted) {
        context.read<CommunityProvider>().incrementShareCount(index, post['id']);
      }
    }
  }

  Future<void> _copyLink(Map<String, dynamic> post, int index) async {
    final String postLink = '$SHARE_BASE_URL${post['id']}';
    await Clipboard.setData(ClipboardData(text: postLink));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Link berhasil disalin! Siap dibagikan.")),
      );
      context.read<CommunityProvider>().incrementShareCount(index, post['id']);
    }
  }

  Future<void> _toggleSave(int index, String postId) async {
    final lang = context.read<LanguageProvider>();
    if (await checkRestriction('save')) return;
    if (!mounted) return;

    final provider = context.read<CommunityProvider>();
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final isCurrentlySaved = provider.posts[index]['is_saved'];

    if (isCurrentlySaved) {
      provider.updateSaveState(index, false);

      try {
        await supabase.from('saved_posts').delete().match({'user_id': userId, 'post_id': postId});
        // Update save_count di posts
        await supabase.from('posts').update({
          'save_count': provider.posts[index]['save_count']
        }).eq('id', postId);
        try {
          await supabase.from('notifications').delete().match({
            'user_id': provider.posts[index]['user_id'],
            'actor_id': userId,
            'related_id': postId,
            'type': 'save'
          });
        } catch (e) {
          debugPrint("Gagal hapus notifikasi save: $e");
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.getText('comm_unsaved'))));
        }
      } catch (e) {
        provider.revertSaveState(index, true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.getText('comm_save_error'))));
        }
      }
    } else {
      final result = await showDialog<String>(
        context: context,
        builder: (context) => SaveCollectionDialog(userId: userId),
      );

      if (result == null) return; 

      final String? collectionId = result == 'all_posts' ? null : result;

      provider.updateSaveState(index, true);

      try {
        // Gunakan upsert agar tidak error jika data sudah ada (misal sinkronisasi delay)
        await supabase.from('saved_posts').upsert({
          'user_id': userId, 
          'post_id': postId,
          'collection_id': collectionId
        });
        // Update save_count di posts
        await supabase.from('posts').update({
          'save_count': provider.posts[index]['save_count']
        }).eq('id', postId);
        
        final postOwnerId = provider.posts[index]['user_id'];
        if (postOwnerId != userId) {
           try {
             // Gunakan insert biasa untuk memastikan notifikasi terkirim
             await supabase.from('notifications').insert({
               'user_id': postOwnerId,
               'actor_id': userId,
               'type': 'save',
               'message': 'menyimpan postingan Anda.',
               'related_id': postId,
               'post_id': postId, 
               'is_read': false
             });
           } catch (e) {
             debugPrint("Gagal kirim notifikasi save: $e");
           }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.getText('comm_saved'))));
        }
      } catch (e) {
        debugPrint("Error saving post: $e");
        provider.revertSaveState(index, false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.getText('comm_save_error'))));
        }
      }
    }
  }

  Future<void> _navigateToRecipe(int recipeId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator(color: Colors.orange)),
    );

    try {
      final response = await supabase
          .from('recipes')
          .select()
          .eq('id', recipeId)
          .single();

      if (!mounted) return;
      Navigator.pop(context); 

      final recipe = Recipe.fromJson(response);
      Navigator.pushNamed(context, AppRoutes.recipeDetailRoute, arguments: recipe);

    } catch (e) {
      if (mounted) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Yah, resepnya gak bisa dibuka. Coba lagi nanti ya!")),
        );
      }
    }
  }

  Widget _buildUserSearchResults(List<Map<String, dynamic>> users) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'Pengguna',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return GestureDetector(
                onTap: () {
                    Navigator.pushNamed(
                    context, 
                    AppRoutes.profileRoute, 
                    arguments: user['id']
                  );
                },
                child: Container(
                  width: 80,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundImage: user['avatar_url'] != null 
                            ? NetworkImage(user['avatar_url']) 
                            : null,
                        child: user['avatar_url'] == null 
                            ? const Icon(Icons.person) 
                            : null,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user['username'] ?? 'User',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(),
      ],
    );
  }

  // Modern Empty State
  Widget _buildModernEmptyState(BuildContext context, LanguageProvider lang, bool isDarkMode) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated icon container
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.9, end: 1.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(scale: value, child: child);
              },
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDarkMode
                        ? [const Color(0xFF2A2520).withOpacity(0.5), const Color(0xFF1E1A18).withOpacity(0.3)]
                        : [Colors.orange.shade50, Colors.orange.shade100.withOpacity(0.5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.1),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(Icons.photo_camera_rounded, size: 50, color: Colors.orange),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              lang.getText('comm_empty'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ayo mulai berbagi masakan pertamamu! 🍳',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 20),
            // Food emojis decoration
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              children: ['📸', '🍽️', '👨‍🍳', '🍕', '🥗'].map((emoji) {
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 400 + (emoji.hashCode % 300)),
                  curve: Curves.bounceOut,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 15 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 20)),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOffline = context.watch<ConnectivityProvider>().isOffline;
    final lang = context.watch<LanguageProvider>();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
      appBar: CommunityAppBar(
        isSearchingMode: _isSearchingMode,
        searchController: _searchController,
        onSearchClose: () {
          setState(() {
            _isSearchingMode = false;
            _searchController.clear();
            context.read<CommunityProvider>().setSearchQuery('');
          });
        },
        onSearchTap: () {
          setState(() {
            _isSearchingMode = true;
          });
        },
        onUploadPressed: () async {
          if (await checkRestriction('upload')) return;
          if (!mounted) return;

          final result = await Navigator.pushNamed(context, AppRoutes.uploadPostRoute);
          if (result == true) {
            context.read<CommunityProvider>().refreshPosts();
          }
        },
        sanctionEndTime: sanctionEndTime,
        remainingTime: formatRemainingTime(),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDarkMode
                ? [const Color(0xFF1A1A2E), const Color(0xFF16213E), const Color(0xFF0F0F1A)]
                : [const Color(0xFFFFF8F0), const Color(0xFFFFF5EB), const Color(0xFFFFFFFF)],
          ),
        ),
        child: Column(
          children: [
            const OfflineBanner(),
            
            if (!isOffline) const CommunityFilterBar(),

            Expanded(
              child: isOffline 
                ? Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.wifi_off_rounded, size: 50, color: Colors.grey),
                      ),
                      const SizedBox(height: 20),
                      Text(lang.getText('comm_offline_title'), style: const TextStyle(color: Colors.grey, fontSize: 16)),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE67E22), Color(0xFFD35400)],
                          ),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(25),
                            onTap: () => context.read<CommunityProvider>().refreshPosts(),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              child: Text(lang.getText('comm_retry'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ))
                : RefreshIndicator(
                    onRefresh: () => context.read<CommunityProvider>().refreshPosts(),
                    color: Colors.orange,
                    backgroundColor: isDarkMode ? Colors.grey[800] : Colors.white,
                    child: Consumer<CommunityProvider>(
                      builder: (context, provider, child) {
                        return provider.isLoading 
                          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
                          : provider.posts.isEmpty && provider.users.isEmpty
                            ? _buildModernEmptyState(context, lang, isDarkMode)
                            : ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.only(bottom: 80, top: 8),
                                itemCount: provider.posts.length + (provider.hasMore ? 1 : 0) + (provider.users.isNotEmpty ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (provider.users.isNotEmpty) {
                                    if (index == 0) {
                                      return _buildUserSearchResults(provider.users);
                                    }
                                    index--;
                                  }

                                  if (index == provider.posts.length) {
                                    return const Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: Center(child: CircularProgressIndicator(color: Colors.orange)),
                                    );
                                  }
                                  return PostCard(
                                    post: provider.posts[index],
                                    index: index,
                                    onLike: _toggleLike,
                                    onSave: _toggleSave,
                                    onShare: _sharePost,
                                    onOptions: _showPostOptions,
                                    onRecookTap: _navigateToRecipe,
                                    onCommentTap: (postId) {
                                      Navigator.pushNamed(
                                        context, 
                                        AppRoutes.commentsRoute,
                                        arguments: postId,
                                      );
                                    },
                                    onLikesTap: _showLikesList,
                                    formatTime: _formatPostTime,
                                  );
                                },
                              );
                      },
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}