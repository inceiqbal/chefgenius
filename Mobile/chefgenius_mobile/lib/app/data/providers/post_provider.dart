import 'package:flutter/material.dart';

class PostProvider extends ChangeNotifier {
  final List<Map<String, dynamic>> _posts = [];

  List<Map<String, dynamic>> get posts => _posts;

  void setPosts(List<Map<String, dynamic>> newPosts) {
    _posts.clear();
    _posts.addAll(newPosts);
    notifyListeners();
  }

  void updatePost(Map<String, dynamic> updatedPost) {
    final idx = _posts.indexWhere((p) => p['id'] == updatedPost['id']);
    if (idx != -1) {
      _posts[idx] = updatedPost;
      notifyListeners();
    }
  }

  void toggleLike(String postId) {
    final idx = _posts.indexWhere((p) => p['id'] == postId);
    if (idx != -1) {
      final post = _posts[idx];
      final isLiked = post['is_liked'] == true;
      post['is_liked'] = !isLiked;
      post['like_count'] = (post['like_count'] ?? 0) + (isLiked ? -1 : 1);
      notifyListeners();
    }
  }
}
