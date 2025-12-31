import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../../../app/data/providers/language_provider.dart';
import '../../community/widgets/edit_post_bottom_sheet.dart';

class PostDetailSheet extends StatefulWidget {
  final Map<String, dynamic> post;
  final bool isMyPost;
  final VoidCallback onPin;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final VoidCallback onComment;
  final VoidCallback? onReport;
  final void Function(Map<String, dynamic> updatedPost)? onEditSuccess;
  final VoidCallback? onLike;
  final Future<void> Function(String postId)? onDelete;

  const PostDetailSheet({
    super.key,
    required this.post,
    required this.isMyPost,
    required this.onPin,
    required this.onSave,
    required this.onShare,
    required this.onComment,
    this.onReport,
    this.onEditSuccess,
    this.onLike,
    this.onDelete,
  });

  @override
  State<PostDetailSheet> createState() => _PostDetailSheetState();
}

class _PostDetailSheetState extends State<PostDetailSheet> with SingleTickerProviderStateMixin {
  late List<Map<String, dynamic>> _mediaList;
  int _currentMediaIndex = 0;
  final PageController _pageController = PageController();
  
  // Video player
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isVideoInitialized = false;
  String? _currentVideoUrl;

  // Love animation
  late AnimationController _loveController;
  late Animation<double> _loveScale;
  bool _showLove = false;

  @override
  void initState() {
    super.initState();
    debugPrint('POST_DETAIL_SHEET init for post id=${widget.post['id']} owner=${widget.post['user_id']}');
    _prepareMediaList();
    _loveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loveScale = Tween<double>(begin: 0.5, end: 1.5).animate(
      CurvedAnimation(parent: _loveController, curve: Curves.elasticOut),
    );
    _loveController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) setState(() => _showLove = false);
        });
      }
    });
  }

  void _prepareMediaList() {
    final rawMedia = widget.post['post_media'] as List?;
    if (rawMedia != null && rawMedia.isNotEmpty) {
      _mediaList = List<Map<String, dynamic>>.from(rawMedia);
      _mediaList.sort((a, b) => (a['media_order'] ?? 0).compareTo(b['media_order'] ?? 0));
    } else {
      // Backward compatibility
      _mediaList = [];
      if (widget.post['image_url'] != null || widget.post['video_url'] != null) {
        _mediaList.add({
          'url': widget.post['video_url'] ?? widget.post['image_url'],
          'type': widget.post['video_url'] != null ? 'video' : 'image',
          'thumbnail_url': widget.post['thumbnail_url']
        });
      }
    }
  }

  @override
  void dispose() {
    debugPrint('POST_DETAIL_SHEET dispose for post id=${widget.post['id']}');
    _pageController.dispose();
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    _loveController.dispose();
    super.dispose();
  }

  void _handleDoubleTapLike() {
    setState(() {
      _showLove = true;
    });
    _loveController.forward(from: 0);
    widget.onLike?.call();
  }

  Future<void> _initializeVideo(String videoUrl) async {
    if (_currentVideoUrl == videoUrl && _videoPlayerController != null) return;

    _disposeVideo();

    try {
      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      await _videoPlayerController!.initialize();
      
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(errorMessage, style: const TextStyle(color: Colors.white)),
          );
        },
      );

      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
          _currentVideoUrl = videoUrl;
        });
      }
    } catch (e) {
      debugPrint("Error initializing video: $e");
    }
  }

  void _disposeVideo() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    _videoPlayerController = null;
    _chewieController = null;
  }
  Widget _buildMediaWidget(Map<String, dynamic> media, int index) {
    final isVideo = media['type'] == 'video';
    final url = media['url'] ?? '';
    final thumbnailUrl = media['thumbnail_url'];

    if (isVideo) {
      // Show thumbnail with play button, or video player if initialized
      if (_isVideoInitialized && _currentVideoUrl == url && _chewieController != null) {
        return GestureDetector(
          onDoubleTap: _handleDoubleTapLike,
          child: Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: _videoPlayerController!.value.aspectRatio,
                  child: Chewie(controller: _chewieController!),
                ),
              ),
              if (_showLove)
                ScaleTransition(
                  scale: _loveScale,
                  child: const Icon(Icons.favorite, color: Colors.white, size: 90),
                ),
            ],
          ),
        );
      }
      return GestureDetector(
        onTap: () => _initializeVideo(url),
        onDoubleTap: _handleDoubleTapLike,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 1,
                child: thumbnailUrl != null
                    ? CachedNetworkImage(
                        imageUrl: thumbnailUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(color: Colors.grey[300]),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[800],
                          child: const Icon(Icons.videocam, color: Colors.white54, size: 48),
                        ),
                      )
                    : Container(
                        color: Colors.grey[800],
                        child: const Icon(Icons.videocam, color: Colors.white54, size: 48),
                      ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 40),
            ),
            if (_showLove)
              ScaleTransition(
                scale: _loveScale,
                child: const Icon(Icons.favorite, color: Colors.white, size: 90),
              ),
          ],
        ),
      );
    }

    // Image
    return GestureDetector(
      onTap: () => _showFullscreenImage(url),
      onDoubleTap: _handleDoubleTapLike,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 1,
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                errorWidget: (context, url, error) => const Icon(Icons.broken_image),
              ),
            ),
          ),
          if (_showLove)
            ScaleTransition(
              scale: _loveScale,
              child: const Icon(Icons.favorite, color: Colors.white, size: 90),
            ),
        ],
      ),
    );
  }

  void _showFullscreenImage(String imageUrl) {
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
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
    final subTextColor = Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey;

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.all(16),
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[700] : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header (Author Info) for other users' posts
            if (!widget.isMyPost) ...[
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundImage: widget.post['profiles']?['avatar_url'] != null 
                        ? (widget.post['profiles']['avatar_url'].startsWith('asset:') || widget.post['profiles']['avatar_url'].startsWith('assets/')
                            ? AssetImage(widget.post['profiles']['avatar_url'].startsWith('asset:') 
                                ? widget.post['profiles']['avatar_url'].substring(6).trim() 
                                : widget.post['profiles']['avatar_url']) as ImageProvider
                            : CachedNetworkImageProvider(widget.post['profiles']['avatar_url']))
                        : null,
                    child: widget.post['profiles']?['avatar_url'] == null 
                        ? const Icon(Icons.person, size: 16) 
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.post['profiles']?['full_name'] ?? widget.post['profiles']?['username'] ?? 'Chef',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor),
                    ),
                  ),
                    if (widget.onReport != null)
                    IconButton(
                      icon: Icon(Icons.more_horiz, color: textColor),
                      onPressed: () {
                        debugPrint('POST_DETAIL: opening report menu for post id=${widget.post['id']}');
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                          builder: (ctx) => SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.flag_outlined, color: Colors.red),
                                  title: Text(context.read<LanguageProvider>().getText('report_post')),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    widget.onReport!();
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Three-dot menu for own posts (Edit / Delete)
            if (widget.isMyPost && (widget.onEditSuccess != null || widget.onDelete != null))
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: Icon(Icons.more_horiz, color: textColor),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                      builder: (menuCtx) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.onEditSuccess != null)
                              ListTile(
                                leading: Icon(Icons.edit_outlined, color: textColor),
                                title: Text(context.read<LanguageProvider>().getText('edit')),
                                onTap: () async {
                                  Navigator.pop(menuCtx);
                                  // Close the post sheet first
                                  Navigator.pop(context);
                                  final newCaption = await showModalBottomSheet<String>(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (ctx) => EditPostBottomSheet(post: widget.post),
                                  );
                                  if (newCaption != null) {
                                    final updatedPost = Map<String, dynamic>.from(widget.post);
                                    updatedPost['caption'] = newCaption;
                                    updatedPost['is_edited'] = true;
                                    widget.onEditSuccess!(updatedPost);
                                  }
                                },
                              ),
                            if (widget.onDelete != null)
                              ListTile(
                                leading: const Icon(Icons.delete_outline, color: Colors.red),
                                title: Text(context.read<LanguageProvider>().getText('delete')),
                                onTap: () async {
                                  Navigator.pop(menuCtx);
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: Text(context.read<LanguageProvider>().getText('delete_post_confirm_title')),
                                      content: Text(context.read<LanguageProvider>().getText('delete_post_confirm_desc')),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.read<LanguageProvider>().getText('cancel'))),
                                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.read<LanguageProvider>().getText('delete'), style: const TextStyle(color: Colors.red))),
                                      ],
                                    ),
                                  );
                                  if (confirmed == true) {
                                    // Close the post sheet then call delete
                                    Navigator.pop(context);
                                    try {
                                      await widget.onDelete!(widget.post['id'].toString());
                                    } catch (e) {
                                      debugPrint('Error during delete callback: $e');
                                    }
                                  }
                                },
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

            // Media section (with PageView for multi-slide)
            if (_mediaList.isNotEmpty) ...[
              if (_mediaList.length == 1)
                _buildMediaWidget(_mediaList.first, 0)
              else
                Column(
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.width - 32,
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: _mediaList.length,
                        onPageChanged: (index) {
                          setState(() {
                            _currentMediaIndex = index;
                            // Dispose video when switching pages
                            if (_mediaList[index]['type'] != 'video') {
                              _disposeVideo();
                            }
                          });
                        },
                        itemBuilder: (context, index) => _buildMediaWidget(_mediaList[index], index),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Page indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_mediaList.length, (index) {
                        return Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: index == _currentMediaIndex 
                                ? Colors.orange 
                                : Colors.grey.withOpacity(0.5),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
            ],
            
            // Action Row (Like, Comment, Share, Save/Pin)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: widget.onLike,
                      child: Icon(
                        widget.post['is_liked'] == true ? Icons.favorite : Icons.favorite_border_rounded,
                        color: widget.post['is_liked'] == true ? Colors.red : textColor,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text("${widget.post['like_count'] ?? 0}", style: TextStyle(color: textColor)),
                    
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: widget.onComment,
                      child: Row(
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded, color: textColor, size: 26),
                          const SizedBox(width: 6),
                          Text("${widget.post['comment_count'] ?? 0}", style: TextStyle(color: textColor)),
                        ],
                      ),
                    ),
                    
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: widget.onShare,
                      child: Row(
                        children: [
                          Icon(Icons.send_rounded, color: textColor, size: 26),
                          const SizedBox(width: 6),
                          Text("${widget.post['share_count'] ?? 0}", style: TextStyle(color: textColor)),
                        ],
                      ),
                    ),
                  ],
                ),
                // TOMBOL SAVE SELALU MUNCUL, baik postingan sendiri maupun orang lain
                GestureDetector(
                  onTap: widget.onSave,
                  child: Row(
                    children: [
                      Icon(
                        widget.post['is_saved'] == true ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                        color: widget.post['is_saved'] == true ? Colors.orange : textColor,
                        size: 26,
                      ),
                      const SizedBox(width: 6),
                      Text("${widget.post['save_count'] ?? 0}", style: TextStyle(color: textColor)),
                    ],
                  ),
                ),
                if (widget.isMyPost)
                  IconButton(
                    icon: Icon(
                      widget.post['is_pinned'] == true ? Icons.push_pin : Icons.push_pin_outlined,
                      color: widget.post['is_pinned'] == true ? Colors.orange : subTextColor,
                    ),
                    onPressed: widget.onPin,
                    tooltip: context.read<LanguageProvider>().getText('pin_post'),
                  ),
              ],
            ),

            const SizedBox(height: 12),
            
            // Caption
            Text(
              widget.post['caption'] ?? '',
              style: TextStyle(fontSize: 16, color: textColor),
            ),
            
            const SizedBox(height: 8),

            if ((widget.post['comment_count'] ?? 0) > 0)
              GestureDetector(
                onTap: widget.onComment,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    "Lihat semua ${widget.post['comment_count']} komentar",
                    style: TextStyle(color: subTextColor, fontSize: 14),
                  ),
                ),
              ),

            Text(
              timeago.format(DateTime.parse(widget.post['created_at']).toLocal(), locale: 'id'),
              style: TextStyle(color: subTextColor, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
