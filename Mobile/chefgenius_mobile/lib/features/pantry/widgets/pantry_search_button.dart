import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/data/providers/language_provider.dart';

class PantrySearchButton extends StatefulWidget {
  final bool isSearching;
  final bool isOffline;
  final bool isLoading;
  final VoidCallback onSearch;

  const PantrySearchButton({
    super.key,
    required this.isSearching,
    required this.isOffline,
    required this.isLoading,
    required this.onSearch,
  });

  @override
  State<PantrySearchButton> createState() => _PantrySearchButtonState();
}

class _PantrySearchButtonState extends State<PantrySearchButton> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isDisabled = widget.isLoading || widget.isSearching || widget.isOffline;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: isDisabled ? 1.0 : _pulseAnimation.value,
            child: child,
          );
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: widget.isOffline || widget.isSearching
                ? []
                : [
                    BoxShadow(
                      color: const Color(0xFFE67E22).withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: isDisabled ? null : widget.onSearch,
              child: Ink(
                decoration: BoxDecoration(
                  gradient: widget.isOffline
                      ? LinearGradient(
                          colors: isDarkMode
                              ? [const Color(0xFF374151), const Color(0xFF1F2937)]
                              : [Colors.grey.shade400, Colors.grey.shade500],
                        )
                      : const LinearGradient(
                          // Softer warm orange gradient
                          colors: [Color(0xFFE67E22), Color(0xFFD35400)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.isSearching) ...[
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            widget.isOffline ? Icons.wifi_off_rounded : Icons.search_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ],
                      const SizedBox(width: 14),
                      Text(
                        widget.isSearching
                            ? lang.getText('search_recipe_loading')
                            : widget.isOffline
                                ? lang.getText('offline_mode')
                                : lang.getText('search_recipe_btn'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (!widget.isSearching && !widget.isOffline) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
