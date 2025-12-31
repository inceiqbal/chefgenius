import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/data/providers/language_provider.dart';

class ProfileHeader extends StatelessWidget {
  final String? fullName;
  final String? username;
  final String email;
  final String? avatarUrl;
  final String? bio;
  final int postCount;
  final int totalLikes;
  final bool isOwnProfile;
  final VoidCallback onEditProfile;
  final VoidCallback onShowAvatar;

  const ProfileHeader({
    super.key,
    required this.fullName,
    required this.username,
    required this.email,
    required this.avatarUrl,
    this.bio,
    required this.postCount,
    required this.totalLikes,
    this.isOwnProfile = true,
    required this.onEditProfile,
    required this.onShowAvatar,
  });

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onShowAvatar,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.orange, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey.shade200,
                    backgroundImage: avatarUrl != null 
                        ? (avatarUrl!.startsWith('asset:') || avatarUrl!.startsWith('assets/')
                            ? AssetImage(avatarUrl!.startsWith('asset:') 
                                ? avatarUrl!.substring(6).trim() 
                                : avatarUrl!) as ImageProvider
                            : CachedNetworkImageProvider(avatarUrl!))
                        : null,
                    child: avatarUrl == null
                        ? const Icon(Icons.person, size: 40, color: Colors.grey)
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName ?? username ?? email.split('@').first,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Username section
                    if (username != null && username!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '@$username',
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                      ),
                    ] else if (isOwnProfile) ...[
                      const SizedBox(height: 2),
                      GestureDetector(
                        onTap: onEditProfile,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_circle_outline, size: 14, color: Colors.orange.shade400),
                            const SizedBox(width: 4),
                            Text(
                              lang.getText('profile_add_username'),
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.orange.shade400,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_user_rounded, size: 16, color: Colors.orange.shade300),
                          const SizedBox(width: 4),
                          Text(
                            lang.getText('profile_no_username'),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.orange.shade300,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ],
                    // Bio section
                    if (bio != null && bio!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Builder(
                        builder: (context) {
                          final stickerRegex = RegExp(r'^sticker:(.+)\]$');
                          final match = stickerRegex.firstMatch(bio!);
                          if (match != null) {
                            final assetPath = match.group(1);
                            return Image.asset(assetPath!, height: 60, width: 60);
                          }
                          
                          return InkWell(
                            onTap: () async {
                              final urlRegExp = RegExp(r'((https?:www\.)|(https?:\/\/)|(www\.))[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9]{1,6}(\/[-a-zA-Z0-9()@:%_\+.~#?&\/=]*)?');
                              final match = urlRegExp.firstMatch(bio!);
                              if (match != null) {
                                 final url = match.group(0)!;
                                 final uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
                                 if (await canLaunchUrl(uri)) {
                                   await launchUrl(uri);
                                 }
                              }
                            },
                            child: Text(
                              bio!,
                              style: TextStyle(
                                fontSize: 12, 
                                color: Colors.blue,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }
                      ),
                    ] else if (isOwnProfile) ...[
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: onEditProfile,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDarkMode ? Colors.grey[800]?.withOpacity(0.5) : Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.orange.withOpacity(0.3),
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit_note_rounded, size: 16, color: Colors.orange.shade400),
                              const SizedBox(width: 6),
                              Text(
                                lang.getText('profile_add_bio'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.orange.withOpacity(0.08) : Colors.orange.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.2),
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.info_outline_rounded, size: 16, color: Colors.orange.shade300),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                lang.getText('profile_no_bio'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange.shade300,
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (isOwnProfile)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: onEditProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey[100],
                          foregroundColor: isDarkMode ? Colors.white : Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: Text(lang.getText('edit_profile_btn'), style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(postCount.toString(), lang.getText('profile_posts')),
              Container(height: 30, width: 1, color: Colors.grey.withValues(alpha: 0.3)),
              _buildStatItem(totalLikes.toString(), lang.getText('profile_likes')),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}
