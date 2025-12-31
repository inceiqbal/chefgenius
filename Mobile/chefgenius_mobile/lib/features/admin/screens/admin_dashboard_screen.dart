import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:chefgenius/app/data/localization/app_strings.dart';
import '../widgets/admin_common_widgets.dart';
import '../widgets/report_card.dart';
import '../widgets/appeal_card.dart';
import '../widgets/sanctioned_user_card.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  late AppStrings l10n;
  final supabase = Supabase.instance.client;
  late TabController _tabController;
  
  bool _isLoading = true;
  List<Map<String, dynamic>> _reports = [];
  String _reportFilter = 'all'; // 'all', 'post', 'comment'
  
  // Appeals Data
  List<Map<String, dynamic>> _appeals = [];
  bool _isLoadingAppeals = false;

  // Sanctioned Users Data
  List<Map<String, dynamic>> _sanctionedUsers = [];
  bool _isLoadingSanctions = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checkAccess();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkAccess() async {
    final user = supabase.auth.currentUser;
    const adminEmail = 'inceiqbals6@gmail.com';

    // RLS: Gunakan policy di Supabase untuk membatasi akses Admin,
    // namun tetap melakukan cek email di client-side untuk UI yang lebih cepat.
    if (user == null || user.email != adminEmail) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Akses Ditolak: Area Terlarang!"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
      }
    } else {
      _fetchReports();
      _fetchAppeals();
      _fetchSanctionedUsers();
    }
  }

  Future<void> _fetchReports() async {
    setState(() => _isLoading = true);
    try {
      // FIX: Menambahkan !fk_reports_posts agar tidak error ambiguous relationship
      final response = await supabase
          .from('reports')
          .select('''
            *, 
            reporter_profile:profiles!reports_reporter_id_fkey(username, avatar_url), 
            reported_profile:profiles!reports_reported_id_fkey(username, warning_level, avatar_url),
            posts!reports_post_id_fkey(*, profiles(username, avatar_url)),
            comments!reports_comment_id_fkey(content, user_id)
          ''')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _reports = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching reports: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchAppeals() async {
    setState(() => _isLoadingAppeals = true);
    try {
      final response = await supabase
          .from('appeals')
          .select('*, profiles:user_id(username, warning_level, avatar_url)')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _appeals = List<Map<String, dynamic>>.from(response);
          _isLoadingAppeals = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching appeals: $e");
      if (mounted) setState(() => _isLoadingAppeals = false);
    }
  }

  Future<void> _fetchSanctionedUsers() async {
    setState(() => _isLoadingSanctions = true);
    try {
      final response = await supabase
          .from('profiles')
          .select('id, username, full_name, avatar_url, warning_level, sanction_end_time')
          .gt('warning_level', 0)
          .order('warning_level', ascending: false);

      if (mounted) {
        setState(() {
          _sanctionedUsers = List<Map<String, dynamic>>.from(response);
          _isLoadingSanctions = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching sanctioned users: $e");
      if (mounted) setState(() => _isLoadingSanctions = false);
    }
  }

  Future<void> _revokeSanction(String userId, String username) async {
    // Implementasi perbaikan: track hasil restore, tunda hapus backup sampai
    // restore sukses, kumpulkan error, dan tampilkan ringkasan dengan opsi retry.
    try {
      // 1. Reset warning level
      await supabase.from('profiles').update({
        'warning_level': 0,
        'sanction_end_time': null,
      }).eq('id', userId);

      // 2. Restore postingan yang dihapus karena sanksi
      int restoredPosts = 0;
      int restoredComments = 0;
      final List<String> restoreErrors = [];

      try {
        debugPrint("🔍 Mencari postingan yang dihapus untuk user: $userId");
        final deletedPosts = await supabase.from('deleted_posts').select().eq('user_id', userId);
        debugPrint("📦 Ditemukan ${deletedPosts.length} postingan yang dihapus");

        for (final post in deletedPosts) {
          final postOriginalId = post['original_id'];
          bool postRestoreSuccess = true;
          int restoredCommentsForThisPost = 0;

          try {
            debugPrint("🔄 Restoring post: $postOriginalId");
            try {
              await supabase.rpc('restore_deleted_post', params: {'post_data': post});
            } catch (e) {
              postRestoreSuccess = false;
              restoreErrors.add('Failed RPC restore_deleted_post for post $postOriginalId: $e');
              debugPrint('❌ ${restoreErrors.last}');
            }

            // Restore media (only attempt; mark failure but don't stop overall loop)
            try {
              final deletedMedia = await supabase.from('deleted_post_media').select().eq('post_id', postOriginalId);
              for (final media in deletedMedia) {
                try {
                  // Check if media already exists (from previous restore attempt)
                  final existing = await supabase.from('post_media').select('id').eq('id', media['id']).maybeSingle();
                  if (existing != null) {
                    debugPrint('⏭️ Media ${media['id']} already exists, skipping');
                    continue;
                  }
                  await supabase.from('post_media').insert({
                    'id': media['id'],
                    'post_id': media['post_id'],
                    'url': media['url'],
                    'type': media['type'],
                    'media_order': media['media_order'],
                    'thumbnail_url': media['thumbnail_url'],
                  });
                } catch (e) {
                  postRestoreSuccess = false;
                  restoreErrors.add('Failed restoring media ${media['id']} for post $postOriginalId: $e');
                  debugPrint('❌ ${restoreErrors.last}');
                }
              }
            } catch (e) {
              postRestoreSuccess = false;
              restoreErrors.add('Failed fetching deleted_post_media for post $postOriginalId: $e');
            }

            // Restore likes
            try {
              final deletedLikes = await supabase.from('deleted_likes').select().eq('post_id', postOriginalId);
              for (final like in deletedLikes) {
                try {
                  await supabase.rpc('restore_deleted_like', params: {'like_data': like});
                } catch (e) {
                  postRestoreSuccess = false;
                  restoreErrors.add('Failed restoring like ${like['id']} for post $postOriginalId: $e');
                  debugPrint('❌ ${restoreErrors.last}');
                }
              }
            } catch (e) {
              postRestoreSuccess = false;
              restoreErrors.add('Failed fetching deleted_likes for post $postOriginalId: $e');
            }

            // Restore saved posts
            try {
              final deletedSaved = await supabase.from('deleted_saved_posts').select().eq('post_id', postOriginalId);
              for (final saved in deletedSaved) {
                try {
                  await supabase.rpc('restore_deleted_saved_post', params: {'saved_data': saved});
                } catch (e) {
                  postRestoreSuccess = false;
                  restoreErrors.add('Failed restoring saved_post ${saved['id']} for post $postOriginalId: $e');
                  debugPrint('❌ ${restoreErrors.last}');
                }
              }
            } catch (e) {
              postRestoreSuccess = false;
              restoreErrors.add('Failed fetching deleted_saved_posts for post $postOriginalId: $e');
            }

            // Restore comments (iterative approach for nested replies)
            try {
              final deletedCommentsForPost = await supabase.from('deleted_post_comments').select().eq('post_id', postOriginalId);
              debugPrint("📝 Found ${deletedCommentsForPost.length} comments to restore for post $postOriginalId");
              
              // Build a set of original_comment_ids in backup for reference
              final Set<int> backupCommentIds = {};
              for (final c in deletedCommentsForPost) {
                final origId = c['original_comment_id'] as int?;
                if (origId != null) backupCommentIds.add(origId);
              }
              
              // Pending comments to restore
              List<Map<String, dynamic>> pending = List<Map<String, dynamic>>.from(deletedCommentsForPost);
              Set<int> restoredIds = {}; // IDs that have been successfully restored
              
              int maxIterations = pending.length + 1; // Prevent infinite loop
              int iteration = 0;
              
              while (pending.isNotEmpty && iteration < maxIterations) {
                iteration++;
                List<Map<String, dynamic>> stillPending = [];
                
                for (final comment in pending) {
                  final parentId = comment['parent_id'] as int?;
                  final origCommentId = comment['original_comment_id'] as int?;
                  
                  // Check if this comment can be restored now
                  bool canRestore = false;
                  int? effectiveParentId = parentId;
                  
                  if (parentId == null) {
                    // Top-level comment, can always restore
                    canRestore = true;
                  } else {
                    // Check if parent exists in database
                    final parentExists = await supabase.from('comments').select('id').eq('id', parentId).maybeSingle();
                    if (parentExists != null) {
                      // Parent exists in database, can restore
                      canRestore = true;
                    } else if (restoredIds.contains(parentId)) {
                      // Parent was just restored in this session
                      canRestore = true;
                    } else if (!backupCommentIds.contains(parentId)) {
                      // Parent is NOT in our backup (belongs to another user or was deleted long ago)
                      // Set parent_id to null to make it a top-level comment
                      debugPrint("⚠️ Comment ${comment['id']}: parent_id $parentId not in backup, converting to top-level");
                      effectiveParentId = null;
                      canRestore = true;
                    }
                    // else: parent is in backup but not yet restored, wait for next iteration
                  }
                  
                  if (canRestore) {
                    try {
                      await supabase.rpc('restore_deleted_comment', params: {
                        'comment_data': {
                          'user_id': comment['user_id'],
                          'post_id': comment['post_id'],
                          'content': comment['content'],
                          'parent_id': effectiveParentId,
                          'is_edited': comment['is_edited'] ?? false,
                          'created_at': comment['created_at'],
                        },
                      });
                      restoredCommentsForThisPost++;
                      if (origCommentId != null) restoredIds.add(origCommentId);
                    } catch (e) {
                      postRestoreSuccess = false;
                      restoreErrors.add('Failed restoring comment ${comment['id']} for post $postOriginalId: $e');
                      debugPrint('❌ ${restoreErrors.last}');
                    }
                  } else {
                    stillPending.add(comment);
                  }
                }
                
                // Check if we made progress
                if (stillPending.length == pending.length) {
                  // No progress made, remaining comments have unresolvable parents
                  for (final comment in stillPending) {
                    debugPrint("⚠️ Comment ${comment['id']}: cannot restore, setting parent to null as fallback");
                    try {
                      await supabase.rpc('restore_deleted_comment', params: {
                        'comment_data': {
                          'user_id': comment['user_id'],
                          'post_id': comment['post_id'],
                          'content': comment['content'],
                          'parent_id': null, // Force top-level
                          'is_edited': comment['is_edited'] ?? false,
                          'created_at': comment['created_at'],
                        },
                      });
                      restoredCommentsForThisPost++;
                    } catch (e) {
                      postRestoreSuccess = false;
                      restoreErrors.add('Failed restoring comment ${comment['id']} (fallback) for post $postOriginalId: $e');
                      debugPrint('❌ ${restoreErrors.last}');
                    }
                  }
                  break;
                }
                
                pending = stillPending;
              }
            } catch (e) {
              postRestoreSuccess = false;
              restoreErrors.add('Failed fetching deleted_post_comments for post $postOriginalId: $e');
            }

            // Sync counts (best-effort)
            try {
              final likeCount = await supabase.from('likes').select('id').eq('post_id', postOriginalId);
              final commentCount = await supabase.from('comments').select('id').eq('post_id', postOriginalId);
              final saveCount = await supabase.from('saved_posts').select('id').eq('post_id', postOriginalId);
              await supabase.from('posts').update({
                'like_count': (likeCount as List).length,
                'comment_count': (commentCount as List).length,
                'save_count': (saveCount as List).length,
              }).eq('id', postOriginalId);
            } catch (e) {
              restoreErrors.add('Warning syncing counts for post $postOriginalId: $e');
              debugPrint('⚠️ ${restoreErrors.last}');
            }

            // Jika semua langkah utama sukses, hapus backup untuk post ini
            if (postRestoreSuccess) {
              try {
                await supabase.from('deleted_post_media').delete().eq('post_id', postOriginalId);
                await supabase.from('deleted_likes').delete().eq('post_id', postOriginalId);
                await supabase.from('deleted_saved_posts').delete().eq('post_id', postOriginalId);
                await supabase.from('deleted_post_comments').delete().eq('post_id', postOriginalId);
                await supabase.from('deleted_posts').delete().eq('id', post['id']);
                restoredPosts++;
                restoredComments += restoredCommentsForThisPost;
                debugPrint("✅ Post $postOriginalId restored and backups removed");
              } catch (e) {
                restoreErrors.add('Failed deleting backup rows for post $postOriginalId: $e');
                debugPrint('❌ ${restoreErrors.last}');
              }
            } else {
              restoreErrors.add('Post $postOriginalId was not fully restored; backups retained for retry.');
              debugPrint('⚠️ Post $postOriginalId retain backups for retry');
            }
          } catch (e) {
            restoreErrors.add('Unexpected error while restoring post $postOriginalId: $e');
            debugPrint('❌ ${restoreErrors.last}');
          }
        }

        // Restore komentar individual yang dihapus (bukan karena post dihapus)
        final deletedIndividualComments = await supabase.from('deleted_comments').select().eq('user_id', userId);
        final Set<String> affectedPostIds = {};

        // Sort: parent comments (parent_id == null) first, then replies
        final sortedIndividualComments = List<Map<String, dynamic>>.from(deletedIndividualComments);
        sortedIndividualComments.sort((a, b) {
          final aParent = a['parent_id'];
          final bParent = b['parent_id'];
          if (aParent == null && bParent != null) return -1;
          if (aParent != null && bParent == null) return 1;
          return (a['id'] ?? 0).compareTo(b['id'] ?? 0);
        });

        for (final comment in sortedIndividualComments) {
          bool commentSuccess = true;
          final commentId = comment['id'];
          try {
            final postExists = await supabase.from('posts').select('id').eq('id', comment['post_id']).maybeSingle();
            if (postExists != null) {
              try {
                await supabase.rpc('restore_deleted_comment', params: {
                  'comment_data': {
                    'user_id': comment['user_id'],
                    'post_id': comment['post_id'],
                    'content': comment['content'],
                    'parent_id': comment['parent_id'],
                    'is_edited': false,
                    'created_at': comment['original_created_at'],
                  },
                });
                affectedPostIds.add(comment['post_id'].toString());
                restoredComments++;
              } catch (e) {
                commentSuccess = false;
                restoreErrors.add('Failed restoring deleted_comment $commentId: $e');
              }
            } else {
              commentSuccess = false;
              restoreErrors.add('Post ${comment['post_id']} for deleted_comment $commentId does not exist; cannot restore.');
            }
          } catch (e) {
            commentSuccess = false;
            restoreErrors.add('Error checking post for deleted_comment $commentId: $e');
          }

          if (commentSuccess) {
            try {
              await supabase.from('deleted_comments').delete().eq('id', commentId);
            } catch (e) {
              restoreErrors.add('Failed deleting deleted_comments backup $commentId after restore: $e');
            }
          }
        }

        // Restore likes user yang dihapus saat banned
        final deletedUserLikes = await supabase.from('deleted_user_likes').select().eq('user_id', userId);
        for (final like in deletedUserLikes) {
          final likeId = like['id'];
          bool likeSuccess = true;
          try {
            final postExists = await supabase.from('posts').select('id').eq('id', like['post_id']).maybeSingle();
            if (postExists != null) {
              try {
                await supabase.rpc('restore_deleted_like', params: {'like_data': like});
                affectedPostIds.add(like['post_id'].toString());
              } catch (e) {
                likeSuccess = false;
                restoreErrors.add('Failed restoring deleted_user_like $likeId: $e');
              }
            } else {
              likeSuccess = false;
              restoreErrors.add('Post ${like['post_id']} for deleted_user_like $likeId does not exist; cannot restore.');
            }
          } catch (e) {
            likeSuccess = false;
            restoreErrors.add('Error checking post for deleted_user_like $likeId: $e');
          }

          if (likeSuccess) {
            try {
              await supabase.from('deleted_user_likes').delete().eq('id', likeId);
            } catch (e) {
              restoreErrors.add('Failed deleting deleted_user_likes $likeId after restore: $e');
            }
          }
        }

        // Sync counts untuk semua affected posts sekali di akhir
        for (final postIdStr in affectedPostIds) {
          try {
            final likeCount = await supabase.from('likes').select('id').eq('post_id', postIdStr);
            final commentCount = await supabase.from('comments').select('id').eq('post_id', postIdStr);
            final saveCount = await supabase.from('saved_posts').select('id').eq('post_id', postIdStr);
            await supabase.from('posts').update({
              'like_count': (likeCount as List).length,
              'comment_count': (commentCount as List).length,
              'save_count': (saveCount as List).length,
            }).eq('id', postIdStr);
          } catch (e) {
            restoreErrors.add('Error syncing counts for post $postIdStr: $e');
          }
        }
      } catch (e) {
        restoreErrors.add('Error restoring posts/comments: $e');
      }

      // 3. Kirim notifikasi ke user
      String message = 'Sanksi akun Anda telah dicabut oleh Admin.';
      if (restoredPosts > 0 || restoredComments > 0) {
        message += ' $restoredPosts postingan dan $restoredComments komentar Anda telah dipulihkan.';
      }
      message += ' Silakan gunakan aplikasi dengan bijak.';
      
      try {
        await supabase.from('notifications').insert({
          'user_id': userId,
          'type': 'system_info',
          'title': 'Sanksi Dicabut',
          'message': message,
          'related_id': null
        });
      } catch (_) {}

      // Coba simpan ringkasan restore ke tabel `restore_logs` jika ada
      try {
        await supabase.from('restore_logs').insert({
          'user_id': userId,
          'restored_posts': restoredPosts,
          'restored_comments': restoredComments,
          'errors': restoreErrors.join('\n'),
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
      } catch (_) {
        // Jika tabel tidak ada, jangan crash — cukup lanjut
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Sanksi untuk $username berhasil dicabut."), backgroundColor: Colors.green),
        );
        _fetchSanctionedUsers();

        // Tampilkan ringkasan restore dengan opsi retry
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Ringkasan Restore'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Postingan direstore: $restoredPosts'),
                    Text('Komentar direstore: $restoredComments'),
                    const SizedBox(height: 12),
                    if (restoreErrors.isNotEmpty) ...[
                      const Text('Beberapa error terjadi (lihat detail):', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      for (final err in restoreErrors.take(10)) Text('- $err', style: const TextStyle(fontSize: 12)),
                      if (restoreErrors.length > 10) Text('...and ${restoreErrors.length - 10} more', style: const TextStyle(fontSize: 12)),
                    ] else
                      const Text('Semua data berhasil direstore.'),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
              if (restoreErrors.isNotEmpty)
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    // Retry: panggil ulang revoke untuk mencoba restore lagi. Ini aman karena operasi restore umumnya idempotent/upsert.
                    _revokeSanction(userId, username);
                  },
                  child: const Text('Retry Restore'),
                ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal mencabut sanksi: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Backup post beserta semua data terkait (media, likes, saves, comments) lalu hapus
  Future<void> _backupAndDeletePost(dynamic postId, String? adminId, dynamic reportId, String reason) async {
    // 1. Ambil data post
    final postData = await supabase.from('posts').select('*').eq('id', postId).maybeSingle();
    if (postData == null) return;

    // 2. Backup post ke deleted_posts (upsert untuk hindari duplicate key error)
    try {
      await supabase.from('deleted_posts').upsert({
        'id': postData['id'],
        'original_id': postData['id'],
        'user_id': postData['user_id'],
        'image_url': postData['image_url'],
        'caption': postData['caption'],
        'title': postData['title'],
        'video_url': postData['video_url'],
        'thumbnail_url': postData['thumbnail_url'],
        'category': postData['category'],
        'like_count': postData['like_count'] ?? 0,
        'comment_count': postData['comment_count'] ?? 0,
        'share_count': postData['share_count'] ?? 0,
        'save_count': postData['save_count'] ?? 0,
        'recipe_id': postData['recipe_id'],
        'recipe_title': postData['recipe_title'],
        'is_pinned': postData['is_pinned'] ?? false,
        'is_edited': postData['is_edited'] ?? false,
        'original_created_at': postData['created_at'],
        'deleted_by': adminId,
        'report_id': reportId,
        'reason': reason,
      }, onConflict: 'id');
    } catch (e) {
      debugPrint("Backup post already exists or error: $e");
    }

    // 3. Backup media
    final mediaData = await supabase.from('post_media').select('*').eq('post_id', postId);
    for (final media in mediaData) {
      try {
        await supabase.from('deleted_post_media').upsert({
          'id': media['id'],
          'post_id': media['post_id'],
          'url': media['url'],
          'type': media['type'],
          'media_order': media['media_order'] ?? media['index'] ?? 0,
          'thumbnail_url': media['thumbnail_url'],
        }, onConflict: 'id');
      } catch (_) {}
    }

    // 4. Backup likes
    final likesData = await supabase.from('likes').select('*').eq('post_id', postId);
    for (final like in likesData) {
      try {
        await supabase.from('deleted_likes').upsert({
          'id': like['id'],
          'user_id': like['user_id'],
          'post_id': like['post_id'],
          'created_at': like['created_at'],
        }, onConflict: 'id');
      } catch (_) {}
    }

    // 5. Backup saved_posts
    final savedData = await supabase.from('saved_posts').select('*').eq('post_id', postId);
    for (final saved in savedData) {
      try {
        await supabase.from('deleted_saved_posts').upsert({
          'id': saved['id'],
          'user_id': saved['user_id'],
          'post_id': saved['post_id'],
          'collection_id': saved['collection_id'],
          'created_at': saved['created_at'],
        }, onConflict: 'id');
      } catch (_) {}
    }

    // 6. Backup comments
    final commentsData = await supabase.from('comments').select('*').eq('post_id', postId);
    for (final comment in commentsData) {
      try {
        await supabase.from('deleted_post_comments').upsert({
          'id': comment['id'],
          'user_id': comment['user_id'],
          'post_id': comment['post_id'],
          'content': comment['content'],
          'parent_id': comment['parent_id'],
          'is_edited': comment['is_edited'] ?? false,
          'created_at': comment['created_at'],
        }, onConflict: 'id');
      } catch (_) {}
    }

    // 6.5 Hapus notifikasi terkait post (PENTING: Biar gak error FK)
    try {
      await supabase.from('notifications').delete().eq('post_id', postId);
    } catch (_) {}

    // 7. Hapus post (cascade akan hapus likes, saves, comments, media)
    await supabase.from('posts').delete().eq('id', postId);
  }

  /// Backup dan hapus SEMUA konten user (untuk banned permanen)
  Future<void> _backupAllUserContent(String usrId, String? adminId, dynamic reportId) async {
    try {
      // 1. Backup dan hapus semua postingan user
      final allPosts = await supabase.from('posts').select('id').eq('user_id', usrId);
      for (final post in allPosts) {
        await _backupAndDeletePost(post['id'], adminId, reportId, 'user_banned');
      }

      // 2. Backup dan hapus semua komentar user di post orang lain
      final allComments = await supabase.from('comments').select('*').eq('user_id', usrId);
      for (final comment in allComments) {
        // Backup comment (upsert untuk hindari duplicate)
        try {
          await supabase.from('deleted_comments').upsert({
            'id': comment['id'],
            'original_id': comment['id'],
            'user_id': comment['user_id'],
            'post_id': comment['post_id'],
            'content': comment['content'],
            'parent_id': comment['parent_id'],
            'original_created_at': comment['created_at'],
            'deleted_by': adminId,
            'report_id': reportId,
            'reason': 'user_banned',
          }, onConflict: 'id');
        } catch (_) {} // Mungkin sudah di-backup dari post
        
        // Hapus notifikasi terkait sebelum hapus komentar
        try {
          await supabase.from('notifications').delete().eq('comment_id', comment['id']);
        } catch (_) {}

        // Hapus comment
        await supabase.from('comments').delete().eq('id', comment['id']);
        
        // Update comment count di post
        if (comment['post_id'] != null) {
          try {
            final countResult = await supabase.from('comments').select('id').eq('post_id', comment['post_id']);
            await supabase.from('posts').update({
              'comment_count': (countResult as List).length
            }).eq('id', comment['post_id']);
          } catch (_) {}
        }
      }

      // 3. Backup dan hapus semua likes user
      final allLikes = await supabase.from('likes').select('*').eq('user_id', usrId);
      for (final like in allLikes) {
        // Backup like ke deleted_user_likes (upsert untuk hindari duplicate)
        try {
          await supabase.from('deleted_user_likes').upsert({
            'id': like['id'],
            'user_id': like['user_id'],
            'post_id': like['post_id'],
            'created_at': like['created_at'],
          }, onConflict: 'id');
        } catch (_) {}
        
        await supabase.from('likes').delete().eq('id', like['id']);
        // Update like count di post
        if (like['post_id'] != null) {
          try {
            final countResult = await supabase.from('likes').select('id').eq('post_id', like['post_id']);
            await supabase.from('posts').update({
              'like_count': (countResult as List).length
            }).eq('id', like['post_id']);
          } catch (_) {}
        }
      }

      debugPrint("✅ All user content backed up and deleted for banned user: $usrId");
    } catch (e) {
      debugPrint("Error backing up all user content: $e");
    }
  }

  Future<void> _issueWarning(dynamic userId, int currentLevel, dynamic reportId, {dynamic postId, dynamic commentId, int durationDays = 0, bool forceLevel3 = false}) async {
    // Jika forceLevel3 = true (Permanen dipilih), langsung set ke level 3
    final newLevel = forceLevel3 ? 3 : currentLevel + 1;
    String message = "";
    DateTime? endTime;
    final adminId = supabase.auth.currentUser?.id;

    // Permanen = tidak ada end time
    if (durationDays > 0 && !forceLevel3) {
      endTime = DateTime.now().add(Duration(days: durationDays));
    }
    final dateStr = endTime != null ? "${endTime.day}/${endTime.month}/${endTime.year}" : "Permanen";

    if (newLevel == 1) {
      message = "Teguran 1: Fitur dibatasi sampai $dateStr.";
    } else if (newLevel == 2) {
      message = "Teguran 2: Read Only sampai $dateStr.";
    } else if (newLevel >= 3) {
      message = "Teguran 3: AKUN DIBEKUKAN (BANNED).";
    }

    try {
      final List<dynamic> updatedData = await supabase
          .from('profiles')
          .update({
            'warning_level': newLevel,
            'sanction_end_time': endTime?.toUtc().toIso8601String(),
          })
          .eq('id', userId)
          .select();

      if (updatedData.isEmpty) throw "Gagal update level!";
      
      // Jika BANNED (level 3), backup dan hapus SEMUA postingan & komentar user
      if (newLevel >= 3) {
        await _backupAllUserContent(userId.toString(), adminId, reportId);
      } else {
        // Untuk level 1 & 2, hanya hapus konten yang dilaporkan
        if (commentId != null) {
            // Ambil data comment sebelum delete untuk backup
            final commentData = await supabase.from('comments').select('*').eq('id', commentId).maybeSingle();
            if (commentData != null) {
              final commentPostId = commentData['post_id'];
              
              // Backup comment ke deleted_comments
              await supabase.from('deleted_comments').insert({
                'id': commentData['id'],
                'original_id': commentData['id'],
                'user_id': commentData['user_id'],
                'post_id': commentPostId,
                'content': commentData['content'],
                'parent_id': commentData['parent_id'],
                'original_created_at': commentData['created_at'],
                'deleted_by': adminId,
                'report_id': reportId,
                'reason': 'sanction_warning',
              });
              
              // FIX: Hapus notifikasi terkait komentar ini dulu
              try {
                await supabase.from('notifications').delete().eq('comment_id', commentId);
              } catch (_) {}

              await supabase.from('comments').delete().eq('id', commentId);
              
              // Update comment_count di posts
              if (commentPostId != null) {
                try {
                  final countResult = await supabase.from('comments').select('id').eq('post_id', commentPostId);
                  final newCount = (countResult as List).length;
                  await supabase.from('posts').update({'comment_count': newCount}).eq('id', commentPostId);
                } catch (e) {
                  debugPrint("Error updating comment_count: $e");
                }
              }
            }
        } else if (postId != null) {
            await _backupAndDeletePost(postId, adminId, reportId, 'sanction_warning');
        }
      }
      await supabase.from('reports').update({
        'status': 'resolved',
        'action_taken': 'warning_issued'
      }).eq('id', reportId);

      try {
        await supabase.from('notifications').insert({
          'user_id': userId,
          'type': 'system_sanction',
          'title': 'Sanksi Pelanggaran',
          'message': message,
          'related_id': reportId
        });
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Sanksi diberikan: $message"), backgroundColor: Colors.orange),
        );
        _fetchReports();
        _fetchSanctionedUsers(); // Refresh tab Sanksi dengan data terbaru
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _deletePost(dynamic postId, dynamic reportId) async {
    if (postId == null) return;
    try {
      final adminId = supabase.auth.currentUser?.id;
      
      // Ambil data post dulu sebelum backup
      final postData = await supabase.from('posts').select('*').eq('id', postId).maybeSingle();
      if (postData == null) throw "Post tidak ditemukan.";
      
      // Backup dan hapus post
      await _backupAndDeletePost(postId, adminId, reportId, 'admin_deleted');
      
      await supabase.from('reports').update({
        'status': 'resolved',
        'action_taken': 'post_deleted'
      }).eq('id', reportId);

      try {
        await supabase.from('notifications').insert({
          'user_id': postData['user_id'],
          'type': 'system_delete',
          'title': 'Postingan Dihapus',
          'message': 'Postingan Anda dihapus oleh Admin karena melanggar pedoman.',
          'related_id': reportId
        });
      } catch (_) {}

      setState(() {
        final index = _reports.indexWhere((r) => r['id'] == reportId);
        if (index != -1) {
          _reports[index]['status'] = 'resolved';
          _reports[index]['action_taken'] = 'post_deleted';
        }
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Postingan dihapus."), backgroundColor: Colors.green));
      }
    } catch (e) {
      debugPrint("Error delete post: $e");
    }
  }

  Future<void> _deleteComment(dynamic commentId, dynamic reportId) async {
    try {
      // Ambil data comment sebelum delete untuk backup
      final commentData = await supabase.from('comments').select('*').eq('id', commentId).maybeSingle();
      if (commentData == null) throw "Komentar tidak ditemukan.";
      
      final postId = commentData['post_id'];
      final adminId = supabase.auth.currentUser?.id;
      
      // Backup comment ke deleted_comments
      await supabase.from('deleted_comments').insert({
        'id': commentData['id'],
        'original_id': commentData['id'],
        'user_id': commentData['user_id'],
        'post_id': postId,
        'content': commentData['content'],
        'parent_id': commentData['parent_id'],
        'original_created_at': commentData['created_at'],
        'deleted_by': adminId,
        'report_id': reportId,
        'reason': 'admin_deleted',
      });
      
      // FIX: Hapus notifikasi terkait komentar ini dulu
      try {
        await supabase.from('notifications').delete().eq('comment_id', commentId);
      } catch (_) {}

      await supabase.from('comments').delete().eq('id', commentId);
      
      // Update comment_count di posts
      if (postId != null) {
        try {
          final countResult = await supabase.from('comments').select('id').eq('post_id', postId);
          final newCount = (countResult as List).length;
          await supabase.from('posts').update({'comment_count': newCount}).eq('id', postId);
        } catch (e) {
          debugPrint("Error updating comment_count: $e");
        }
      }
      
      await supabase.from('reports').update({
        'status': 'resolved',
        'action_taken': 'comment_deleted'
      }).eq('id', reportId);

      try {
        await supabase.from('notifications').insert({
          'user_id': commentData['user_id'],
          'type': 'system_delete',
          'title': 'Komentar Dihapus',
          'message': 'Komentar Anda dihapus oleh Admin.',
          'related_id': reportId
        });
      } catch (_) {}

      setState(() {
        final index = _reports.indexWhere((r) => r['id'] == reportId);
        if (index != -1) {
          _reports[index]['status'] = 'resolved';
          _reports[index]['action_taken'] = 'comment_deleted';
        }
      });
    } catch (e) {
      debugPrint("Error delete comment: $e");
    }
  }

  Future<void> _dismissReport(dynamic reportId) async {
    try {
      await supabase.from('reports').update({
        'status': 'ignored',
        'action_taken': 'none'
      }).eq('id', reportId);

      setState(() {
        final index = _reports.indexWhere((r) => r['id'] == reportId);
        if (index != -1) {
          _reports[index]['status'] = 'ignored';
          _reports[index]['action_taken'] = 'none';
        }
      });
    } catch (e) {
      debugPrint("Error dismiss report: $e");
    }
  }

  Future<void> _handleAppeal(dynamic appealId, String userId, bool isApproved) async {
    try {
      await supabase.from('appeals').update({
        'status': isApproved ? 'approved' : 'rejected'
      }).eq('id', appealId);

      if (isApproved) {
        // Reset semua sanksi jika banding diterima
        await supabase.from('profiles').update({
          'warning_level': 0,
          'sanction_end_time': null,
        }).eq('id', userId);
        // Restore semua data user yang dihapus karena sanksi
        final userProfile = await supabase.from('profiles').select('username').eq('id', userId).maybeSingle();
        final username = userProfile != null ? (userProfile['username'] ?? 'User') : 'User';
        await _revokeSanction(userId, username);
      }

      try {
        await supabase.from('notifications').insert({
          'user_id': userId,
          'type': 'system_appeal',
          'title': isApproved ? 'Banding Diterima' : 'Banding Ditolak',
          'message': isApproved ? 'Sanksi Anda telah dikurangi.' : 'Permohonan banding ditolak.',
          'related_id': appealId
        });
      } catch (_) {}

      _fetchAppeals();
      if (isApproved) {
        _fetchSanctionedUsers();
      }
    } catch (e) {
      debugPrint("Error handle appeal: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    l10n = AppStrings.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F7FA);
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF2D3436);

    final String dashboardTitle = l10n.adminDashboard;
    final String tabLaporan = l10n.adminTabLaporan;
    final String tabBanding = l10n.adminTabBanding;
    final String tabSanksi = l10n.adminTabSanksi;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 120.0,
              floating: true,
              pinned: true,
              backgroundColor: isDarkMode ? Colors.black : Colors.white,
              elevation: 0,
              title: Text(
                dashboardTitle,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              centerTitle: false,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: EdgeInsets.zero,
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                          colors: isDarkMode
                              ? [Colors.orange.shade900, Colors.black]
                              : [Colors.orange.shade100, Colors.white],
                        ),
                      ),
                    ),
                    Positioned(
                      right: -20,
                      bottom: -20,
                      child: Opacity(
                        opacity: 0.3,
                        child: Image.asset(
                          'assets/images/Chef_Cei/chefhead.png',
                          height: 160,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.refresh_rounded, color: textColor),
                  onPressed: () {
                    _fetchReports();
                    _fetchAppeals();
                  },
                ),
              ],
              bottom: PreferredSize(
                // Tinggi dinaikkan sedikit untuk mencegah overflow vertikal pada TabBar
                preferredSize: const Size.fromHeight(72),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                      decoration: BoxDecoration(
                        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                        borderRadius: BorderRadius.circular(36),
                        border: Border.all(
                          color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                      child: SizedBox(
                        height: 44,
                        child: TabBar(
                        controller: _tabController,
                        indicatorSize: TabBarIndicatorSize.label,
                        dividerColor: Colors.transparent,
                        // Make the pill indicator inset a bit so it looks like a chip inside the rounded container
                        indicatorPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                        indicator: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.orange, Color(0xFFFF8C00)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        labelColor: Colors.white,
                        unselectedLabelColor: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                        // Use fixed tabs so they divide available width equally
                        labelPadding: EdgeInsets.zero,
                        isScrollable: false,
                        tabs: [
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.report_outlined, size: 16),
                                const SizedBox(width: 8),
                                Text(tabLaporan),
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.gavel_outlined, size: 16),
                                const SizedBox(width: 8),
                                Text(tabBanding),
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.block_outlined, size: 16),
                                const SizedBox(width: 8),
                                Text(tabSanksi),
                              ],
                            ),
                          ),
                        ],
                      ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ]; 
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildReportsList(textColor, cardColor),
            _buildAppealsList(textColor, cardColor),
            _buildSanctionedUsersList(textColor, cardColor),
          ],
        ),
      ),
    );
  }

  Widget _buildSanctionedUsersList(Color textColor, Color cardColor) {
    if (_isLoadingSanctions) {
      return const Center(child: CircularProgressIndicator(color: Colors.orange));
    }

    if (_sanctionedUsers.isEmpty) {
      return AdminEmptyState(
        message: l10n.adminNoSanctionedUsers,
        icon: Icons.check_circle_outline,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _sanctionedUsers.length,
      itemBuilder: (context, index) {
        final user = _sanctionedUsers[index];
        return SanctionedUserCard(
          user: user,
          textColor: textColor,
          cardColor: cardColor,
          onRevoke: () => _revokeSanction(user['id'], user['username'] ?? 'User'),
        );
      },
    );
  }

  Widget _buildReportsList(Color textColor, Color cardColor) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    
    // Filter Logic
    final filteredReports = _reports.where((report) {
      if (_reportFilter == 'all') return true;
      final isComment = report['comments'] != null && (report['comments'] as List).isNotEmpty;
      if (_reportFilter == 'comment') return isComment;
      if (_reportFilter == 'post') return !isComment;
      return true;
    }).toList();

    return Column(
      children: [
        // Filter Header
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              _buildFilterChip(l10n.adminFilterAll, 'all'),
              const SizedBox(width: 8),
              _buildFilterChip(l10n.adminFilterPost, 'post'),
              const SizedBox(width: 8),
              _buildFilterChip(l10n.adminFilterComment, 'comment'),
            ],
          ),
        ),
        // List
        Expanded(
          child: filteredReports.isEmpty 
              ? AdminEmptyState(
                  message: l10n.adminNoReports,
                  icon: Icons.check_circle_outline,
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredReports.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final report = filteredReports[index];
                    final reported = report['reported_profile'];
                    final post = report['posts'];
                    final isCommentReport = report['comments'] != null && (report['comments'] as List).isNotEmpty;

                    return ReportCard(
                      report: report,
                      textColor: textColor,
                      cardColor: cardColor,
                      onDismiss: () => _dismissReport(report['id']),
                      onAction: () => _showActionDialog(report, reported, post, isCommentReport),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _reportFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool selected) {
        setState(() {
          _reportFilter = value;
        });
      },
      backgroundColor: Colors.transparent,
      selectedColor: const Color.fromRGBO(255, 152, 0, 0.2),
      checkmarkColor: Colors.orange,
      labelStyle: TextStyle(
        color: isSelected ? Colors.orange : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.grey),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? Colors.orange : (Theme.of(context).brightness == Brightness.dark ? const Color.fromRGBO(158,158,158,0.3) : Colors.grey.shade300),
        ),
      ),
    );
  }

  Widget _buildAppealsList(Color textColor, Color cardColor) {
    if (_isLoadingAppeals) return const Center(child: CircularProgressIndicator());
    if (_appeals.isEmpty) {
      return AdminEmptyState(
        message: l10n.adminNoAppeals,
        icon: Icons.gavel_rounded,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _appeals.length,
      separatorBuilder: (ctx, i) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final appeal = _appeals[index];
        return AppealCard(
          appeal: appeal,
          textColor: textColor,
          cardColor: cardColor,
          onAccept: () => _handleAppeal(appeal['id'], appeal['user_id'], true),
          onReject: () => _handleAppeal(appeal['id'], appeal['user_id'], false),
        );
      },
    );
  }

  void _showActionDialog(Map<String, dynamic> report, Map<String, dynamic>? reported, Map<String, dynamic>? post, bool isComment) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Pilih Tindakan", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
              ),
              title: const Text("Beri Teguran & Hapus Konten"),
              subtitle: const Text("User akan naik level sanksi. Konten otomatis dihapus."),
              onTap: () {
                Navigator.pop(context);
                _showWarningDurationDialog(report, reported, post, isComment);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.delete_outline, color: Colors.red),
              ),
              title: const Text("Hapus Konten Saja"),
              subtitle: const Text("Tanpa menaikkan level sanksi user."),
              onTap: () {
                Navigator.pop(context);
                if (isComment) {
                  _deleteComment(report['comment_id'], report['id']);
                } else {
                  _deletePost(post?['id'], report['id']);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showWarningDurationDialog(Map<String, dynamic> report, Map<String, dynamic>? reported, Map<String, dynamic>? post, bool isComment) {
    int selectedDuration = 1;
    final warningLevel = reported?['warning_level'] ?? 0;
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Konfirmasi Sanksi"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("User akan naik ke Level ${warningLevel + 1}."),
              const SizedBox(height: 16),
              if (warningLevel + 1 < 3)
                DropdownButtonFormField<int>(
                  value: selectedDuration,
                  decoration: InputDecoration(
                    labelText: "Durasi Pembatasan",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text("1 Hari")),
                      DropdownMenuItem(value: 3, child: Text("3 Hari")),
                      DropdownMenuItem(value: 7, child: Text("7 Hari")),
                      DropdownMenuItem(value: 30, child: Text("30 Hari")),
                      DropdownMenuItem(value: 0, child: Text("Permanen")),
                    ],
                    initialValue: selectedDuration,
                    onChanged: (val) => setState(() => selectedDuration = val!),
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
                  child: const Row(
                    children: [
                      Icon(Icons.block, color: Colors.red),
                      SizedBox(width: 12),
                      Expanded(child: Text("Level 3 = Banned Permanen", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                    ],
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal")),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                // Jika selectedDuration == 0 (Permanen), langsung ban (forceLevel3 = true)
                final bool isPermanent = selectedDuration == 0;
                _issueWarning(
                  report['reported_id'],
                  warningLevel,
                  report['id'],
                  postId: post?['id'],
                  commentId: report['comment_id'],
                  durationDays: isPermanent ? 0 : selectedDuration,
                  forceLevel3: isPermanent,
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text("Eksekusi"),
            ),
          ],
        ),
      ),
    );
  }
}