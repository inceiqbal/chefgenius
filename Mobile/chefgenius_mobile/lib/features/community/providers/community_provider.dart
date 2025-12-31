import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../../app/data/providers/language_provider.dart'; 
import '../widgets/save_collection_dialog.dart'; 

class CommunityProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;
   
  // State
  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 0;
  final int _postsPerPage = 10;

  // Filters
  String _selectedCategory = 'Semua';
  String _selectedSort = 'Terbaru';
  String _searchQuery = '';

  // Getters
  List<Map<String, dynamic>> get posts => _posts;
  List<Map<String, dynamic>> get users => _users;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String get selectedCategory => _selectedCategory;
  String get selectedSort => _selectedSort;
  String get searchQuery => _searchQuery;

  // Setters
  void setCategory(String category) {
    _selectedCategory = category;
    refreshPosts();
  }

  void setSort(String sort) {
    _selectedSort = sort;
    refreshPosts();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    refreshPosts();
  }

  Future<void> refreshPosts() async {
    _page = 0;
    _hasMore = true;
    _posts.clear();
    _users.clear();
    _isLoading = true;
    notifyListeners();
    
    if (_searchQuery.isNotEmpty) {
      await fetchUsers();
    }
    await fetchPosts();
  }

  Future<void> fetchUsers() async {
    if (_searchQuery.isEmpty) return;
    
    try {
      final response = await _supabase
          .from('profiles')
          .select('id, username, full_name, avatar_url')
          .or('username.ilike.%$_searchQuery%,full_name.ilike.%$_searchQuery%')
          .limit(10);
            
      _users = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint("Error fetch users: $e");
    }
  }

  Future<void> loadMorePosts() async {
    if (_isLoadingMore || !_hasMore) return;
    _isLoadingMore = true;
    notifyListeners();
    await fetchPosts(loadMore: true);
  }

  Future<void> fetchPosts({bool loadMore = false}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      final start = _page * _postsPerPage;
      final end = start + _postsPerPage - 1;
      dynamic query = _supabase
          .from('posts')
          .select('''
            *, 
            profiles(full_name, username, avatar_url), 
            likes(user_id), 
            saved_posts(user_id), 
            comments(id),
            post_media(*)
          ''');

      // 1. FILTER KATEGORI
      if (_selectedCategory == 'Hasil Resep ChefGenius') {
        query = query.not('recipe_id', 'is', null);
      } else if (_selectedCategory != 'Semua') {
        query = query.eq('category', _selectedCategory);
      }

      // 2. SEARCH FILTER
      if (_searchQuery.isNotEmpty) {
        query = query.or('caption.ilike.%$_searchQuery%,title.ilike.%$_searchQuery%,recipe_title.ilike.%$_searchQuery%');
      }

      // 3. SORTING
      if (_selectedSort == 'Like Terbanyak') {
        query = query.order('like_count', ascending: false);
      } else if (_selectedSort == 'Populer') {
        query = query.order('popularity_score', ascending: false);
      } else {
        query = query.order('created_at', ascending: false);
      }

      // 4. PAGINATION
      final response = await query.range(start, end);

      final List<Map<String, dynamic>> formattedPosts = [];

      for (var post in response) {
        final List likes = post['likes'] ?? [];
        final List saves = post['saved_posts'] ?? [];

        final bool isLiked = likes.any((like) => like['user_id'] == userId);
        final bool isSaved = saves.any((save) => save['user_id'] == userId);

        final profile = post['profiles'] ?? {};

        formattedPosts.add({
          ...post,
          'like_count': post['like_count'] ?? 0,
          'comment_count': post['comment_count'] ?? 0,
          'save_count': post['save_count'] ?? 0,
          'share_count': post['share_count'] ?? 0, 
          'is_liked': isLiked,
          'is_saved': isSaved, 
          'author_name': profile['full_name'] ?? profile['username'] ?? 'Chef Misterius',
          'author_avatar': profile['avatar_url'],
        });
      }

      if (loadMore) {
        _posts.addAll(formattedPosts);
      } else {
        _posts = formattedPosts;
      }

      if (response.length < _postsPerPage) {
        _hasMore = false;
      } else {
        _page++;
      }

    } catch (e) {
      debugPrint("Error fetch posts: $e");
    } finally {
      _isLoading = false;
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  // FIXED: Toggle Like (Updated for New DB Logic - Partial Index)
  Future<bool> toggleLike(int index, String postId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;

    final isCurrentlyLiked = _posts[index]['is_liked'];
    final prevLikeCount = _posts[index]['like_count'] ?? 0;

    debugPrint('[COMMUNITY_PROVIDER] ========== TOGGLE LIKE START ==========');
    debugPrint('[COMMUNITY_PROVIDER] Post ID: $postId');

    try {
      if (isCurrentlyLiked) {
        // ========== UNLIKE ==========
        debugPrint('[COMMUNITY_PROVIDER] Action: UNLIKE');
        
        // 1. Delete dari likes table
        await _supabase.from('likes').delete().match({
          'user_id': userId, 
          'post_id': postId
        });
        
        // Hapus notifikasi juga
        try {
          await _supabase.from('notifications').delete().match({
            'user_id': _posts[index]['user_id'],
            'actor_id': userId,
            'related_id': postId,
            'type': 'like'
          });
        } catch (_) {}

        _posts[index]['is_liked'] = false;
        _posts[index]['like_count'] = prevLikeCount - 1;

      } else {
        // ========== LIKE ==========
        debugPrint('[COMMUNITY_PROVIDER] Action: LIKE');
        
        // 1. Insert ke likes table
        await _supabase.from('likes').insert({
          'user_id': userId, 
          'post_id': postId
        });

        // 2. Create notification (FIXED: Use insert + try-catch instead of upsert)
        // Karena DB pakai partial index (comment_id IS NULL), upsert lama bisa error.
        // Kita pakai insert + try-catch buat handle duplicate key (kalau user spam like).
        final postOwnerId = _posts[index]['user_id'];
        if (postOwnerId != userId) {
          try {
            await _supabase.from('notifications').insert({
              'user_id': postOwnerId,
              'actor_id': userId,
              'type': 'like',
              'message': 'menyukai postingan Anda.',
              'related_id': postId,
              'post_id': postId, // Ensure post_id is set
              'is_read': false
            });
           } catch (e) {
             // Ignore duplicate notification error (Expected behavior)
             // debugPrint("Duplicate like notification blocked by DB (Safe): $e");
           }
        }

        _posts[index]['is_liked'] = true;
        _posts[index]['like_count'] = prevLikeCount + 1;
      }

      notifyListeners();

      // 4. Verify dari database (WITH DELAY 500ms)
      await Future.delayed(const Duration(milliseconds: 500));

      final verified = await _supabase
          .from('posts')
          .select('like_count')
          .eq('id', postId)
          .maybeSingle();

      if (verified != null) {
        final dbLikeCount = verified['like_count'] as int;
        if (_posts[index]['like_count'] != dbLikeCount) {
          _posts[index]['like_count'] = dbLikeCount;
          notifyListeners();
        }
      }

      return true;

    } catch (e) {
      debugPrint('[COMMUNITY_PROVIDER] ❌ Error: $e');
      _posts[index]['is_liked'] = isCurrentlyLiked;
      _posts[index]['like_count'] = prevLikeCount;
      notifyListeners();
      return false;
    }
  }

  // --- FIXED: TOGGLE SAVE (Updated for New DB Logic) ---
  Future<void> toggleSave(BuildContext context, int index, String postId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final lang = context.read<LanguageProvider>();
    final isCurrentlySaved = _posts[index]['is_saved'] == true;

    if (isCurrentlySaved) {
      // --- UNSAVE ---
      // Optimistic Update
      _posts[index]['is_saved'] = false;
      _posts[index]['save_count'] = ((_posts[index]['save_count'] ?? 1) - 1).clamp(0, double.infinity).toInt();
      notifyListeners();

      try {
        await _supabase.from('saved_posts').delete().match({'user_id': userId, 'post_id': postId});
        await _supabase.rpc('decrement_save_count', params: {'post_id_param': postId}).catchError((_) {});
        
        // Hapus Notifikasi (Opsional)
        try {
           final postOwnerId = _posts[index]['user_id'];
           if (postOwnerId != null && postOwnerId != userId) {
             await _supabase.from('notifications').delete().match({
               'user_id': postOwnerId,
               'actor_id': userId,
               'type': 'save',
               'related_id': postId,
             });
           }
        } catch (_) {}

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(lang.getText('comm_unsaved'))),
          );
        }
      } catch (e) {
        // Revert kalau gagal
        _posts[index]['is_saved'] = true;
        _posts[index]['save_count'] = (_posts[index]['save_count'] ?? 0) + 1;
        notifyListeners();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.getText('save_failed'))));
        }
      }

    } else {
      // --- SAVE ---
      // 1. Show Dialog Collection
      final result = await showDialog<String>(
        context: context,
        builder: (context) => SaveCollectionDialog(userId: userId),
      );

      if (result == null) return; // Cancel

      final String? collectionId = result == 'all_posts' ? null : result;

      // Optimistic Update
      _posts[index]['is_saved'] = true;
      _posts[index]['save_count'] = (_posts[index]['save_count'] ?? 0) + 1;
      notifyListeners();

      try {
        await _supabase.from('saved_posts').insert({
          'user_id': userId, 
          'post_id': postId,
          'collection_id': collectionId
        });
        await _supabase.rpc('increment_save_count', params: {'post_id_param': postId}).catchError((_) {});
        
        // --- FIX NOTIFIKASI ANTI-CRASH ---
        final postOwnerId = _posts[index]['user_id'];
        if (postOwnerId != null && postOwnerId != userId) {
          try {
            // Gunakan INSERT + Try-Catch untuk DB baru
            await _supabase.from('notifications').insert({
              'user_id': postOwnerId,
              'actor_id': userId,
              'type': 'save',
              'message': 'menyimpan postingan Anda.',
              'related_id': postId,
              'post_id': postId,
              'is_read': false,
            });
           } catch (e) {
             // Ignore duplicate key error
             // debugPrint("Notification save duplicate ignored: $e");
           }
        }
        // -------------------------------------

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(lang.getText('comm_saved'))),
          );
        }
      } catch (e) {
        // Revert
        _posts[index]['is_saved'] = false;
        _posts[index]['save_count'] = ((_posts[index]['save_count'] ?? 1) - 1).clamp(0, double.infinity).toInt();
        notifyListeners();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.getText('save_failed'))));
        }
      }
    }
  }

  Future<void> deletePost(String postId, int index) async {
    try {
      // Safe Delete: Hapus notifikasi terkait dulu biar gak kena Foreign Key Violation
      try {
        await _supabase.from('notifications').delete().eq('post_id', postId);
      } catch (e) {
        debugPrint("Warning: Failed to cleanup notifications before delete post: $e");
      }

      await _supabase.from('posts').delete().eq('id', postId);
      _posts.removeAt(index);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> incrementShareCount(int index, String postId) async {
    _posts[index]['share_count'] = (_posts[index]['share_count'] ?? 0) + 1;
    notifyListeners();

    try {
      try {
         await _supabase.rpc('increment_share_count', params: {'post_id': postId});
      } catch (_) {
         final currentCount = _posts[index]['share_count'];
         await _supabase.from('posts').update({
          'share_count': currentCount
         }).eq('id', postId);
      }
      
      final userId = _supabase.auth.currentUser?.id;
      final postOwnerId = _posts[index]['user_id'];
      
      if (userId != null && postOwnerId != userId) {
        try {
          debugPrint('[SHARE_NOTIF] Sending to postOwnerId=$postOwnerId from userId=$userId');
          // FIX: Tambahkan timestamp agar notifikasi share tidak di-deduplicate
          final timestamp = DateTime.now().toIso8601String();
          await _supabase.from('notifications').insert({
            'user_id': postOwnerId,
            'actor_id': userId,
            'type': 'share',
            'message': 'membagikan postingan Anda.',
            'related_id': '$postId|$timestamp', // Unique per share event
            'post_id': postId,
            'is_read': false
          });
          debugPrint('[SHARE_NOTIF] ✅ Notification sent successfully');
        } catch (e) {
          debugPrint('[SHARE_NOTIF] ❌ Error sending notification: $e');
        }
      } else {
        debugPrint('[SHARE_NOTIF] ⚠️ Skipped: userId=$userId, postOwnerId=$postOwnerId');
      }
    } catch (e) {
      debugPrint('[COMMUNITY_PROVIDER] ❌ Error increment share: $e');
    }
  }

  void updateSaveState(int index, bool isSaved) {
    _posts[index]['is_saved'] = isSaved;
    if (isSaved) {
      _posts[index]['save_count'] = (_posts[index]['save_count'] ?? 0) + 1;
    } else {
      _posts[index]['save_count'] = ((_posts[index]['save_count'] ?? 1) - 1).clamp(0, double.infinity).toInt();
    }
    notifyListeners();
  }
   
  void revertSaveState(int index, bool originalState) {
    _posts[index]['is_saved'] = originalState;
    if (originalState) {
      _posts[index]['save_count'] = (_posts[index]['save_count'] ?? 0) + 1;
    } else {
      _posts[index]['save_count'] = ((_posts[index]['save_count'] ?? 1) - 1).clamp(0, double.infinity).toInt();
    }
    notifyListeners();
  }

  void updatePost(int index, Map<String, dynamic> updatedPost) {
    if (index >= 0 && index < _posts.length) {
      _posts[index] = updatedPost;
      notifyListeners();
    }
  }
}