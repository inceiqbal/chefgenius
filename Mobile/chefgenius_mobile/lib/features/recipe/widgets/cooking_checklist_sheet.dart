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
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[900]
            : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 5,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Checklist Bahan',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: widget.ingredients.length,
              itemBuilder: (context, index) {
                final ingredient = widget.ingredients[index];
                return CheckboxListTile(
                  value: widget.checkedState[index],
                  onChanged: (bool? value) {
                    // Update state di widget ini
                    setState(() {
                      widget.checkedState[index] = value ?? false;
                    });
                    // Kabarin parent juga
                    widget.onCheckChanged(index, value ?? false);
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: Theme.of(context).primaryColor,
                  title: Text(
                    '${ingredient.quantity} ${ingredient.name}'.trim(),
                    style: TextStyle(
                      decoration: widget.checkedState[index]
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      color: widget.checkedState[index]
                          ? Colors.grey
                          : (Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black),
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