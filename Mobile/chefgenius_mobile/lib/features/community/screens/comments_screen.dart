import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../app/data/providers/language_provider.dart';
import '../../../app/services/translation_service.dart';
import '../../pantry/widgets/cei_showcase_wrapper.dart';
import '../../auth/screens/profile_screen.dart';

class CommentsScreen extends StatefulWidget {
  final String postId;
  final String? highlightCommentId;
  const CommentsScreen({super.key, required this.postId, this.highlightCommentId});

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final supabase = Supabase.instance.client;
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _rootCommentKeys = {}; // Keys for scrolling
  bool _isLoading = true;
  bool _isPosting = false;
  List<Map<String, dynamic>> _comments = [];
  String? _postOwnerId;
  Map<String, dynamic>? _postData; // Data postingan untuk caption
  Map<String, dynamic>? _replyingTo; // State for reply
  String? _editingCommentId; // State for editing

  // Showcase
  final GlobalKey _emojiShowcaseKey = GlobalKey();
  bool _hasCheckedShowcase = false;

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id', null);
    timeago.setLocaleMessages('id', timeago.IdMessages());
    _fetchComments();
  }

  void _showEmojiPicker() {
    final List<String> emojis = [
      'excited.png', 'genit.png', 'marah.png', 'nyapa.png', 'wow.png'
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: 250,
          child: Column(
            children: [
              const Text("Pilih Stiker Chef Cei", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: emojis.length,
                  itemBuilder: (context, index) {
                    final emojiName = emojis[index];
                    final assetPath = 'assets/images/emoji/$emojiName';
                    return GestureDetector(
                      onTap: () {
                        _postComment(content: "[sticker:$assetPath]");
                        Navigator.pop(context);
                      },
                      child: Image.asset(assetPath),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _fetchComments() async {
    try {
      // 1. Ambil Data Postingan (Caption, Owner, dll)
      if (_postData == null) {
         final data = await supabase
             .from('posts')
             .select('*, profiles!posts_user_id_fkey(username, avatar_url, full_name)')
             .eq('id', widget.postId)
             .maybeSingle();
         if (data != null) {
           _postData = data;
           _postOwnerId = data['user_id'];
         }
      }

      // 2. Ambil komen + data user yang komen
      final response = await supabase
          .from('comments')
          .select('*, profiles(full_name, username, avatar_url)')
          .eq('post_id', widget.postId)
          .order('created_at', ascending: false); // IG Style: Newest first

      if (mounted) {
        setState(() {
          _comments = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });

        if (widget.highlightCommentId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToHighlightedComment();
          });
        }
      }
    } catch (e) {
      debugPrint("Gagal load komen: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _scrollToHighlightedComment() async {
    if (widget.highlightCommentId == null) return;
    
    // Tunggu sebentar biar UI stabil dulu
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    // Find root ancestor
    String? rootId = _findRootAncestor(widget.highlightCommentId!);
    debugPrint("DEBUG: Scrolling to rootId: $rootId for highlightId: ${widget.highlightCommentId}");
    
    if (rootId != null) {
      // Cek apakah key sudah ada
      if (_rootCommentKeys.containsKey(rootId)) {
        final key = _rootCommentKeys[rootId];
        
        // Jika widget belum dirender (context null), kita coba scroll manual dulu
        if (key?.currentContext == null) {
           final rootComments = _comments.where((c) => c['parent_id'] == null).toList();
           final index = rootComments.indexWhere((c) => c['id'].toString() == rootId);
           
           if (index != -1) {
             // Estimasi posisi: index * tinggi rata-rata (misal 120px)
             double estimatedOffset = index * 120.0;
             
             if (_scrollController.hasClients) {
               // Clamp offset
               if (estimatedOffset > _scrollController.position.maxScrollExtent) {
                 estimatedOffset = _scrollController.position.maxScrollExtent;
               }
               
               await _scrollController.animateTo(
                 estimatedOffset, 
                 duration: const Duration(milliseconds: 500), 
                 curve: Curves.easeOut
               );
               
               // Tunggu render setelah scroll
               await Future.delayed(const Duration(milliseconds: 500));
             }
           }
        }

        // Coba ensureVisible lagi (sekarang harusnya udah dirender karena cacheExtent besar atau udah discroll)
        // Kita coba retry beberapa kali
        for (int i = 0; i < 3; i++) {
          if (key?.currentContext != null) {
            await Scrollable.ensureVisible(
              key!.currentContext!,
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeInOut,
              alignment: 0.1, 
            );
            break; // Berhasil scroll
          }
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }
    }
  }

  String? _findRootAncestor(String commentId) {
    final map = {for (var c in _comments) c['id'].toString(): c};
    
    String currentId = commentId;
    // Prevent infinite loop with max depth or visited set, though DB should be acyclic
    int depth = 0;
    while (map.containsKey(currentId) && depth < 100) {
      final comment = map[currentId]!;
      final parentId = comment['parent_id'];
      if (parentId == null) {
        return currentId;
      }
      currentId = parentId.toString();
      depth++;
    }
    return null;
  }

  String _formatCommentTime(String? dateString) {
    if (dateString == null) return '';
    
    DateTime date = DateTime.parse(dateString);

    // FIX TIMEZONE (Sama kayak di CommunityScreen)
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
      return DateFormat('d/M/yy HH:mm', 'id').format(localDate);
    } else {
      return timeago.format(localDate, locale: 'id');
    }
  }

  Future<void> _deleteComment(dynamic commentId) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      final comment = _comments.firstWhere((c) => c['id'] == commentId, orElse: () => {});

      await supabase.from('comments').delete().eq('id', commentId);
      
      // Update comment_count di posts
      try {
        final countResult = await supabase
            .from('comments')
            .select('id')
            .eq('post_id', widget.postId);
        final newCount = (countResult as List).length;
        await supabase.from('posts').update({'comment_count': newCount}).eq('id', widget.postId);
      } catch (e) {
        debugPrint("DEBUG: Error updating comment_count: $e");
      }
      
      // FIX DELETE NOTIFICATION
      // Hapus notifikasi berdasarkan comment_id biar presisi.
      // Dulu pake related_id (postId), itu bisa ngehapus notif komen lain dari user yg sama.
      if (userId != null && comment.isNotEmpty && comment['user_id'] == userId) {
        await supabase.from('notifications').delete().match({
          'comment_id': commentId, // Hapus spesifik notif utk komen ini
        });
      }

      setState(() {
        _comments.removeWhere((c) => c['id'] == commentId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Sip! Komentar udah dihapus ya.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Waduh, gagal hapus komentar nih. Coba lagi ya!")),
        );
      }
    }
  }

  Future<void> _editComment(dynamic commentId, String oldContent) async {
    setState(() {
      _editingCommentId = commentId.toString();
      _replyingTo = null; // Cancel reply if any
      _commentController.text = oldContent;
    });
    _focusNode.requestFocus();
  }

  Future<void> _reportComment(dynamic commentId) async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text(
                  "Laporin Komentar",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: "Alasan lapor...",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.orange, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: const Text("Batal", style: TextStyle(color: Colors.black87)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final reason = controller.text.trim();
                        if (reason.isEmpty) return;
                        Navigator.pop(ctx);
                        
                        try {
                          final userId = supabase.auth.currentUser?.id;
                          if (userId == null) return;

                          // UPDATE: Ambil ID pemilik komentar dari list _comments
                          final reportedUserId = _comments.firstWhere((c) => c['id'] == commentId)['user_id'];

                          await supabase.from('reports').insert({
                            'reporter_id': userId,
                            'post_id': widget.postId, 
                            'comment_id': commentId, // Tambahkan ID Komentar
                            'reason': reason, 
                            'reported_id': reportedUserId, 
                            'status': 'pending'
                          });

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Laporan diterima. Makasih udah bantu jaga komunitas! 🛡️")),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Waduh, gagal lapor nih. Coba lagi ya!")),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text("Laporin"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pinComment(Map<String, dynamic> comment) async {
    final isPinned = comment['is_pinned'] == true;
    final commentId = comment['id'];

    // Check limit if pinning
    if (!isPinned) {
      final pinnedCount = _comments.where((c) => c['is_pinned'] == true).length;
      if (pinnedCount >= 3) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Maksimal 3 komentar yang bisa disematkan.")),
          );
        }
        return;
      }
    }

    try {
      await supabase
          .from('comments')
          .update({'is_pinned': !isPinned})
          .eq('id', commentId);

      setState(() {
        final index = _comments.indexWhere((c) => c['id'] == commentId);
        if (index != -1) {
          _comments[index]['is_pinned'] = !isPinned;
        }
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isPinned ? "Komentar dilepas dari sematan." : "Komentar disematkan.")),
        );
      }
    } catch (e) {
      debugPrint("Error pinning comment: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Gagal menyematkan komentar.")),
        );
      }
    }
  }

  void _showCommentOptions(Map<String, dynamic> comment) {
    final userId = supabase.auth.currentUser?.id;
    final isMyComment = comment['user_id'] == userId;
    final isPostOwner = _postOwnerId == userId;
    final isPinned = comment['is_pinned'] == true;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (ctx) => Wrap(
        children: [
          if (isPostOwner)
             ListTile(
              leading: Icon(Icons.push_pin, color: isPinned ? Colors.grey : Colors.orange),
              title: Text(isPinned ? "Lepas Sematan" : "Sematkan Komentar", 
                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87)),
              onTap: () {
                Navigator.pop(ctx);
                _pinComment(comment);
              },
            ),

          if (isMyComment)
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.orange),
              title: Text("Edit Komentar", 
                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87)),
              onTap: () {
                Navigator.pop(ctx);
                _editComment(comment['id'], comment['content']);
              },
            ),
          
          if (isMyComment || isPostOwner)
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text("Hapus Komentar", style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                showDialog(
                  context: context,
                  builder: (dCtx) => AlertDialog(
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    title: Text("Hapus Komentar?", 
                      style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(dCtx), 
                        child: Text("Batal", 
                          style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.black54))),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(dCtx);
                          _deleteComment(comment['id']);
                        },
                        child: const Text("Hapus", style: TextStyle(color: Colors.red)),
                      )
                    ],
                  ),
                );
              },
            ),

          if (!isMyComment)
            ListTile(
              leading: const Icon(Icons.flag, color: Colors.orange),
              title: Text("Laporin Komentar",
                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87)),
              onTap: () {
                Navigator.pop(ctx);
                _reportComment(comment['id']);
              },
            ),
        ],
      ),
    );
  }

  // --- HELPER: CEK STATUS SANKSI (Copy dari CommunityScreen) ---
  Future<bool> _checkRestriction() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return false;

    try {
      final response = await supabase
          .from('profiles')
          .select('warning_level')
          .eq('id', userId)
          .single();
      
      final level = response['warning_level'] as int? ?? 0;

      if (level >= 1) { // Level 1 udah gak boleh komen
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Ups, fitur komentar lagi istirahat dulu ya (Sanksi Akun)."), backgroundColor: Colors.orange),
          );
        }
        return true; 
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> _postComment({String? content}) async {
    if (await _checkRestriction()) return;
    if (!mounted) return;

    final text = content ?? _commentController.text.trim();
    // final lang = context.read<LanguageProvider>();
    if (text.isEmpty) return;

    // FILTER KATA KASAR
    if (_isProfane(text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Waduh, ada kata yang kurang pas nih. Yuk pake bahasa yang lebih adem!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isPosting = true);
    
    try {
      final userId = supabase.auth.currentUser!.id;

      if (_editingCommentId != null) {
         await supabase
            .from('comments')
            .update({
              'content': text,
              'is_edited': true,
            })
            .eq('id', _editingCommentId!);

         setState(() {
            final index = _comments.indexWhere((c) => c['id'].toString() == _editingCommentId);
            if (index != -1) {
              _comments[index]['content'] = text;
              _comments[index]['is_edited'] = true;
            }
            _editingCommentId = null;
            _commentController.clear();
         });
         
         if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Komentar berhasil diedit!")),
            );
         }
         return;
      }
      
      // Kirim ke database
      final Map<String, dynamic> commentData = {
        'post_id': widget.postId,
        'user_id': userId,
        'content': text,
      };

      if (_replyingTo != null) {
        // Pastikan parent_id dikirim sebagai String untuk menghindari error tipe data
        // Jika ID aslinya int, toString() aman. Jika UUID, juga aman.
        commentData['parent_id'] = _replyingTo!['id'].toString(); 
      }

      debugPrint("DEBUG: Sending comment data: $commentData");
      final insertedComment = await supabase.from('comments').insert(commentData).select().single();
      final newCommentId = insertedComment['id'];
      debugPrint("DEBUG: Comment inserted successfully");
      
      // Update comment_count di posts
      try {
        // Hitung jumlah komentar baru
        final countResult = await supabase
            .from('comments')
            .select('id')
            .eq('post_id', widget.postId);
        final newCount = (countResult as List).length;
        await supabase.from('posts').update({'comment_count': newCount}).eq('id', widget.postId);
      } catch (e) {
        debugPrint("DEBUG: Error updating comment_count: $e");
      }

      // ============================================
      // FIX NOTIFIKASI - BAGIAN KRUSIAL
      // ============================================

      // HELPER: Format notification message (handle sticker)
      String notifMessage(String action, String content) {
        if (content.startsWith('[sticker:') && content.endsWith(']')) {
          return '$action dengan stiker 🎉';
        }
        return '$action: "$content"';
      }

      // 1. CEK MENTION (@username)
      try {
        final mentionRegex = RegExp(r"@(\w+)");
        final matches = mentionRegex.allMatches(text);
        final mentionedUsernames = matches.map((m) => m.group(1)).toSet();

        for (final username in mentionedUsernames) {
          if (username == null) continue;
          
          // Cari ID user berdasarkan username
          final userRes = await supabase
              .from('profiles')
              .select('id')
              .eq('username', username)
              .maybeSingle();
              
          if (userRes != null) {
            final mentionedUserId = userRes['id'];
            // Jangan notif diri sendiri
            if (mentionedUserId != userId) {
              await supabase.from('notifications').insert({
                'user_id': mentionedUserId,
                'actor_id': userId,
                'type': 'mention',
                'message': notifMessage('membalas komentar Anda', text),
                // FIX: Gunakan related_id = Post ID agar konsisten, tapi comment_id tetap dikirim
                'related_id': widget.postId, 
                'post_id': widget.postId,
                'comment_id': newCommentId,
                'is_read': false
              });
            }
          }
        }
      } catch (e) {
        debugPrint("DEBUG: Error sending mention notification: $e");
      }

      // 2. NOTIFIKASI KE PEMILIK POSTINGAN
      try {
        // FIX: Fallback fetch post owner if not yet loaded
        String? postOwnerId = _postOwnerId;
        if (postOwnerId == null) {
          debugPrint("DEBUG: _postOwnerId is null, fetching from DB...");
          final postData = await supabase
              .from('posts')
              .select('user_id')
              .eq('id', widget.postId)
              .maybeSingle();
          if (postData != null) {
            postOwnerId = postData['user_id']?.toString();
            _postOwnerId = postOwnerId; // Cache for future use
          }
        }
        
        debugPrint("DEBUG: postOwnerId=$postOwnerId, currentUserId=$userId");
        
        if (postOwnerId != null && postOwnerId != userId) {
           debugPrint("DEBUG: Sending notification to post owner: $postOwnerId");
           await supabase.from('notifications').insert({
             'user_id': postOwnerId,
             'actor_id': userId,
             'type': 'comment',
             'message': notifMessage('mengomentari postingan Anda', text),
             // FIX: Gunakan related_id = Post ID (cleaner), comment_id jadi unique key
             'related_id': widget.postId,
             'post_id': widget.postId,
             'comment_id': newCommentId,
             'is_read': false
           });
           debugPrint("DEBUG: ✅ Notification sent to post owner successfully");
        } else {
           debugPrint("DEBUG: ⚠️ Not sending owner notification - postOwnerId=$postOwnerId, userId=$userId");
        }
      } catch (e) {
        debugPrint("DEBUG: Error sending owner notification: $e");
      }

      // 3. NOTIFIKASI KE ORANG YANG DIBALAS (REPLY)
      try {
        if (_replyingTo != null) {
          final replyToUserId = _replyingTo!['user_id'];
          // Kirim notif jika yang dibalas BUKAN diri sendiri DAN BUKAN pemilik postingan (karena pemilik udah dapet notif di atas)
          if (replyToUserId != userId && replyToUserId != _postOwnerId) {
             await supabase.from('notifications').insert({
               'user_id': replyToUserId,
               'actor_id': userId,
               'type': 'comment', // Tetap pakai tipe comment atau bisa 'reply' jika ada
               'message': notifMessage('membalas komentar Anda', text),
               // FIX: Gunakan related_id = Post ID
               'related_id': widget.postId,
               'post_id': widget.postId,
               'comment_id': newCommentId,
               'is_read': false
             });
          }
        }
      } catch (e) {
        debugPrint("DEBUG: Error sending reply notification: $e");
      }

      _commentController.clear();
      setState(() {
        _replyingTo = null;
      });
      // Refresh list komen biar muncul
      await _fetchComments();
      
    } catch (e) {
      debugPrint("Error posting comment: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal mengirim komentar: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  bool _isProfane(String text) {
    final List<String> badWords = [
      "anjing", "babi", "bangsat", "tolol", "goblok", "bodoh", "fuck", "shit", 
      "asshole", "bitch", "kontol", "memek", "jembut", "ngentot", "pantek", 
      "pukimak", "sialan", "brengsek", "bajingan", "asu", "kampret", "idiot",
      "lonte", "bencong", "jablay", "tai", "bgst", "ajg", "tolol"
    ];
    
    final lowerText = text.toLowerCase();
    final words = lowerText.split(RegExp(r'\s+')); 
    
    for (final word in words) {
      // Hapus tanda baca sederhana
      final cleanWord = word.replaceAll(RegExp(r'[^\w\s]'), '');
      if (badWords.contains(cleanWord)) return true;
    }
    return false;
  }

  void _replyToComment(Map<String, dynamic> comment) {
    setState(() {
      _replyingTo = comment;
    });
    final username = comment['profiles']?['username'] ?? 'User';
    _commentController.text = "@$username ";
    _commentController.selection = TextSelection.fromPosition(
      TextPosition(offset: _commentController.text.length),
    );
    _focusNode.requestFocus();
  }

  void _checkShowcase(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      final hasSeen = prefs.getBool('hasSeenEmojiShowcase') ?? false;
      
      if (!hasSeen && mounted) {
        ShowCaseWidget.of(context).startShowCase([_emojiShowcaseKey]);
        await prefs.setBool('hasSeenEmojiShowcase', true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    
    // Group comments by parent_id
    final Map<String, List<Map<String, dynamic>>> groupedComments = {};
    final List<Map<String, dynamic>> rootComments = [];

    for (var c in _comments) {
      final parentId = c['parent_id'];
      if (parentId == null) {
        rootComments.add(c);
      } else {
        groupedComments.putIfAbsent(parentId.toString(), () => []).add(c);
      }
    }

    // Sort Root Comments: Pinned first, then Newest (DESC)
    rootComments.sort((a, b) {
      final bool aPinned = a['is_pinned'] ?? false;
      final bool bPinned = b['is_pinned'] ?? false;
      if (aPinned != bPinned) return aPinned ? -1 : 1;
      
      final DateTime aTime = DateTime.parse(a['created_at']);
      final DateTime bTime = DateTime.parse(b['created_at']);
      return bTime.compareTo(aTime); // DESC
    });

    // Sort Replies: Oldest first (ASC) for conversation flow
    groupedComments.forEach((key, list) {
      list.sort((a, b) {
        final DateTime aTime = DateTime.parse(a['created_at']);
        final DateTime bTime = DateTime.parse(b['created_at']);
        return aTime.compareTo(bTime); // ASC
      });
    });

    return ShowCaseWidget(
      builder: (context) {
          if (!_hasCheckedShowcase) {
             _checkShowcase(context);
             _hasCheckedShowcase = true;
          }
          return Scaffold(
      appBar: AppBar(title: Text(lang.getText('comments_title'))),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    controller: _scrollController,
                    cacheExtent: 5000,
                    padding: const EdgeInsets.all(16),
                    children: [
                      // CAPTION (IG Style)
                      if (_postData != null && (_postData!['caption'] != null && _postData!['caption'].toString().isNotEmpty)) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () {
                                final rawUrl = _postData!['profiles']?['avatar_url'];
                                if (rawUrl != null && rawUrl.toString().isNotEmpty) {
                                  final url = rawUrl.toString().trim();
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => Dialog(
                                      backgroundColor: Colors.transparent,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: (url.startsWith('asset:') || url.startsWith('assets/'))
                                            ? Image.asset(
                                                url.startsWith('asset:') ? url.substring(6) : url,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) => Container(
                                                  color: Colors.white,
                                                  padding: const EdgeInsets.all(20),
                                                  child: const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                                                ),
                                              )
                                            : Image.network(
                                                url,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) => Container(
                                                  color: Colors.white,
                                                  padding: const EdgeInsets.all(20),
                                                  child: const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                                                ),
                                              ),
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: CircleAvatar(
                                radius: 18,
                                backgroundColor: Colors.grey.shade200,
                                backgroundImage: (_postData!['profiles']?['avatar_url'] != null && _postData!['profiles']!['avatar_url'].toString().isNotEmpty)
                                    ? (_postData!['profiles']!['avatar_url'].toString().startsWith('asset:')
                                        ? AssetImage(_postData!['profiles']!['avatar_url'].toString().substring(6)) as ImageProvider
                                        : NetworkImage(_postData!['profiles']!['avatar_url']))
                                    : NetworkImage(
                                        'https://ui-avatars.com/api/?name=${_postData!['profiles']?['username'] ?? 'User'}'
                                      ),
                                onBackgroundImageError: (_postData!['profiles']?['avatar_url'] != null && _postData!['profiles']!['avatar_url'].toString().isNotEmpty)
                                    ? (exception, stackTrace) {
                                        debugPrint('Error loading post owner avatar: $exception');
                                      }
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  RichText(
                                    text: TextSpan(
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87,
                                        decoration: TextDecoration.none,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: "${_postData!['profiles']?['username'] ?? 'User'} ",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold, 
                                            fontSize: 14, 
                                            color: Theme.of(context).textTheme.bodyMedium?.color,
                                            decoration: TextDecoration.none,
                                          ),
                                        ),
                                        TextSpan(
                                          text: _postData!['caption'],
                                          style: TextStyle(
                                            fontSize: 14, 
                                            color: Theme.of(context).textTheme.bodyMedium?.color,
                                            decoration: TextDecoration.none,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatCommentTime(_postData!['created_at']),
                                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 32, thickness: 0.5),
                      ],

                      if (rootComments.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: Center(
                            child: Text(lang.getText('comments_empty'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.grey)),
                          ),
                        )
                      else
                        ...rootComments.map((comment) {
                          final key = _rootCommentKeys.putIfAbsent(comment['id'].toString(), () => GlobalKey());

                          return _CommentTile(
                            key: key,
                            comment: comment,
                            groupedComments: groupedComments,
                            currentUserId: supabase.auth.currentUser?.id ?? '',
                            postOwnerId: _postOwnerId,
                            onReply: _replyToComment,
                            onOptions: _showCommentOptions,
                            formatTime: _formatCommentTime,
                            isRoot: true,
                            highlightCommentId: widget.highlightCommentId,
                          );
                        }).toList(),
                    ],
                  ),
          ),
          if (_replyingTo != null || _editingCommentId != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey.withOpacity(0.1),
              child: Row(
                children: [
                  Text(_editingCommentId != null 
                      ? "Edit Komentar" 
                      : "Membalas ${_replyingTo!['profiles']?['username'] ?? 'User'}"),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () {
                      setState(() {
                        _replyingTo = null;
                        _editingCommentId = null;
                        _commentController.clear();
                      });
                    },
                  )
                ],
              ),
            ),
          // Input Section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.2))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      hintText: lang.getText('comments_hint'),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.withOpacity(0.1),
                      prefixIcon: CeiShowcaseWrapper(
                        showcaseKey: _emojiShowcaseKey,
                        title: "Stiker Seru!",
                        description: "Ekspresikan dirimu dengan stiker Chef Cei yang lucu-lucu di kolom komentar!",
                        child: IconButton(
                          tooltip: "Stiker Chef Cei",
                          icon: Image.asset(
                            'assets/images/Chef_Cei/chefceihead.png',
                            width: 28,
                            height: 28,
                          ),
                          onPressed: _showEmojiPicker,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isPosting ? null : () => _postComment(),
                  icon: _isPosting 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                    : Icon(_editingCommentId != null ? Icons.check : Icons.send, color: Colors.orange),
                ),
              ],
            ),
          ),
        ],
      ),
          );
        }
      );
  }
}

class _CommentTile extends StatefulWidget {
  final Map<String, dynamic> comment;
  final Map<String, List<Map<String, dynamic>>> groupedComments;
  final String currentUserId;
  final String? postOwnerId;
  final Function(Map<String, dynamic>) onReply;
  final Function(Map<String, dynamic>) onOptions;
  final String Function(String?) formatTime;
  final bool isRoot;
  final String? highlightCommentId;

  const _CommentTile({
    Key? key,
    required this.comment,
    required this.groupedComments,
    required this.currentUserId,
    required this.postOwnerId,
    required this.onReply,
    required this.onOptions,
    required this.formatTime,
    this.isRoot = true,
    this.highlightCommentId,
  }) : super(key: key);

  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile> {
  bool _expanded = false;
  
  // Translation State
  String? _translatedContent;
  bool _isTranslating = false;
  final TranslationService _translationService = TranslationService();

  @override
  void initState() {
    super.initState();
    if (widget.highlightCommentId != null) {
      _checkExpand();
    }
  }

  void _checkExpand() {
    final replies = widget.groupedComments[widget.comment['id'].toString()] ?? [];
    // Check direct children or descendants
    if (replies.any((r) => _isOrHasHighlighted(r))) {
      _expanded = true;
    }
  }

  bool _isOrHasHighlighted(Map<String, dynamic> comment) {
    if (comment['id'].toString() == widget.highlightCommentId) return true;
    final replies = widget.groupedComments[comment['id'].toString()] ?? [];
    for (var reply in replies) {
      if (_isOrHasHighlighted(reply)) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final replies = widget.groupedComments[widget.comment['id'].toString()] ?? [];
    
    final showReplies = _expanded ? replies : replies.take(3).toList();
    final remaining = replies.length - 3;

    final profile = widget.comment['profiles'] ?? {};
    final name = profile['full_name'] ?? profile['username'] ?? 'User';
    final avatarUrl = profile['avatar_url'];
    final content = widget.comment['content'] ?? '';
    final createdString = widget.comment['created_at'];
    
    final isPostOwner = widget.postOwnerId != null && widget.comment['user_id'] == widget.postOwnerId;
    final isHighlighted = widget.comment['id'].toString() == widget.highlightCommentId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TweenAnimationBuilder<Color?>(
          tween: ColorTween(
            begin: isHighlighted ? Colors.orange.withOpacity(0.5) : Colors.transparent,
            end: isHighlighted ? Colors.orange.withOpacity(0.15) : Colors.transparent,
          ),
          duration: const Duration(seconds: 2),
          curve: Curves.easeOut,
          builder: (context, color, child) {
            return Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
                border: isHighlighted ? Border.all(color: Colors.orange.withOpacity(0.5)) : null,
              ),
              child: child,
            );
          },
          child: InkWell(
            onLongPress: () => widget.onOptions(widget.comment),
            child: Padding(
              padding: EdgeInsets.only(bottom: 16.0, left: widget.isRoot ? 0 : 0, top: isHighlighted ? 8.0 : 0, right: isHighlighted ? 8.0 : 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isHighlighted) const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      // Navigate to user profile
                      final commentUserId = widget.comment['user_id'];
                      if (commentUserId != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProfileScreen(userId: commentUserId.toString()),
                          ),
                        );
                      }
                    },
                    onLongPress: () {
                      // Long press to show avatar in dialog
                      if (avatarUrl != null && avatarUrl.isNotEmpty) {
                        final url = avatarUrl.trim();
                        showDialog(
                          context: context,
                          builder: (ctx) => Dialog(
                            backgroundColor: Colors.transparent,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: (url.startsWith('asset:') || url.startsWith('assets/'))
                                  ? Image.asset(
                                      url.startsWith('asset:') ? url.substring(6) : url,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        color: Colors.white,
                                        padding: const EdgeInsets.all(20),
                                        child: const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                                      ),
                                    )
                                  : Image.network(
                                      url,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        color: Colors.white,
                                        padding: const EdgeInsets.all(20),
                                        child: const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                                      ),
                                    ),
                            ),
                          ),
                        );
                      }
                    },
                    child: CircleAvatar(
                      radius: widget.isRoot ? 18 : 14,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                          ? (avatarUrl.startsWith('asset:') 
                              ? AssetImage(avatarUrl.substring(6)) as ImageProvider
                              : NetworkImage(avatarUrl))
                          : null,
                      onBackgroundImageError: (avatarUrl != null && avatarUrl.isNotEmpty)
                          ? (exception, stackTrace) {
                              debugPrint('Error loading avatar: $exception');
                            }
                          : null,
                      child: (avatarUrl == null || avatarUrl.isEmpty) 
                          ? Icon(Icons.person, size: widget.isRoot ? 20 : 16, color: Colors.grey) 
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            if (widget.comment['is_pinned'] == true) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.push_pin, size: 12, color: Colors.grey),
                              const SizedBox(width: 2),
                              const Text(
                                "Disematkan",
                                style: TextStyle(fontSize: 10, color: Colors.grey),
                              ),
                            ],
                            if (isPostOwner) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.orange, width: 0.5),
                                ),
                                child: const Text(
                                  "Pemilik",
                                  style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                            const SizedBox(width: 8),
                            Text(
                              widget.formatTime(createdString),
                              style: const TextStyle(color: Colors.grey, fontSize: 10),
                            ),
                            if (widget.comment['is_edited'] == true) ...[
                              const SizedBox(width: 4),
                              const Text(
                                "(diedit)",
                                style: TextStyle(color: Colors.grey, fontSize: 10, fontStyle: FontStyle.italic),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Builder(
                          builder: (context) {
                            final textContent = content.isNotEmpty ? content : '';
                            final stickerRegex = RegExp(r'^\[sticker:(.+)\]$');
                            final match = stickerRegex.firstMatch(textContent);
                            if (match != null) {
                              final assetPath = match.group(1);
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Image.asset(
                                  assetPath!, 
                                  height: 80, 
                                  width: 80,
                                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 40, color: Colors.grey),
                                ),
                              );
                            }
                            
                            // Check if translation is needed
                            final langProvider = context.watch<LanguageProvider>();
                            final appLang = langProvider.appLocale.languageCode;
                            final needsTranslate = _translationService.needsTranslation(textContent, appLang);
                            final isDarkMode = Theme.of(context).brightness == Brightness.dark;
                            
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Original comment text
                                Text(
                                  textContent,
                                  style: TextStyle(
                                    color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87,
                                  ),
                                ),
                                
                                // Translated content
                                if (_translatedContent != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: isDarkMode ? Colors.blue.withValues(alpha: 0.1) : Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isDarkMode ? Colors.blue.withValues(alpha: 0.3) : Colors.blue.shade100,
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Icon(Icons.translate, size: 12, color: Colors.blue.shade400),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              _translatedContent!,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDarkMode ? Colors.blue.shade200 : Colors.blue.shade800,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                
                                // Translate button
                                if (needsTranslate || _translatedContent != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: GestureDetector(
                                      onTap: _isTranslating ? null : () async {
                                        if (_translatedContent != null) {
                                          setState(() => _translatedContent = null);
                                        } else {
                                          setState(() => _isTranslating = true);
                                          final result = await _translationService.translate(
                                            text: textContent,
                                            targetLanguage: appLang,
                                          );
                                          if (mounted) {
                                            setState(() {
                                              _translatedContent = result;
                                              _isTranslating = false;
                                            });
                                          }
                                        }
                                      },
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (_isTranslating)
                                            const SizedBox(
                                              width: 10,
                                              height: 10,
                                              child: CircularProgressIndicator(strokeWidth: 1.5),
                                            )
                                          else
                                            Icon(
                                              Icons.translate,
                                              size: 11,
                                              color: _translatedContent != null ? Colors.blue : Colors.grey[600],
                                            ),
                                          const SizedBox(width: 3),
                                          Text(
                                            _isTranslating
                                              ? "..."
                                              : (_translatedContent != null ? "Sembunyikan" : "Terjemahkan"),
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: _translatedContent != null ? Colors.blue : Colors.grey[600],
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          }
                        ),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () => widget.onReply(widget.comment),
                          child: Text(
                            "Balas",
                            style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Replies Section
        if (replies.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(left: widget.isRoot ? 48.0 : 0.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...showReplies.map((reply) => _CommentTile(
                  key: ValueKey(reply['id']),
                  comment: reply,
                  groupedComments: widget.groupedComments,
                  currentUserId: widget.currentUserId,
                  postOwnerId: widget.postOwnerId,
                  onReply: widget.onReply,
                  onOptions: widget.onOptions,
                  formatTime: widget.formatTime,
                  isRoot: false,
                  highlightCommentId: widget.highlightCommentId,
                )),
                if (!_expanded && remaining > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                    child: GestureDetector(
                      onTap: () => setState(() => _expanded = true),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 1,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Lihat $remaining balasan lainnya",
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}