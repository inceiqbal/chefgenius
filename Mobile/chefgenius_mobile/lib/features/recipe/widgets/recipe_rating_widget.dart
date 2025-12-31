import 'package:flutter/material.dart';

class RecipeRatingWidget extends StatelessWidget {
  final double averageRating;
  final int ratingCount;
  final int? userRating;
  final bool isLoading;
  final Function(int) onRatingSubmit;
  final VoidCallback? onRatingCancel;
  final VoidCallback? onTap;

  const RecipeRatingWidget({
    super.key,
    required this.averageRating,
    required this.ratingCount,
    required this.userRating,
    required this.isLoading,
    required this.onRatingSubmit,
    this.onRatingCancel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () => _showRatingBottomSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.amber.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              userRating != null ? Icons.star : Icons.star_border,
              color: Colors.orange,
              size: 20,
            ),
            const SizedBox(width: 4),
            isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.orange,
                    ),
                  )
                : Text(
                    averageRating > 0
                        ? averageRating.toStringAsFixed(1)
                        : '-',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
            if (ratingCount > 0) ...[
              const SizedBox(width: 4),
              Text(
                '($ratingCount)',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showRatingBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => RatingBottomSheet(
        averageRating: averageRating,
        ratingCount: ratingCount,
        userRating: userRating,
        onRatingSubmit: onRatingSubmit,
        onRatingCancel: onRatingCancel,
      ),
    );
  }
}

class RatingBottomSheet extends StatefulWidget {
  final double averageRating;
  final int ratingCount;
  final int? userRating;
  final Function(int) onRatingSubmit;
  final VoidCallback? onRatingCancel;

  const RatingBottomSheet({
    super.key,
    required this.averageRating,
    required this.ratingCount,
    required this.userRating,
    required this.onRatingSubmit,
    this.onRatingCancel,
  });

  @override
  State<RatingBottomSheet> createState() => _RatingBottomSheetState();
}

class _RatingBottomSheetState extends State<RatingBottomSheet> {
  late int _selectedRating;
  bool _isSubmitting = false;
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    _selectedRating = widget.userRating ?? 0;
  }

  String _getRatingLabel(int rating) {
    switch (rating) {
      case 1:
        return 'Sangat Buruk 😞';
      case 2:
        return 'Buruk 😕';
      case 3:
        return 'Cukup 😐';
      case 4:
        return 'Enak 😊';
      case 5:
        return 'Sangat Enak! 🤤';
      default:
        return 'Ketuk bintang untuk menilai';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            'Beri Penilaian',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),

          // Average rating display
          if (widget.averageRating > 0)
            Text(
              'Rating rata-rata: ${widget.averageRating.toStringAsFixed(1)} (${widget.ratingCount} ulasan)',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          const SizedBox(height: 24),

          // Stars
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starIndex = index + 1;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedRating = starIndex;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    starIndex <= _selectedRating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 48,
                    color: starIndex <= _selectedRating
                        ? Colors.amber
                        : (isDark ? Colors.grey[600] : Colors.grey[400]),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),

          // Rating label
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              _getRatingLabel(_selectedRating),
              key: ValueKey(_selectedRating),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: _selectedRating > 0
                    ? Colors.orange
                    : (isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Submit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedRating > 0 && !_isSubmitting
                  ? () async {
                      setState(() => _isSubmitting = true);
                      await widget.onRatingSubmit(_selectedRating);
                      if (mounted) Navigator.pop(context);
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[400],
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      widget.userRating != null ? 'Ubah Penilaian' : 'Kirim Penilaian',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),

          // Cancel rating button (only show if user has rated)
          if (widget.userRating != null && widget.onRatingCancel != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: !_isCancelling
                    ? () async {
                        setState(() => _isCancelling = true);
                        widget.onRatingCancel!();
                        if (mounted) Navigator.pop(context);
                      }
                    : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isCancelling
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.red,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.delete_outline, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Batalkan Penilaian',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Penilaian Anda saat ini: ${widget.userRating} ⭐',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
