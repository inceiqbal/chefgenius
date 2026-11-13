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

    return Column(
      children: [
        // Hero Section with Gradient Background
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDarkMode
                  ? [const Color(0xFF2A2520), const Color(0xFF1E1A18), const Color(0xFF121212)]
                  : [const Color(0xFFFFF8F0), const Color(0xFFFFE5D9), const Color(0xFFFFFFFF)],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                const SizedBox(height: 20),
                
                // Avatar with Gradient Border
                GestureDetector(
                  onTap: onShowAvatar,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE67E22), Color(0xFFD35400), Color(0xFFE74C3C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE67E22).withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDarkMode ? const Color(0xFF121212) : Colors.white,
                      ),
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey.shade200,
                        backgroundImage: avatarUrl != null 
                            ? (avatarUrl!.startsWith('asset:') || avatarUrl!.startsWith('assets/')
                                ? AssetImage(avatarUrl!.startsWith('asset:') 
                                    ? avatarUrl!.substring(6).trim() 
                                    : avatarUrl!) as ImageProvider
                                : CachedNetworkImageProvider(avatarUrl!))
                            : null,
                        child: avatarUrl == null
                            ? Icon(Icons.person_rounded, size: 50, color: Colors.grey.shade400)
                            : null,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Name
                Text(
                  fullName ?? username ?? email.split('@').first,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: isDarkMode ? Colors.white : Colors.black87,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                
                // Username
                if (username != null && username!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '@$username',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.orange.shade300 : Colors.orange.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ] else if (isOwnProfile) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: onEditProfile,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded, size: 14, color: Colors.orange.shade400),
                          const SizedBox(width: 4),
                          Text(
                            lang.getText('profile_add_username'),
                            style: TextStyle(fontSize: 13, color: Colors.orange.shade400),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                
                const SizedBox(height: 16),
                
                // Bio Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: _buildBioSection(context, lang, isDarkMode),
                ),
                
                const SizedBox(height: 20),
                
                // Edit Profile Button
                if (isOwnProfile)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: GestureDetector(
                      onTap: onEditProfile,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE67E22), Color(0xFFD35400)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE67E22).withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.edit_rounded, size: 18, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              lang.getText('edit_profile_btn'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        
        // Stats Section
        Transform.translate(
          offset: const Offset(0, -20),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildModernStatItem(
                  value: postCount.toString(),
                  label: lang.getText('profile_posts'),
                  icon: Icons.grid_view_rounded,
                  isDarkMode: isDarkMode,
                ),
                Container(
                  height: 40,
                  width: 1,
                  color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                ),
                _buildModernStatItem(
                  value: totalLikes.toString(),
                  label: lang.getText('profile_likes'),
                  icon: Icons.favorite_rounded,
                  isDarkMode: isDarkMode,
                  iconColor: Colors.red,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBioSection(BuildContext context, LanguageProvider lang, bool isDarkMode) {
    if (bio != null && bio!.isNotEmpty) {
      final stickerRegex = RegExp(r'^\[sticker:(.+)\]$');
      final match = stickerRegex.firstMatch(bio!);
      if (match != null) {
        final assetPath = match.group(1);
        return Image.asset(assetPath!, height: 60, width: 60);
      }
      
      return InkWell(
        onTap: () async {
          final urlRegExp = RegExp(r'((https?:www\.)|(https?:\/\/)|(www\.))[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9]{1,6}(\/[-a-zA-Z0-9()@:%_\+.~#?&\/=]*)?');
          final urlMatch = urlRegExp.firstMatch(bio!);
          if (urlMatch != null) {
            final url = urlMatch.group(0)!;
            final uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri);
            }
          }
        },
        child: Text(
          bio!,
          style: TextStyle(
            fontSize: 14,
            color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade600,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      );
    } else if (isOwnProfile) {
      return GestureDetector(
        onTap: onEditProfile,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey[850]?.withOpacity(0.5) : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.orange.withOpacity(0.2),
              style: BorderStyle.solid,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.edit_note_rounded, size: 18, color: Colors.orange.shade400),
              const SizedBox(width: 8),
              Text(
                lang.getText('profile_add_bio'),
                style: TextStyle(
                  fontSize: 13,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline_rounded, size: 16, color: Colors.orange.shade300),
            const SizedBox(width: 8),
            Text(
              lang.getText('profile_no_bio'),
              style: TextStyle(
                fontSize: 13,
                color: Colors.orange.shade300,
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildModernStatItem({
    required String value,
    required String label,
    required IconData icon,
    required bool isDarkMode,
    Color? iconColor,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: iconColor ?? Colors.orange),
            const SizedBox(width: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
