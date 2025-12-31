import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:timeago/timeago.dart' as timeago;
import 'package:intl/date_symbol_data_local.dart';
import '../../../app/data/providers/language_provider.dart';
import '../../../app/data/providers/notification_provider.dart';
import '../../../app/config/routes.dart';
import '../../community/screens/post_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    initializeDateFormatting('id', null);
    timeago.setLocaleMessages('id', timeago.IdMessages());
    
    // NOTE: do not mark all as read automatically on open.
    // Individual notifications are marked as read when the user taps them
    // (see _handleNotificationTap). This prevents accidental clearing
    // of the unread badge just by opening the screen.
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(lang.getText('notif_title'), style: const TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.orange,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.orange,
          tabs: [
            Tab(text: lang.getText('notif_tab_activity')),
            Tab(text: lang.getText('notif_tab_inbox')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _NotificationList(type: 'social'),
          _NotificationList(type: 'system'),
        ],
      ),
    );
  }
}

class _NotificationList extends StatefulWidget {
  final String type; // 'social' or 'system'
  const _NotificationList({required this.type});

  @override
  State<_NotificationList> createState() => _NotificationListState();
}

class _NotificationListState extends State<_NotificationList> {
  bool _canAppeal = false;
  
  void _showSystemDialog(String title, String content) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(lang.getText('notif_understand'), style: const TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _fetchUserSanctionStatus();
    _fetchNotifications();
  }

  Future<void> _fetchUserSanctionStatus() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      setState(() {
        _canAppeal = false;
      });
      return;
    }
    try {
      final profile = await supabase
          .from('profiles')
          .select('warning_level, sanction_end_time')
          .eq('id', userId)
          .maybeSingle();
      bool sanctioned = false;
      if (profile != null && (profile['warning_level'] ?? 0) > 0) {
        if (profile['sanction_end_time'] == null) {
          sanctioned = true;
        } else {
          final end = DateTime.tryParse(profile['sanction_end_time']);
          if (end != null && end.isAfter(DateTime.now())) {
            sanctioned = true;
          }
        }
      }
      setState(() {
        _canAppeal = sanctioned;
      });
    } catch (e) {
      setState(() {
        _canAppeal = false;
      });
    }
  }

  Future<void> _fetchNotifications() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // UPDATE PENTING:
      // Menggunakan Left Join (post:posts) agar notifikasi Follow/System (yg post_id-nya null)
      // TETAP MUNCUL. Kalau pakai 'posts!post_id' (Inner Join), data null akan ke-skip.
      final response = await supabase
          .from('notifications')
          .select('*, actor:profiles!actor_id(username, avatar_url), post:posts(image_url)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      if (mounted) {
        final List<Map<String, dynamic>> allNotifications = List<Map<String, dynamic>>.from(response);
        List<Map<String, dynamic>> filtered;

        if (widget.type == 'social') {
          filtered = allNotifications.where((n) {
            final type = n['type']?.toString().toLowerCase() ?? '';
            return ['like', 'comment', 'share', 'save', 'mention', 'follow'].contains(type);
          }).toList();
        } else {
          filtered = allNotifications.where((n) {
             final type = n['type']?.toString().toLowerCase() ?? '';
             // Pastikan semua tipe non-sosial masuk sini
             return !['like', 'comment', 'share', 'save', 'mention', 'follow'].contains(type);
          }).toList();
        }

        setState(() {
          _notifications = filtered;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching notifications: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'like': return Icons.favorite;
      case 'comment': return Icons.comment;
      case 'mention': return Icons.alternate_email;
      case 'share': return Icons.send;
      case 'save': return Icons.bookmark;
      case 'follow': return Icons.person_add; // Tambahan icon follow
      case 'system_sanction': return Icons.warning_amber_rounded;
      case 'system_report': return Icons.report_problem_rounded;
      case 'system_delete': return Icons.delete_forever_rounded;
      case 'system_info': return Icons.info_outline_rounded;
      default: return Icons.notifications;
    }
  }

  Color _getIconColor(String type) {
    switch (type) {
      case 'like': return Colors.red;
      case 'comment': return Colors.blue;
      case 'mention': return Colors.purple;
      case 'share': return Colors.green;
      case 'save': return Colors.orange;
      case 'follow': return Colors.blueAccent; // Warna follow
      case 'system_sanction': return Colors.red;
      case 'system_report': return Colors.orange;
      case 'system_delete': return Colors.red;
      case 'system_info': return Colors.blue;
      default: return Colors.grey;
    }
  }

  /// Translate notification message based on pattern matching
  /// This allows localization of messages stored in database as Indonesian
  String _translateMessage(String? message, LanguageProvider lang) {
    if (message == null || message.isEmpty) return '';
    
    final m = message;
    
    // Sanction messages
    if (m.startsWith('Teguran 1:')) {
      final dateMatch = RegExp(r'sampai (.+)\.').firstMatch(m);
      final date = dateMatch?.group(1) ?? 'Permanen';
      return lang.getText('admin_warning_1').replaceAll('@date', date);
    }
    if (m.startsWith('Teguran 2:')) {
      final dateMatch = RegExp(r'sampai (.+)\.').firstMatch(m);
      final date = dateMatch?.group(1) ?? 'Permanen';
      return lang.getText('admin_warning_2').replaceAll('@date', date);
    }
    if (m.startsWith('Teguran 3:')) {
      return lang.getText('admin_warning_3');
    }
    
    // Revoked sanction
    if (m.contains('Sanksi akun Anda telah dicabut')) {
      return lang.getText('notif_sanction_revoked');
    }
    
    // Post deleted
    if (m.contains('Postingan Anda dihapus oleh Admin')) {
      return lang.getText('notif_post_deleted');
    }
    
    // Comment deleted
    if (m.contains('Komentar Anda dihapus oleh Admin')) {
      return lang.getText('notif_comment_deleted');
    }
    
    // Social notifications - these use patterns
    if (m.contains('menyukai postingan Anda')) {
      return lang.getText('notif_liked_post');
    }
    if (m.contains('mengomentari postingan Anda')) {
      final contentMatch = RegExp(r': "(.+)"').firstMatch(m);
      final content = contentMatch?.group(1) ?? '';
      if (content.isNotEmpty) {
        return '${lang.getText('notif_commented_post')}: "$content"';
      }
      return lang.getText('notif_commented_post');
    }
    if (m.contains('membagikan postingan Anda')) {
      return lang.getText('notif_shared_post');
    }
    if (m.contains('menyimpan postingan Anda')) {
      return lang.getText('notif_saved_post');
    }
    if (m.contains('membalas komentar Anda')) {
      final contentMatch = RegExp(r': "(.+)"').firstMatch(m);
      final content = contentMatch?.group(1) ?? '';
      if (content.isNotEmpty) {
        return '${lang.getText('notif_replied_comment')}: "$content"';
      }
      return lang.getText('notif_replied_comment');
    }
    if (m.contains('menyebut Anda')) {
      return lang.getText('notif_mentioned_you');
    }
    if (m.contains('mulai mengikuti Anda')) {
      return lang.getText('notif_followed_you');
    }
    
    // If no pattern matches, return original message
    return m;
  }

  Future<void> _handleNotificationTap(Map<String, dynamic> notif) async {
    final type = (notif['type'] ?? '').toString().toLowerCase();
    final notifId = notif['id'];
    final isRead = notif['is_read'] ?? false;

    // Ambil ID relasi. Prioritaskan field eksplisit.
    final relatedId = notif['related_id'];
    final postId = notif['post_id'] ?? relatedId;
    final commentId = notif['comment_id']; // ID Komentar (BigInt/Int)

    // Mark as read
    if (!isRead) {
      try {
        await supabase.from('notifications').update({'is_read': true}).eq('id', notifId);
        if (mounted) {
          setState(() {
            notif['is_read'] = true;
          });
          
          // FIX: Refresh badge count in NotificationProvider
          Provider.of<NotificationProvider>(context, listen: false).refreshUnreadCount();
        }
      } catch (e) {
        debugPrint("Error marking as read: $e");
      }
    }

    if (!mounted) return;

    // Handle navigasi
    if (['like', 'share', 'save'].contains(type)) {
      if (postId != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostDetailScreen(postId: postId),
          ),
        );
      }
    } else if (type == 'comment' || type == 'mention') {
      // Logic navigasi komentar:
      // 1. Coba pake postId langsung.
      // 2. Kalau postId null (jarang terjadi di notif baru), coba cari via commentId.
      String? resolvedPostId = postId?.toString();
      
      if (resolvedPostId == null && commentId != null) {
        try {
          final commentLookup = await supabase
              .from('comments')
              .select('post_id')
              .eq('id', commentId)
              .maybeSingle();
          if (commentLookup != null) {
            resolvedPostId = commentLookup['post_id']?.toString();
          }
        } catch (e) {
          debugPrint('Error resolving post_id from comment_id: $e');
        }
      }

      if (resolvedPostId != null) {
        // Kirim highlightCommentId biar PostDetailScreen bisa auto-scroll!
        if (commentId != null) {
          Navigator.pushNamed(
            context,
            AppRoutes.commentsRoute,
            arguments: {
              'postId': resolvedPostId,
              'highlightCommentId': commentId.toString(),
            },
          );
        } else {
          Navigator.pushNamed(
            context,
            AppRoutes.commentsRoute,
            arguments: {'postId': resolvedPostId},
          );
        }
      }
    } else if (type == 'follow') {
       // Opsional: Buka profil user yg nge-follow
       final actorId = notif['actor_id'];
       if (actorId != null) {
         Navigator.pushNamed(context, AppRoutes.profileRoute, arguments: actorId);
       }
    } else if (type == 'system_sanction') {
      _showSanctionDialog(notif);
    } else if (type == 'system_info') {
       _showSystemDialog("Info Sistem", notif['message'] ?? "Info baru dari sistem.");
    } else if (type == 'system_delete') {
       _showSystemDialog("Konten Dihapus", notif['message'] ?? "Konten Anda telah dihapus.");
    }
  }

  void _showSanctionDialog(Map<String, dynamic> notif) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(lang.getText('notif_sanction_title'), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
          content: Text(notif['message'] ?? lang.getText('notif_sanction_default')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(lang.getText('notif_understand'), style: const TextStyle(color: Colors.orange)),
            ),
            if (_canAppeal)
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  final result = await _showAppealDialog();
                  if (result == true && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(lang.getText('notif_appeal_sent')), backgroundColor: Colors.green),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: Text(lang.getText('notif_appeal_button')),
              ),
          ],
        );
      },
    );
  }

  Future<bool?> _showAppealDialog() async {
    TextEditingController reasonController = TextEditingController();
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lang.getText('notif_appeal_title')),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: lang.getText('notif_appeal_reason_label'),
            hintText: lang.getText('notif_appeal_reason_hint'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(lang.getText('notif_cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              final userId = Supabase.instance.client.auth.currentUser?.id;
              if (userId != null && reasonController.text.trim().isNotEmpty) {
                await Supabase.instance.client.from('appeals').insert({
                  'user_id': userId,
                  'reason': reasonController.text.trim(),
                  'status': 'pending',
                  'created_at': DateTime.now().toIso8601String(),
                });
                Navigator.pop(context, true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text(lang.getText('notif_appeal_send')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.orange));
    }

    if (_notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(lang.getText('notif_empty'), style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _notifications.length,
      itemBuilder: (context, index) {
        final notif = _notifications[index];
        final actor = notif['actor'];
        final type = notif['type'];
        final isRead = notif['is_read'] ?? false;
        final postImageRaw = notif['post']?['image_url'];

        // Resolve actor avatar safely (support asset: URIs and plain assets path)
        ImageProvider? avatarImage;
        try {
          final aUrl = actor != null ? actor['avatar_url'] : null;
          if (aUrl != null && aUrl is String && aUrl.isNotEmpty) {
            if (aUrl.startsWith('asset:')) {
              avatarImage = AssetImage(aUrl.substring(6));
            } else if (aUrl.startsWith('assets/')) {
              avatarImage = AssetImage(aUrl);
            } else {
              avatarImage = NetworkImage(aUrl);
            }
          }
        } catch (e) {
          avatarImage = null;
        }

        // Prepare trailing widget for post image; handle asset paths too
        Widget? trailingWidget;
        try {
          if (postImageRaw != null && postImageRaw is String && postImageRaw.isNotEmpty) {
            if (postImageRaw.startsWith('asset:')) {
              trailingWidget = ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.asset(
                  postImageRaw.substring(6),
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, st) => const SizedBox(width: 40, height: 40, child: Icon(Icons.image_not_supported, size: 20, color: Colors.grey)),
                ),
              );
            } else if (postImageRaw.startsWith('assets/')) {
              trailingWidget = ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.asset(
                  postImageRaw,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, st) => const SizedBox(width: 40, height: 40, child: Icon(Icons.image_not_supported, size: 20, color: Colors.grey)),
                ),
              );
            } else {
              trailingWidget = ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  postImageRaw,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, st) => const SizedBox(width: 40, height: 40, child: Icon(Icons.image_not_supported, size: 20, color: Colors.grey)),
                ),
              );
            }
          }
        } catch (e) {
          trailingWidget = null;
        }

        return Container(
          color: isRead ? Colors.transparent : Colors.orange.withOpacity(0.1),
          child: ListTile(
            leading: Stack(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: avatarImage,
                  child: avatarImage == null
                      ? const Icon(Icons.person, color: Colors.grey)
                      : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getIcon(type),
                      size: 14,
                      color: _getIconColor(type),
                    ),
                  ),
                ),
              ],
            ),
            title: RichText(
              text: TextSpan(
                style: DefaultTextStyle.of(context).style,
                children: [
                  TextSpan(
                    text: actor != null ? (actor['username'] ?? lang.getText('notif_someone')) : lang.getText('notif_system'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: ' '),
                  TextSpan(text: _translateMessage(notif['message'], lang)),
                ],
              ),
            ),
            subtitle: Text(
              timeago.format(DateTime.parse(notif['created_at']).toLocal(), locale: 'id'),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            trailing: trailingWidget,
            onTap: () => _handleNotificationTap(notif),
          ),
        );
      },
    );
  }
}