import 'package:flutter/material.dart';
import '../../../app/data/models/ingredient_model.dart';

class CookingChecklistSheet extends StatefulWidget {
  final List<Ingredient> ingredients;
  // Kita pass status checklist dari parent biar persist
  final List<bool> checkedState; 
  final Function(int index, bool value) onCheckChanged;

  const CookingChecklistSheet({
    super.key,
    required this.ingredients,
    required this.checkedState,
    required this.onCheckChanged,
  });

  @override
  State<CookingChecklistSheet> createState() => _CookingChecklistSheetState();
}

class _CookingChecklistSheetState extends State<CookingChecklistSheet> {
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF27AE60), Color(0xFF2ECC71)]),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF27AE60).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: const Icon(Icons.checklist_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Checklist Bahan',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        '${widget.checkedState.where((c) => c).length}/${widget.ingredients.length} siap',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Progress indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: widget.ingredients.isEmpty 
                    ? 0 
                    : widget.checkedState.where((c) => c).length / widget.ingredients.length,
                backgroundColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF27AE60)),
                minHeight: 6,
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: widget.ingredients.length,
              itemBuilder: (context, index) {
                final ingredient = widget.ingredients[index];
                final isChecked = widget.checkedState[index];
                
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: isChecked 
                        ? (isDarkMode ? const Color(0xFF27AE60).withOpacity(0.15) : Colors.green.shade50)
                        : (isDarkMode ? Colors.white.withOpacity(0.03) : Colors.grey.shade50),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isChecked 
                          ? const Color(0xFF27AE60).withOpacity(0.5)
                          : (isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200),
                    ),
                  ),
                  child: CheckboxListTile(
                    value: isChecked,
                    onChanged: (bool? value) {
                      setState(() {
                        widget.checkedState[index] = value ?? false;
                      });
                      widget.onCheckChanged(index, value ?? false);
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: const Color(0xFF27AE60),
                    checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    title: Text(
                      '${ingredient.quantity} ${ingredient.name}'.trim(),
                      style: TextStyle(
                        decoration: isChecked ? TextDecoration.lineThrough : TextDecoration.none,
                        color: isChecked 
                            ? Colors.grey.shade500
                            : (isDarkMode ? Colors.white : Colors.black87),
                        fontWeight: isChecked ? FontWeight.normal : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}