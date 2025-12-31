import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProfilePostsGrid extends StatelessWidget {
  final List<Map<String, dynamic>> posts;
  final bool isLoading;
  final bool isMyPost;
  final Function(Map<String, dynamic>) onPostTap;
  final Function(Map<String, dynamic>)? onLikeTap;
  // onSaveTap removed (save only in detail)

  const ProfilePostsGrid({
    super.key,
    required this.posts,
    required this.isLoading,
    required this.isMyPost,
    required this.onPostTap,
    this.onLikeTap,
  });

  // Get thumbnail/first media for display
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
    // Fallback to legacy fields
    return {
      'url': post['thumbnail_url'] ?? post['image_url'] ?? '',
      'isVideo': post['video_url'] != null,
      'hasMultiple': false,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => Container(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey.shade200),
          childCount: 9,
        ),
      );
    }

    if (posts.isEmpty) {
      return SliverToBoxAdapter(
        child: SizedBox(
          height: 300,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.camera_alt_outlined, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  "No posts yet",
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final post = posts[index];
          final isPinned = post['is_pinned'] == true;
          final displayMedia = _getDisplayMedia(post);

          return GestureDetector(
            onTap: () => onPostTap(post),
            onDoubleTap: () => onLikeTap?.call(post),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: displayMedia['url'] ?? '',
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey.shade200),
                  errorWidget: (context, url, error) => Container(
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey.shade200,
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  ),
                ),
                // Video indicator
                if (displayMedia['isVideo'] == true)
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.play_arrow_rounded, size: 16, color: Colors.white),
                    ),
                  ),
                // Multi-slide indicator
                if (displayMedia['hasMultiple'] == true)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.collections_rounded, size: 14, color: Colors.white),
                    ),
                  ),
                // Pinned indicator (pojok kanan atas)
                if (isPinned && isMyPost)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.push_pin, size: 16, color: Colors.orange),
                    ),
                  ),

                // ... (tombol save dihapus, hanya tampil di detail post)
              ],
            ),
          );
        },
        childCount: posts.length,
      ),
    );
  }
}
