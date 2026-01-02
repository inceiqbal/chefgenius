import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:provider/provider.dart';
import '../../../app/config/routes.dart';
import '../../../app/services/translation_service.dart';
import '../../../app/data/providers/language_provider.dart';
import 'full_screen_image_viewer.dart';

class PostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final int index;
  final Function(int, String) onLike;
  final Function(int, String) onSave;
  final Function(Map<String, dynamic>, int) onShare;
  final Function(Map<String, dynamic>, int) onOptions;
  final Function(int) onRecookTap;
  final Function(String) onCommentTap;
  final Function(String) onLikesTap;
  final String Function(String?) formatTime;

  const PostCard({
    super.key,
    required this.post,
    required this.index,
    required this.onLike,
    required this.onSave,
    required this.onShare,
    required this.onOptions,
    required this.onRecookTap,
    required this.onCommentTap,
    required this.onLikesTap,
    required this.formatTime,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _heartAnimationController;
  late Animation<double> _heartScaleAnimation;
  bool _showHeartOverlay = false;
  Offset _tapPosition = Offset.zero;

  // Media Carousel State
  int _currentMediaIndex = 0;
  late List<Map<String, dynamic>> _mediaList;

  // Video Controllers
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isVideoPlaying = false;
  String? _currentVideoUrl;

  // Translation State
  String? _translatedCaption;
  bool _isTranslating = false;
  final TranslationService _translationService = TranslationService();

  @override
  void initState() {
    super.initState();
    _heartAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _heartScaleAnimation = Tween<double>(begin: 0.0, end: 1.2).animate(
      CurvedAnimation(parent: _heartAnimationController, curve: Curves.elasticOut),
    );

    _heartAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            _heartAnimationController.reverse();
          }
        });
      } else if (status == AnimationStatus.dismissed) {
        if (mounted) {
          setState(() {
            _showHeartOverlay = false;
          });
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _prepareMediaList();
  }

  @override
  void didUpdateWidget(PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.post != oldWidget.post) {
      _prepareMediaList();
      _resetVideo();
    }
  }

  void _prepareMediaList() {
    final rawMedia = widget.post['post_media'] as List?;
    if (rawMedia != null && rawMedia.isNotEmpty) {
      _mediaList = List<Map<String, dynamic>>.from(rawMedia);
      // Sort by media_order just in case
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

  void _resetVideo() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    _videoPlayerController = null;
    _chewieController = null;
    _isVideoPlaying = false;
    _currentVideoUrl = null;
  }

  @override
  void dispose() {
    _heartAnimationController.dispose();
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo(String videoUrl) async {
    if (_currentVideoUrl == videoUrl && _videoPlayerController != null) return;

    _resetVideo();

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
            child: Text(
              errorMessage,
              style: const TextStyle(color: Colors.white),
            ),
          );
        },
      );

      if (mounted) {
        setState(() {
          _isVideoPlaying = true;
          _currentVideoUrl = videoUrl;
        });
      }
    } catch (e) {
      debugPrint("Error initializing video: $e");
    }
  }

  void _handleDoubleTap(TapDownDetails details) {
    setState(() {
      _showHeartOverlay = true;
      _tapPosition = details.localPosition;
    });
    
    _heartAnimationController.forward(from: 0.0);
    widget.onLike(widget.index, widget.post['id'].toString());
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final caption = post['caption'] ?? "";
    final bool isLongCaption = caption.length > 100;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
    final subTextColor = Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(
                        context, 
                        AppRoutes.profileRoute, 
                        arguments: post['user_id']
                      );
                    },
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDarkMode ? Colors.orange.withValues(alpha: 0.5) : Colors.orange.shade200, 
                              width: 2
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: isDarkMode ? Colors.orange.withValues(alpha: 0.2) : Colors.orange.shade50,
                            backgroundImage: post['author_avatar'] != null 
                              ? (post['author_avatar'].startsWith('asset:') || post['author_avatar'].startsWith('assets/')
                                  ? AssetImage(post['author_avatar'].startsWith('asset:') 
                                      ? post['author_avatar'].substring(6).trim() 
                                      : post['author_avatar']) as ImageProvider
                                  : CachedNetworkImageProvider(post['author_avatar']))
                              : null,
                            child: post['author_avatar'] == null
                              ? Text(
                                  (post['author_name'] as String)[0].toUpperCase(),
                                  style: TextStyle(
                                    color: isDarkMode ? Colors.orangeAccent : Colors.orange, 
                                    fontWeight: FontWeight.bold, 
                                    fontSize: 14
                                  ),
                                )
                              : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                post['author_name'], 
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor),
                              ),
                              const SizedBox(height: 2),
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    widget.formatTime(post['created_at']), 
                                    style: TextStyle(fontSize: 11, color: subTextColor),
                                  ),
                                  if (post['is_edited'] == true)
                                    Text(
                                      "(diedit)",
                                      style: TextStyle(fontSize: 11, color: subTextColor, fontStyle: FontStyle.italic),
                                    ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isDarkMode ? Colors.orange.withValues(alpha: 0.2) : Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: isDarkMode ? Colors.orange.withValues(alpha: 0.5) : Colors.orange.shade100),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          post['category'] == 'Makanan' ? Icons.restaurant_rounded :
                                          post['category'] == 'Minuman' ? Icons.local_cafe_rounded :
                                          post['category'] == 'Set Menu' ? Icons.restaurant_menu_rounded :
                                          post['category'] == 'Hasil Resep ChefGenius' ? Icons.auto_awesome_rounded :
                                          Icons.grid_view_rounded,
                                          size: 10,
                                          color: isDarkMode ? Colors.orangeAccent : Colors.orange.shade800,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          post['category'] ?? 'Umum',
                                          style: TextStyle(fontSize: 10, color: isDarkMode ? Colors.orangeAccent : Colors.orange.shade800, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (post['recipe_title'] != null)
                                    GestureDetector(
                                      onTap: () {
                                        if (post['recipe_id'] != null) {
                                          final recipeId = int.tryParse(post['recipe_id'].toString()) ?? 0;
                                          if (recipeId != 0) {
                                            widget.onRecookTap(recipeId);
                                          }
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isDarkMode ? Colors.green.withValues(alpha: 0.2) : Colors.green.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: isDarkMode ? Colors.green.withValues(alpha: 0.5) : Colors.green.shade200),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.restaurant_menu, size: 10, color: isDarkMode ? Colors.greenAccent : Colors.green),
                                            const SizedBox(width: 4),
                                            ConstrainedBox(
                                              constraints: BoxConstraints(
                                                // Limit badge text to a fraction of screen width so it can ellipsize
                                                maxWidth: MediaQuery.of(context).size.width * 0.45,
                                              ),
                                              child: Text(
                                                "Memasak ${post['recipe_title']}",
                                                style: TextStyle(fontSize: 10, color: isDarkMode ? Colors.greenAccent : Colors.green.shade800, fontWeight: FontWeight.bold),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Pin indicator for pinned posts
                if (post['is_pinned'] == true)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.push_pin,
                      size: 18,
                      color: Colors.orange,
                    ),
                  ),
                IconButton(
                  icon: Icon(Icons.more_horiz, color: subTextColor),
                  onPressed: () => widget.onOptions(post, widget.index),
                ),
              ],
            ),
          ),

          // MEDIA CAROUSEL
          if (_mediaList.isNotEmpty)
            Column(
              children: [
                GestureDetector(
                  onDoubleTapDown: _handleDoubleTap,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        constraints: const BoxConstraints(maxHeight: 500, minHeight: 250),
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: AspectRatio(
                          aspectRatio: 1, // Default square aspect ratio for carousel
                          child: PageView.builder(
                            itemCount: _mediaList.length,
                            onPageChanged: (index) {
                              setState(() {
                                _currentMediaIndex = index;
                                _resetVideo(); // Stop video when sliding
                              });
                            },
                            itemBuilder: (context, index) {
                              final media = _mediaList[index];
                              final isVideo = media['type'] == 'video';
                              final url = media['url'];
                              final thumbnailUrl = media['thumbnail_url'];

                              if (isVideo && _isVideoPlaying && _currentVideoUrl == url && _chewieController != null) {
                                return Chewie(controller: _chewieController!);
                              }

                              return GestureDetector(
                                onTap: () {
                                  if (isVideo) {
                                    _initializeVideo(url);
                                  } else {
                                    // Open Full Screen Viewer with Hero Animation
                                    Navigator.push(
                                      context,
                                      PageRouteBuilder(
                                        opaque: false,
                                        pageBuilder: (_, __, ___) => FullScreenImageViewer(
                                          imageUrl: url,
                                          heroTag: 'post_media_${post['id']}_$index',
                                        ),
                                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                          return FadeTransition(opacity: animation, child: child);
                                        },
                                      ),
                                    );
                                  }
                                },
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Hero(
                                      tag: isVideo ? 'video_tag_${post['id']}_$index' : 'post_media_${post['id']}_$index',
                                      child: CachedNetworkImage(
                                        imageUrl: thumbnailUrl ?? (isVideo ? '' : url),
                                        fit: BoxFit.cover,
                                        progressIndicatorBuilder: (context, url, downloadProgress) => Center(
                                          child: CircularProgressIndicator(
                                            value: downloadProgress.progress,
                                            color: Colors.orange,
                                          ),
                                        ),
                                        errorWidget: (context, url, error) => Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.broken_image_outlined, size: 40, color: subTextColor),
                                              const SizedBox(height: 8),
                                              Text("Gagal memuat media", style: TextStyle(color: subTextColor, fontSize: 12)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (isVideo)
                                      Container(
                                        color: Colors.black26,
                                        child: const Center(
                                          child: Icon(Icons.play_circle_fill, size: 64, color: Colors.white70),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      if (_showHeartOverlay)
                        Positioned(
                          left: _tapPosition.dx - 40,
                          top: _tapPosition.dy - 40,
                          child: ScaleTransition(
                            scale: _heartScaleAnimation,
                            child: const Icon(
                              Icons.favorite,
                              color: Colors.white,
                              size: 80,
                              shadows: [
                                Shadow(
                                  color: Colors.black26,
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                )
                              ],
                            ),
                          ),
                        ),
                      // Page Indicator (1/5)
                      if (_mediaList.length > 1)
                        Positioned(
                          top: 16,
                          right: 24,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "${_currentMediaIndex + 1}/${_mediaList.length}",
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Dots Indicator
                if (_mediaList.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_mediaList.length, (index) {
                        return Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _currentMediaIndex == index
                                ? Colors.orange
                                : Colors.grey.shade300,
                          ),
                        );
                      }),
                    ),
                  ),
              ],
            ),

          // ACTION BUTTONS
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                _ActionButton(
                  icon: post['is_liked'] ? Icons.favorite : Icons.favorite_border_rounded,
                  color: post['is_liked'] ? Colors.red : textColor,
                  onTap: () => widget.onLike(widget.index, post['id'].toString()),
                  count: post['like_count'],
                ),
                const SizedBox(width: 16),
                _ActionButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  onTap: () => widget.onCommentTap(post['id'].toString()),
                  count: post['comment_count'],
                  color: textColor,
                ),
                const SizedBox(width: 16),
                _ActionButton(
                  icon: Icons.send_rounded,
                  onTap: () => widget.onShare(post, widget.index),
                  count: post['share_count'] ?? 0,
                  color: textColor,
                ),
                const Spacer(),
                _ActionButton(
                  icon: post['is_saved'] ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  color: post['is_saved'] ? Colors.orange : textColor, 
                  onTap: () => widget.onSave(widget.index, post['id'].toString()),
                  count: post['save_count'] ?? 0,
                ),
              ],
            ),
          ),

          // CAPTION
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post['title'] != null && post['title'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      post['title'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: textColor,
                      ),
                    ),
                  ),
                RichText(
                  text: TextSpan(
                    style: DefaultTextStyle.of(context).style.copyWith(fontSize: 14, height: 1.4, color: textColor),
                    children: [
                      TextSpan(
                        text: _isExpanded || !isLongCaption 
                            ? caption 
                            : "${caption.substring(0, 100)}... ",
                        style: TextStyle(color: textColor),
                      ),
                      if (isLongCaption && !_isExpanded)
                        TextSpan(
                          text: "selengkapnya",
                          style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                          recognizer: TapGestureRecognizer()..onTap = () {
                            setState(() {
                              _isExpanded = true;
                            });
                          },
                        ),
                      // FIX: Add option to collapse the caption
                      if (isLongCaption && _isExpanded)
                        TextSpan(
                          text: " sembunyikan",
                          style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                          recognizer: TapGestureRecognizer()..onTap = () {
                            setState(() {
                              _isExpanded = false;
                            });
                          },
                        ),
                    ],
                  ),
                ),
                
                // TRANSLATED CAPTION
                if (_translatedCaption != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.blue.withValues(alpha: 0.1) : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDarkMode ? Colors.blue.withValues(alpha: 0.3) : Colors.blue.shade100,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.translate, size: 16, color: Colors.blue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _translatedCaption!,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.4,
                                color: isDarkMode ? Colors.blue.shade200 : Colors.blue.shade800,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                // TRANSLATE BUTTON
                Builder(
                  builder: (context) {
                    final langProvider = context.watch<LanguageProvider>();
                    final appLang = langProvider.appLocale.languageCode;
                    final needsTranslate = _translationService.needsTranslation(caption, appLang);
                    
                    if (!needsTranslate && _translatedCaption == null) {
                      return const SizedBox.shrink();
                    }
                    
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: GestureDetector(
                        onTap: _isTranslating ? null : () async {
                          if (_translatedCaption != null) {
                            // Toggle off
                            setState(() => _translatedCaption = null);
                          } else {
                            // Translate
                            setState(() => _isTranslating = true);
                            final result = await _translationService.translate(
                              text: caption,
                              targetLanguage: appLang,
                            );
                            if (mounted) {
                              setState(() {
                                _translatedCaption = result;
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
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            else
                              Icon(
                                Icons.translate,
                                size: 14,
                                color: _translatedCaption != null ? Colors.blue : Colors.grey,
                              ),
                            const SizedBox(width: 4),
                            Text(
                              _isTranslating 
                                ? "Menerjemahkan..." 
                                : (_translatedCaption != null ? "Sembunyikan terjemahan" : "Terjemahkan"),
                              style: TextStyle(
                                fontSize: 12,
                                color: _translatedCaption != null ? Colors.blue : Colors.grey,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // COMMENTS LINK & TIME
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post['comment_count'] > 0)
                  GestureDetector(
                    onTap: () => widget.onCommentTap(post['id'].toString()),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        "Lihat semua ${post['comment_count']} komentar",
                        style: TextStyle(color: subTextColor, fontSize: 14),
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Text(
                      widget.formatTime(post['created_at']),
                      style: TextStyle(color: subTextColor, fontSize: 12),
                    ),
                    if (post['is_edited'] == true)
                      Text(
                        " • Telah diedit",
                        style: TextStyle(color: subTextColor, fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final int? count;

  const _ActionButton({
    required this.icon,
    this.color = Colors.black87,
    required this.onTap,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 26, color: color),
          if (count != null) ...[
            const SizedBox(width: 6),
            Text(
              "$count",
              style: TextStyle(
                fontSize: 14, 
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
