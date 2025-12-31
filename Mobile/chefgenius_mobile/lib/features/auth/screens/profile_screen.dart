import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart'; 
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:chefgenius/app/config.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../../app/config/routes.dart';
import '../../../app/data/providers/language_provider.dart'; 
import '../../../app/data/providers/generated_recipe_provider.dart'; 
import '../../community/widgets/share_bottom_sheet.dart'; 
import '../../community/widgets/save_collection_dialog.dart';
import '../../community/widgets/report_dialog.dart';
import '../widgets/profile_header.dart';
import '../widgets/profile_drawer.dart';
import '../widgets/profile_posts_grid.dart';
import '../widgets/post_detail_sheet.dart';
import '../../community/providers/community_provider.dart';
import '../../../app/data/providers/notification_provider.dart';

class ProfileScreen extends StatefulWidget {
  final String? email;
  final String? userId; // Added userId
  final String? initialPostId; // Baru: ID Postingan buat Auto-Open
  final bool isFromDeepLink; // FIX: Explicit flag untuk deep link

  const ProfileScreen({super.key, this.email, this.userId, this.initialPostId, this.isFromDeepLink = false});

  @override
  State<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  StreamSubscription? _sub;
  RealtimeChannel? _postsRealtimeChannel;
  final supabase = Supabase.instance.client;
  bool _launchedFromDeepLink = false; // true when opened because of a deep link
  // Track whether a post detail bottom sheet is currently open
  bool _isPostDetailOpen = false;
  Future<dynamic>? _currentPostDetailFuture;

  // Data profil yang sedang dilihat
  String? _fullName;
  String? _username;
  String? _avatarUrl;
  String? _bio;
  String? _email;

  // Data user login (untuk sidebar)
  String? _myFullName;
  String? _myUsername;
  // String? _myEmail; // Removed email display logic

  List<Map<String, dynamic>> _userPosts = [];
  bool _isLoadingPosts = true;
  bool _isOwnProfile = false;

  // FIXED TOGGLE LIKE FUNCTION (Updated for Partial Index DB)
  Future<void> _toggleLike(Map<String, dynamic> post) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final isCurrentlyLiked = post['is_liked'] == true;
    final prevLikeCount = post['like_count'] ?? 0;

    debugPrint('[PROFILE_SCREEN] ========== TOGGLE LIKE START ==========');
    debugPrint('[PROFILE_SCREEN] Post ID: ${post['id']}');
    debugPrint('[PROFILE_SCREEN] Before: like_count=$prevLikeCount, is_liked=$isCurrentlyLiked');

    try {
      if (isCurrentlyLiked) {
        // ========== UNLIKE ==========
        debugPrint('[PROFILE_SCREEN] Action: UNLIKE');

        // 1. Delete dari likes table
        await supabase.from('likes').delete().match({
          'user_id': userId, 
          'post_id': post['id']
        });
        debugPrint('[PROFILE_SCREEN] ✅ Deleted from likes table');

        // 2. Delete notification
        try {
          await supabase.from('notifications').delete().match({
            'user_id': post['user_id'],
            'actor_id': userId,
            'related_id': post['id'],
            'type': 'like'
          });
          debugPrint('[PROFILE_SCREEN] ✅ Deleted notification');
        } catch (e) {
          debugPrint('[PROFILE_SCREEN] ⚠️ Failed to delete notification: $e');
        }

        // 3. Update local state
        setState(() {
          post['is_liked'] = false;
          post['like_count'] = prevLikeCount - 1;
        });
      } else {
        // ========== LIKE ==========
        debugPrint('[PROFILE_SCREEN] Action: LIKE');

        // 1. Check if like already exists (prevent duplicate insert error)
        final existing = await supabase
            .from('likes')
            .select('id')
            .eq('user_id', userId)
            .eq('post_id', post['id'])
            .maybeSingle();

        if (existing == null) {
          // 2. Insert ke likes table
          await supabase.from('likes').insert({
            'user_id': userId, 
            'post_id': post['id']
          });
          debugPrint('[PROFILE_SCREEN] ✅ Inserted to likes table');
        } else {
          debugPrint('[PROFILE_SCREEN] ⚠️ Like already exists, skipping insert');
        }

        // 3. Create notification (Updated Logic for New DB Constraints)
        final postOwnerId = post['user_id'];
        if (postOwnerId != null && postOwnerId != userId) {
          try {
            // Gunakan insert biasa. Karena kita pakai partial index di DB (WHERE comment_id IS NULL),
            // constraint 'user_id, actor_id, related_id, type' mungkin tidak terbaca oleh .upsert() standar SDK.
            // Jadi lebih aman pakai insert() + catch error duplikat.
            await supabase.from('notifications').insert({
              'user_id': postOwnerId,
              'actor_id': userId,
              'type': 'like',
              'message': 'menyukai postingan Anda.',
              'related_id': post['id'],
              'post_id': post['id'],
              'is_read': false
            });
            debugPrint('[PROFILE_SCREEN] ✅ Created notification');
          } catch (e) {
            // Abaikan error duplicate key (23505), artinya notif udah ada.
            if (e.toString().contains('23505') || e.toString().contains('unique constraint')) {
               debugPrint('[PROFILE_SCREEN] ℹ️ Notification already exists (Duplicate ignored)');
            } else {
               debugPrint('[PROFILE_SCREEN] ⚠️ Failed to create notification: $e');
            }
          }
        }

        // 4. Update local state
        setState(() {
          post['is_liked'] = true;
          post['like_count'] = prevLikeCount + 1;
        });
      }

      // 5. Verify dari database (WITH DELAY 500ms)
      await Future.delayed(const Duration(milliseconds: 500));

      final verified = await supabase
          .from('posts')
          .select('like_count')
          .eq('id', post['id'])
          .maybeSingle();

      if (verified != null) {
        final dbLikeCount = verified['like_count'] as int;
        debugPrint('[PROFILE_SCREEN] ✅ DB Verification: like_count=$dbLikeCount');
        
        // Sync jika beda
        if (post['like_count'] != dbLikeCount) {
          debugPrint('[PROFILE_SCREEN] ⚠️ Mismatch! Syncing from DB...');
          setState(() {
            post['like_count'] = dbLikeCount;
          });
        }
      }

      // 6. Update CommunityProvider biar sinkron sama Beranda
      try {
        final communityProvider = context.read<CommunityProvider>();
        final idx = communityProvider.posts.indexWhere((p) => p['id'] == post['id']);
        if (idx != -1) {
          communityProvider.updatePost(idx, {
            ...communityProvider.posts[idx],
            'is_liked': post['is_liked'],
            'like_count': post['like_count'],
          });
        }
      } catch (e) {
        debugPrint('[PROFILE_SCREEN] ⚠️ CommunityProvider not available: $e');
      }

      debugPrint('[PROFILE_SCREEN] After: like_count=${post['like_count']}, is_liked=${post['is_liked']}');
      debugPrint('[PROFILE_SCREEN] ========== TOGGLE LIKE SUCCESS ==========');
    } catch (e, st) {
      debugPrint('[PROFILE_SCREEN] ❌ ========== TOGGLE LIKE FAILED ==========');
      debugPrint('[PROFILE_SCREEN] ❌ Error: $e');
      debugPrint('[PROFILE_SCREEN] ❌ Stack trace: $st');
      
      // Revert state
      setState(() {
        post['is_liked'] = isCurrentlyLiked;
        post['like_count'] = prevLikeCount;
      });
      
      if (mounted) {
        final lang = context.read<LanguageProvider>();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lang.getText('like_failed'))),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // FIX: Gunakan parameter explicit isFromDeepLink, bukan tebak dari initialPostId
    _launchedFromDeepLink = widget.isFromDeepLink;
    _checkIsOwnProfile();
    _fetchProfileData();
    _fetchUserPosts();
    _fetchMyProfileData();

    if (widget.initialPostId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Delay dikit biar UI profil ke-render dulu
        Future.delayed(const Duration(milliseconds: 300), () {
           if (mounted) _openPostDetailById(widget.initialPostId!);
        });
      });
    }

    // --- REALTIME SUBSCRIPTION UNTUK POSTS ---
    final targetUserId = widget.userId ?? supabase.auth.currentUser?.id;
    if (targetUserId != null) {
      _postsRealtimeChannel = supabase.channel('public:posts:user:$targetUserId');
      _postsRealtimeChannel!.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'posts',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: targetUserId,
        ),
        callback: (payload) {
          // Logic update realtime count
          final newData = payload.newRecord;
          // Handle delete case (newRecord is empty)
          if (newData.isEmpty) return;
          
          final postId = newData['id'];
          final idx = _userPosts.indexWhere((p) => p['id'] == postId);
          if (idx != -1) {
            setState(() {
              _userPosts[idx]['like_count'] = newData['like_count'] ?? _userPosts[idx]['like_count'];
              _userPosts[idx]['comment_count'] = newData['comment_count'] ?? _userPosts[idx]['comment_count'];
              _userPosts[idx]['save_count'] = newData['save_count'] ?? _userPosts[idx]['save_count'];
              _userPosts[idx]['share_count'] = newData['share_count'] ?? _userPosts[idx]['share_count'];
            });
          }
        },
      );
      _postsRealtimeChannel!.subscribe();
    }

    // Listen for deep links
    _sub = AppLinks().uriLinkStream.listen((Uri? uri) {
      if (uri != null && uri.pathSegments.length == 2 && uri.pathSegments[0] == 'post') {
        final postId = uri.pathSegments[1];
        final post = _userPosts.firstWhere(
          (p) => p['id'].toString() == postId,
          orElse: () => <String, dynamic>{},
        );
        if (post.isNotEmpty) {
          _showPostDetail(post, _isOwnProfile);
        } else {
          _openPostDetailById(postId);
        }
      }
    }, onError: (err) {
      debugPrint('Deep link error: $err');
    });
  }

  Future<void> _fetchMyProfileData() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final data = await supabase
          .from('profiles')
          .select('full_name, username')
          .eq('id', userId)
          .maybeSingle();
      
      // Gak perlu logic restore disini, biar _fetchProfileData yang handle
      // kalau ini profile sendiri.
      if (mounted) {
        setState(() {
          _myFullName = data?['full_name'];
          _myUsername = data?['username'];
          // _myEmail = supabase.auth.currentUser?.email; // No need to store email for display
        });
      }
    } catch (e) {
      debugPrint('Error fetching my profile for drawer: $e');
    }
  }

  void _checkIsOwnProfile() {
    final currentUserId = supabase.auth.currentUser?.id;
    if (widget.userId != null && widget.userId != currentUserId) {
      _isOwnProfile = false;
    } else {
      _isOwnProfile = true;
    }
  }

  Future<void> refresh() async {
    await _fetchProfileData();
    await _fetchUserPosts();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _postsRealtimeChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _openPostDetailById(String postId) async {
    // Cek dulu apakah post ada di list yg udah di-load (Optimasi)
    final existingPost = _userPosts.firstWhere(
      (p) => p['id'].toString() == postId,
      orElse: () => <String, dynamic>{},
    );

    if (existingPost.isNotEmpty) {
      _showPostDetail(existingPost, _isOwnProfile);
      return;
    }

    // Kalau gak ada di list (misal di page bawah), fetch manual
    try {
      final data = await supabase
          .from('posts')
          .select('*, post_media(*), likes(user_id), comments(id), saved_posts(user_id)')
          .eq('id', postId)
          .maybeSingle();
      if (data != null) {
          final currentUserId = supabase.auth.currentUser?.id;
        final List likes = data['likes'] ?? [];
        final List comments = data['comments'] ?? [];
        final List saves = data['saved_posts'] ?? [];
        final post = {
          ...data,
          'like_count': data['like_count'] ?? likes.length,
          'comment_count': data['comment_count'] ?? comments.length,
          'save_count': data['save_count'] ?? saves.length,
          'is_liked': likes.any((l) => l['user_id'] == currentUserId),
          'is_saved': saves.any((s) => s['user_id'] == currentUserId),
        };
          // Jika post bukan milik profil yang sedang dilihat, navigasi ke profil pemilik dulu
          final postOwnerId = data['user_id']?.toString();
          final currentProfileId = widget.userId ?? supabase.auth.currentUser?.id;

          if (postOwnerId != null && currentProfileId != null && postOwnerId != currentProfileId.toString()) {
            // Tutup sheet yang mungkin masih terbuka
            if (_isPostDetailOpen) {
              try { Navigator.pop(context); } catch (_) {}
              await Future.delayed(const Duration(milliseconds: 200));
            }

            // Navigasi ke ProfileScreen pemilik postingan dan biarkan ProfileScreen membuka sheet otomatis
            if (mounted) {
              debugPrint('NAVIGATE_TO_OWNER_PROFILE: postId=${post['id']} owner=$postOwnerId currentProfile=$currentProfileId');
              Navigator.pushNamed(
                context,
                AppRoutes.profileRoute,
                arguments: {
                  'userId': postOwnerId,
                  'initialPostId': post['id'].toString(),
                },
              );
            }
            return;
          }

          // PENTING: Tambahin info profil ke post biar header sheet-nya bener (jika ini profil pemilik)
          post['profiles'] = {
            'full_name': _fullName ?? data['profiles']?['full_name'] ?? data['author_name'],
            'username': _username ?? data['profiles']?['username'] ?? data['author_name'],
            'avatar_url': _avatarUrl ?? data['profiles']?['avatar_url'] ?? data['author_avatar'],
          };

          _showPostDetail(post, _isOwnProfile);
      } else {
        if (mounted) {
          final lang = context.read<LanguageProvider>();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(lang.getText('post_not_found'))),
          );
        }
      }
    } catch (e) {
      debugPrint('Gagal fetch post by id: $e');
      if (mounted) {
        final lang = context.read<LanguageProvider>();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lang.getText('open_post_failed'))),
        );
      }
    }
  }

  // --- LOGIC BARU: FETCH + SELF-HEALING ---
  Future<void> _fetchProfileData() async {
    if (!mounted) return;

    try {
      final targetUserId = widget.userId ?? supabase.auth.currentUser?.id;
      if (targetUserId == null) return;

      if (!_isOwnProfile) {
        // Logic biasa buat profil orang lain
      } else {
        _email = supabase.auth.currentUser?.email;
      }

      var data = await supabase
          .from('profiles')
          .select('full_name, username, avatar_url, bio')
          .eq('id', targetUserId)
          .maybeSingle();

      // -------------------------------------------------------------
      // SELF-HEALING LOGIC
      // Kalau data di DB kosong DAN ini profil saya sendiri,
      // Coba pulihkan data dari Metadata Auth (Saku Cadangan).
      // -------------------------------------------------------------
      if (data == null && _isOwnProfile) {
        debugPrint("⚠️ Profile DB kosong. Mencoba restore dari Metadata...");
        
        final user = supabase.auth.currentUser;
        if (user != null) {
          final metaName = user.userMetadata?['full_name'];
          // Kalau ada nama di saku cadangan, kita pakai!
          if (metaName != null) {
              final newUsername = user.email?.split('@')[0] ?? 'user';
              
              // 1. Update UI Instan (Biar user gak nunggu loading)
              if (mounted) {
                setState(() {
                  _fullName = metaName;
                  _username = newUsername;
                  _email = user.email;
                });
              }

              // 2. Simpan ke DB (Silent Background Process)
              await supabase.from('profiles').upsert({
                'id': user.id,
                'full_name': metaName,
                'username': newUsername,
                'updated_at': DateTime.now().toIso8601String(),
              });
              debugPrint("✅ Sukses Self-Healing Profile!");
              return; // Keluar, gak perlu fetch lagi
          }
        }
      }
      // -------------------------------------------------------------

      if (mounted && data != null) {
        setState(() {
          _fullName = data['full_name'];
          _username = data['username'];
          _avatarUrl = data['avatar_url'];
          _bio = data['bio'];
        });
      }
    } catch (e) {
      debugPrint("Error fetching profile: $e");
    }
  }

  Future<void> _fetchUserPosts() async {
    try {
      final targetUserId = widget.userId ?? supabase.auth.currentUser?.id;
      if (targetUserId == null) return;

      final response = await supabase
          .from('posts')
          .select('*, post_media(*), likes(user_id), comments(id), saved_posts(user_id)')
          .eq('user_id', targetUserId)
          .order('created_at', ascending: false);

      if (mounted) {
        final currentUserId = supabase.auth.currentUser?.id;
        final List<Map<String, dynamic>> formatted = [];
        for (var post in response) {
          final List likes = post['likes'] ?? [];
          final List comments = post['comments'] ?? [];
          final List saves = post['saved_posts'] ?? [];

          formatted.add({
            ...post,
            'like_count': post['like_count'] ?? 0,
            'comment_count': post['comment_count'] ?? comments.length,
            'save_count': post['save_count'] ?? saves.length,
            'is_liked': likes.any((l) => l['user_id'] == currentUserId),
            'is_saved': saves.any((s) => s['user_id'] == currentUserId),
          });
        }

        setState(() {
          _userPosts = formatted;
          _userPosts.sort((a, b) {
            final bool aPinned = a['is_pinned'] ?? false;
            final bool bPinned = b['is_pinned'] ?? false;
            if (aPinned && !bPinned) return -1;
            if (!aPinned && bPinned) return 1;
            return 0;
          });
          _isLoadingPosts = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetch user posts: $e");
      if (mounted) setState(() => _isLoadingPosts = false);
    }
  }

  Future<void> _togglePin(String postId, bool currentStatus) async {
    if (!currentStatus) {
      final pinnedCount = _userPosts.where((p) => p['is_pinned'] == true).length;
      if (pinnedCount >= 3) {
        final lang = context.read<LanguageProvider>();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lang.getText('pin_limit'))),
        );
        return;
      }
    }

    try {
      await supabase.from('posts').update({'is_pinned': !currentStatus}).eq('id', postId);
      await _fetchUserPosts(); 
    } catch (e) {
      if (mounted) {
        final lang = context.read<LanguageProvider>();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lang.getText('pin_failed'))),
        );
      }
    }
  }

  int _calculateTotalLikes() {
    int total = 0;
    for (var post in _userPosts) {
      total += (post['like_count'] as int? ?? 0);
    }
    return total;
  }

  void _showLogoutDialog(BuildContext parentContext) {
    final lang = parentContext.read<LanguageProvider>();
    showDialog(
      context: parentContext,
      builder: (dialogContext) => AlertDialog(
        title: Text(lang.getText('logout_confirm_title')),
        content: Text(lang.getText('logout_confirm_desc')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(lang.getText('cancel')),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              
              if (parentContext.mounted) {
                ScaffoldMessenger.of(parentContext).showSnackBar(
                  SnackBar(
                    content: Text(lang.getText('logout_wait')),
                    duration: const Duration(seconds: 1),
                  ),
                );
              }

              try {
                final recipeProvider = parentContext.read<GeneratedRecipeProvider>();
                recipeProvider.clearData();
                
                // FIX: Reset notification provider before logout to prevent badge leaking to other accounts
                parentContext.read<NotificationProvider>().reset();
                
                await supabase.auth.signOut().timeout(
                  const Duration(seconds: 3),
                  onTimeout: () {
                    debugPrint("Logout timed out, forcing local logout");
                  },
                );
              } catch (e) {
                debugPrint("Logout error: $e");
              } finally {
                if (parentContext.mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                    parentContext, 
                    AppRoutes.loginRoute, 
                    (route) => false
                  );
                }
              }
            },
            child: Text(lang.getText('logout_btn'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAvatarDialog() {
    if (_avatarUrl == null) return;
    final isAsset = _avatarUrl!.startsWith('asset:') || _avatarUrl!.startsWith('assets/');
    String imagePath = _avatarUrl!;
    if (_avatarUrl!.startsWith('asset:')) imagePath = _avatarUrl!.substring(6).trim();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4,
              child: isAsset
                  ? Image.asset(imagePath, fit: BoxFit.contain)
                  : CachedNetworkImage(
                      imageUrl: _avatarUrl!,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                      errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.white, size: 50),
                    ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final lang = context.watch<LanguageProvider>();

    return WillPopScope(
      onWillPop: () async {
        if (_launchedFromDeepLink) {
          // FIX: Jika dari deep-link, navigasi ke halaman utama alih-alih keluar aplikasi
          final email = supabase.auth.currentUser?.email ?? '';
          Navigator.pushReplacementNamed(context, AppRoutes.pantryRoute, arguments: email);
          return false;
        }
        return true;
      },
      child: Scaffold(
      backgroundColor: backgroundColor,
      endDrawer: ProfileDrawer(
        fullName: _myFullName,
        username: _myUsername,
        email: Supabase.instance.client.auth.currentUser?.email ?? '',
        onLogout: () => _showLogoutDialog(context),
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 0,
              floating: true,
              pinned: true,
              backgroundColor: backgroundColor,
              elevation: 0,
              title: Text(
                _isOwnProfile
                    ? lang.getText('profile_title')
                    : lang.getText('profile'),
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              centerTitle: false,
              actions: [
                if (_isOwnProfile)
                  Builder(
                    builder: (context) => IconButton(
                      icon: const Icon(Icons.menu_rounded),
                      onPressed: () => Scaffold.of(context).openEndDrawer(),
                    ),
                  ),
              ],
            ),
            // Tambahkan section Data Pribadi Anda
            // Data Pribadi Anda section with email removed
            SliverToBoxAdapter(
              child: ProfileHeader(
                fullName: _fullName,
                username: _username,
                email: '', // Jangan tampilkan email di header
                avatarUrl: _avatarUrl,
                bio: _bio,
                postCount: _userPosts.length,
                totalLikes: _calculateTotalLikes(),
                isOwnProfile: _isOwnProfile,
                onEditProfile: () async {
                  if (!_isOwnProfile) return;
                  await Navigator.pushNamed(context, AppRoutes.editProfileRoute, arguments: widget.email ?? _email);
                  _fetchProfileData();
                },
                onShowAvatar: _showAvatarDialog,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              sliver: ProfilePostsGrid(
                posts: _userPosts,
                isLoading: _isLoadingPosts,
                isMyPost: _isOwnProfile,
                onPostTap: (post) => _showPostDetail(post, _isOwnProfile),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ),
      ),
      ),
    );
  }

  // --- HELPER FUNCTIONS FOR POST DETAIL ---
  Future<void> _toggleSave(Map<String, dynamic> post, bool isMyPost, {bool closeSheet = false}) async {
    final userId = supabase.auth.currentUser?.id;
    final lang = context.read<LanguageProvider>();
    if (userId == null) return;

    final isCurrentlySaved = post['is_saved'] == true;
    final postId = post['id'].toString();

    if (isCurrentlySaved) {
      // Unsave
      setState(() {
        post['is_saved'] = false;
        post['save_count'] = ((post['save_count'] ?? 1) - 1).clamp(0, double.infinity).toInt();
      });
      
      if (closeSheet && mounted) Navigator.pop(context);

      try {
        await supabase.from('saved_posts').delete().match({'user_id': userId, 'post_id': postId});
        await supabase.rpc('decrement_save_count', params: {'post_id_param': postId}).catchError((_) {});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(lang.getText('comm_unsaved'))),
          );
        }
      } catch (e) {
        // Revert
        if (mounted) {
          setState(() {
            post['is_saved'] = true;
            post['save_count'] = (post['save_count'] ?? 0) + 1;
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.getText('save_failed'))));
        }
      }
    } else {
      // Save -> Show Dialog
      final result = await showDialog<String>(
        context: context,
        builder: (context) => SaveCollectionDialog(userId: userId),
      );

      if (result == null) return; 

      final String? collectionId = result == 'all_posts' ? null : result;

      setState(() {
        post['is_saved'] = true;
        post['save_count'] = (post['save_count'] ?? 0) + 1;
      });
      
      if (closeSheet && mounted) Navigator.pop(context);

      try {
        await supabase.from('saved_posts').insert({
          'user_id': userId, 
          'post_id': postId,
          'collection_id': collectionId
        });
        await supabase.rpc('increment_save_count', params: {'post_id_param': postId}).catchError((_) {});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(lang.getText('comm_saved'))),
          );
        }
      } catch (e) {
        // Revert
        if (mounted) {
          setState(() {
            post['is_saved'] = false;
            post['save_count'] = ((post['save_count'] ?? 1) - 1).clamp(0, double.infinity).toInt();
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.getText('save_failed'))));
        }
      }
    }
  }

  Future<void> _handleShare(Map<String, dynamic> post) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => ShareBottomSheet(
        post: post,
        index: 0, 
        onShareSuccess: (p, i) {}, 
      ),
    );
    if (!mounted || result == null) return;

    final lang = context.read<LanguageProvider>();

    if (result == 'image_text') {
      // Auto-copy caption + link so user can paste as Instagram caption
      final String postLink = '$SHARE_BASE_URL${post['id']}';
      final String captionText = "Cek resep keren ini dari ${post['profiles']?['full_name'] ?? post['profiles']?['username'] ?? 'Chef'} di Inzara!\n\nCaption: ${post['caption'] ?? ''}\n\nLihat selengkapnya: $postLink";
      await Clipboard.setData(ClipboardData(text: captionText));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lang.getText('share_caption_copied'))),
        );
      }
      await _performShare(post, withImage: true);
    } else if (result == 'text_only') {
      await _performShare(post, withImage: false);
    } else if (result == 'copy_caption') {
      final String caption = post['caption'] ?? '';
      await Clipboard.setData(ClipboardData(text: caption));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.getText('share_caption_copied'))));
    } else if (result == 'copy_link') {
      _copyLink(post);
    }
  }

  Future<void> _performShare(Map<String, dynamic> post, {bool withImage = true}) async {
    final String postLink = '$SHARE_BASE_URL${post['id']}';
    final String text = "Cek resep keren ini dari ${post['profiles']?['full_name'] ?? post['profiles']?['username'] ?? 'Chef'} di Inzara!\n\nCaption: ${post['caption'] ?? ''}\n\nLihat selengkapnya: $postLink";
    final List mediaList = post['post_media'] ?? [];

    if (mounted) {
      final lang = context.read<LanguageProvider>();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lang.getText('share_preparing')), duration: const Duration(seconds: 1)),
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
      _incrementShareCount(post);
    } catch (e) {
      debugPrint("Gagal share media: $e");
      await Share.share(text);
      _incrementShareCount(post);
    }
  }

  Future<void> _deletePost(String postId) async {
    final lang = context.read<LanguageProvider>();
    try {
      // Optimistically remove from UI
      setState(() {
        _userPosts.removeWhere((p) => p['id'].toString() == postId.toString());
      });

      // Cleanup related notifications first to avoid FK issues
      try {
        await supabase.from('notifications').delete().eq('post_id', postId);
      } catch (e) {
        debugPrint('Warning: failed to cleanup notifications before deleting post: $e');
      }

      await supabase.from('posts').delete().eq('id', postId);

      // Also remove from CommunityProvider if present
      try {
        final communityProvider = context.read<CommunityProvider>();
        final idx = communityProvider.posts.indexWhere((p) => p['id'].toString() == postId.toString());
        if (idx != -1) {
          await communityProvider.deletePost(postId, idx);
        }
      } catch (e) {
        debugPrint('Warning: failed to remove post from CommunityProvider: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lang.getText('post_delete_success')), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint('Failed to delete post $postId: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lang.getText('post_delete_failed'))),
        );
      }
    }
  }

  Future<void> _copyLink(Map<String, dynamic> post) async {
    final String postLink = '$SHARE_BASE_URL${post['id']}';
    await Clipboard.setData(ClipboardData(text: postLink));
    if (mounted) {
      final lang = context.read<LanguageProvider>();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lang.getText('link_copied'))),
      );
      _incrementShareCount(post);
    }
  }

  Future<void> _incrementShareCount(Map<String, dynamic> post) async {
    setState(() {
      post['share_count'] = (post['share_count'] ?? 0) + 1;
    });
    try {
      await supabase.rpc('increment_share_count', params: {'post_id': post['id']});
    } catch (e) {
      debugPrint("Error increment share: $e");
    }
  }

  Future<void> _reportPost(Map<String, dynamic> post) async {
    final lang = context.read<LanguageProvider>();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ReportDialog(
        postId: post['id'].toString(),
        reportedUserId: post['user_id'].toString(),
      ),
    );
    
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lang.getText('report_success')),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _showPostDetail(Map<String, dynamic> post, bool isMyPost) async {
    // Ensure post contains `profiles` map so header shows correct name/avatar
    final displayedPost = Map<String, dynamic>.from(post);
    if (displayedPost['profiles'] == null || (displayedPost['profiles'] is Map && ((displayedPost['profiles']['full_name'] == null || displayedPost['profiles']['full_name'] == '') && (displayedPost['profiles']['username'] == null || displayedPost['profiles']['username'] == '')))) {
      displayedPost['profiles'] = {
        'full_name': displayedPost['profiles']?['full_name'] ?? _fullName ?? displayedPost['author_name'] ?? displayedPost['profiles']?['username'] ?? 'Chef',
        'username': displayedPost['profiles']?['username'] ?? _username ?? (displayedPost['author_name'] ?? '').toString(),
        'avatar_url': displayedPost['profiles']?['avatar_url'] ?? _avatarUrl ?? displayedPost['author_avatar'],
      };
    }

    debugPrint('OPEN_POST_DETAIL: id=${displayedPost['id']} owner=${displayedPost['user_id']} isMyPost=$isMyPost isPostDetailOpen=$_isPostDetailOpen');

    // If a post detail sheet is already open, close it first to avoid stacking
    if (_isPostDetailOpen) {
      debugPrint('CLOSING existing post detail sheet before opening new one');
      try {
        Navigator.pop(context);
      } catch (_) {}
      // Give the sheet a short moment to dismiss
      await Future.delayed(const Duration(milliseconds: 200));
    }

    _isPostDetailOpen = true;
    _currentPostDetailFuture = showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => PostDetailSheet(
        post: displayedPost,
        isMyPost: isMyPost,
        onPin: () {
          Navigator.pop(sheetContext);
          _togglePin(post['id'].toString(), post['is_pinned'] ?? false);
        },
        onSave: () {
          Navigator.pop(sheetContext);
          _toggleSave(post, isMyPost);
        },
        onShare: () => _handleShare(post),
        onComment: () {
          Navigator.pushNamed(
            context,
            AppRoutes.commentsRoute,
            arguments: post['id'].toString(),
          );
        },
        onReport: isMyPost ? null : () {
          Navigator.pop(sheetContext);
          _reportPost(post);
        },
        onEditSuccess: isMyPost ? (updatedPost) {
          setState(() {
            final index = _userPosts.indexWhere((p) => p['id'] == updatedPost['id']);
            if (index != -1) {
              _userPosts[index] = updatedPost;
            }
          });
          final lang = context.read<LanguageProvider>();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(lang.getText('post_update_success')),
              backgroundColor: Colors.green,
            ),
          );
        } : null,
        onDelete: isMyPost ? (postId) async {
          await _deletePost(postId);
        } : null,
        onLike: () {
          setState(() {}); 
          _toggleLike(post);
        },
      ),
    );

    try {
      await _currentPostDetailFuture;
    } catch (_) {}
    debugPrint('POST_DETAIL closed for id=${displayedPost['id']}');
    _isPostDetailOpen = false;
    _currentPostDetailFuture = null;
  }
}