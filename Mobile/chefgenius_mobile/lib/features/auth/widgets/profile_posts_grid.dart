import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProfilePostsGrid extends StatelessWidget {
  final List<Map<String, dynamic>> posts;
  final bool isLoading;
  final bool isMyPost;
  final Function(Map<String, dynamic>) onPostTap;
  final Function(Map<String, dynamic>)? onLikeTap;

  const ProfilePostsGrid({
    super.key,
    required this.posts,
    required this.isLoading,
    required this.isMyPost,
    required this.onPostTap,
    this.onLikeTap,
  });

  Map<String, dynamic> _getDisplayMedia(Map<String, dynamic> post) {
    final rawMedia = post['post_media'] as List?;
    if (rawMedia != null && rawMedia.isNotEmpty) {
      final mediaList = List<Map<String, dynamic>>.from(rawMedia);
      mediaList.sort((a, b) => (a['media_order'] ?? 0).compareTo(b['media_order'] ?? 0));
      final firstMedia = mediaList.first;
      return {
        'url': firstMedia['type'] == 'video' 
            ? (firstMedia['thumbnail_url'] ?? firstMedia['url']) 
            : firstMedia['url'],
        'isVideo': firstMedia['type'] == 'video',
        'hasMultiple': mediaList.length > 1,
      };
    }
    return {
      'url': post['thumbnail_url'] ?? post['image_url'] ?? '',
      'isVideo': post['video_url'] != null,
      'hasMultiple': false,
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    if (isLoading) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => Container(
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[800] : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            childCount: 9,
          ),
        ),
      );
    }

    if (posts.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          height: 300,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.9, end: 1.0),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(scale: value, child: child);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDarkMode
                            ? [const Color(0xFF2A2520).withOpacity(0.5), const Color(0xFF1E1A18).withOpacity(0.3)]
                            : [Colors.orange.shade50, Colors.orange.shade100.withOpacity(0.5)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.photo_camera_rounded, size: 48, color: Colors.orange),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Belum ada postingan",
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                if (isMyPost)
                  Text(
                    "Bagikan masakan pertamamu! 📸",
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final post = posts[index];
            final isPinned = post['is_pinned'] == true;
            final displayMedia = _getDisplayMedia(post);

            return GestureDetector(
              onTap: () => onPostTap(post),
              onDoubleTap: () => onLikeTap?.call(post),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: displayMedia['url'] ?? '',
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: isDarkMode ? Colors.grey[800] : Colors.grey.shade200,
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: isDarkMode ? Colors.grey[800] : Colors.grey.shade200,
                          child: const Icon(Icons.broken_image, color: Colors.grey),
                        ),
                      ),
                      // Video indicator
                      if (displayMedia['isVideo'] == true)
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.play_arrow_rounded, size: 14, color: Colors.white),
                          ),
                        ),
                      // Multi-slide indicator
                      if (displayMedia['hasMultiple'] == true)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.collections_rounded, size: 12, color: Colors.white),
                          ),
                        ),
                      // Pinned indicator
                      if (isPinned && isMyPost)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFE67E22), Color(0xFFD35400)],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFE67E22).withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.push_pin, size: 12, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
          childCount: posts.length,
        ),
      ),
    );
  }
}
