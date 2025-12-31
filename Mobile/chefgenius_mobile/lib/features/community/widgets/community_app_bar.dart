import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/data/providers/connectivity_provider.dart';
import '../../../app/data/providers/language_provider.dart';
import '../../../app/data/providers/notification_provider.dart';
import '../../../app/widgets/animated_notification_badge.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../providers/community_provider.dart';

class CommunityAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isSearchingMode;
  final TextEditingController searchController;
  final VoidCallback onSearchClose;
  final VoidCallback onSearchTap;
  final VoidCallback onUploadPressed;
  final DateTime? sanctionEndTime;
  final String remainingTime;

  const CommunityAppBar({
    super.key,
    required this.isSearchingMode,
    required this.searchController,
    required this.onSearchClose,
    required this.onSearchTap,
    required this.onUploadPressed,
    this.sanctionEndTime,
    required this.remainingTime,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final isOffline = context.watch<ConnectivityProvider>().isOffline;
    final lang = context.watch<LanguageProvider>();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return AppBar(
      elevation: 0,
      backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      leading: isSearchingMode 
        ? IconButton(
            icon: Icon(Icons.arrow_back, color: isDarkMode ? Colors.white : Colors.black87),
            onPressed: onSearchClose,
          )
        : null,
      title: isSearchingMode
        ? TextField(
            controller: searchController,
            autofocus: true,
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              hintText: "Cari resep, judul, atau caption...",
              hintStyle: TextStyle(color: isDarkMode ? Colors.white54 : Colors.black38),
              border: InputBorder.none,
            ),
            onSubmitted: (value) {
              context.read<CommunityProvider>().setSearchQuery(value.trim());
            },
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lang.getText('comm_title'), 
                style: TextStyle(
                  fontWeight: FontWeight.w800, 
                  color: isDarkMode ? Colors.white : Colors.black87,
                  fontSize: 22,
                  letterSpacing: -0.5,
                ),
              ),
              if (sanctionEndTime != null)
                Text(
                  "Sanksi: $remainingTime",
                  style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold),
                ),
            ],
          ),
      centerTitle: false,
      actions: [
        if (!isOffline) ...[
          if (isSearchingMode)
            IconButton(
              icon: Icon(Icons.close, color: isDarkMode ? Colors.white : Colors.black87),
              onPressed: () {
                searchController.clear();
                onSearchClose();
              },
            )
          else
            IconButton(
              icon: Icon(Icons.search, color: isDarkMode ? Colors.white : Colors.black87),
              onPressed: onSearchTap,
            ),
          
          if (!isSearchingMode) ...[
            Consumer<NotificationProvider>(
              builder: (context, notifProvider, child) {
                return Stack(
                  children: [
                    IconButton(
                      icon: Icon(Icons.notifications_outlined, color: isDarkMode ? Colors.white : Colors.black87),
                      onPressed: () {
                        // Navigate to notifications screen without marking all as read.
                        // Individual items are marked read when tapped.
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                        );
                      },
                    ),
                    if (notifProvider.unreadCount > 0)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: AnimatedNotificationBadge(count: notifProvider.unreadCount),
                      ),
                  ],
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.add, size: 28, color: Colors.orange),
              onPressed: onUploadPressed,
            ),
            const SizedBox(width: 8),
          ],
        ],
      ],
    );
  }
}
