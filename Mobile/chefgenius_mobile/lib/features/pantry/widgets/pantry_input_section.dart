import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:provider/provider.dart';
import '../../../../app/data/providers/language_provider.dart';

class PantryInputSection extends StatefulWidget {
  final GlobalKey showcaseKey;
  final TextEditingController controller;
  final TextEditingController quantityController;
  final bool isOffline;
  final bool isAdding;
  final VoidCallback onScan;
  final VoidCallback onAdd;

  const PantryInputSection({
    super.key,
    required this.showcaseKey,
    required this.controller,
    required this.quantityController,
    required this.isOffline,
    required this.isAdding,
    required this.onScan,
    required this.onAdd,
  });

  @override
  State<PantryInputSection> createState() => _PantryInputSectionState();
}

class _PantryInputSectionState extends State<PantryInputSection> {
  String _selectedUnit = 'gram';
  bool _isFocused = false;
  
  final List<String> _units = [
    'gram', 'kg', 'ml', 'liter', 'sdm', 'sdt', 
    'butir', 'buah', 'siung', 'batang', 'ikat', 'lembar', 'gelas'
  ];

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Showcase(
      key: widget.showcaseKey,
      title: lang.getText('pantry_step_1_title'),
      description: lang.getText('pantry_step_1_desc'),
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDarkMode
                ? [const Color(0xFF2A2A3E), const Color(0xFF1E1E2E)]
                : [Colors.white, const Color(0xFFFFFAF5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _isFocused 
                  ? Colors.orange.withOpacity(0.15) 
                  : Colors.black.withOpacity(isDarkMode ? 0.12 : 0.04),
              blurRadius: _isFocused ? 10 : 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: _isFocused 
                ? Colors.orange 
                : (isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200),
            width: _isFocused ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(19),
                  topRight: Radius.circular(19),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add_shopping_cart_rounded, color: Colors.orange, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Tambah Bahan',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  // Camera Button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: widget.isAdding || widget.isOffline ? null : widget.onScan,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.purple.shade400, Colors.purple.shade600],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              'Scan',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Input Fields
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Ingredient Name
                  Focus(
                    onFocusChange: (focused) => setState(() => _isFocused = focused),
                    child: TextField(
                      controller: widget.controller,
                      enabled: !widget.isOffline,
                      style: TextStyle(
                        fontSize: 16,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: widget.isOffline
                            ? lang.getText('pantry_hint_offline')
                            : 'Ketik nama bahan...',
                        hintStyle: TextStyle(
                          color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
                        ),
                        prefixIcon: Icon(
                          Icons.restaurant_menu_rounded,
                          color: Colors.orange.shade400,
                        ),
                        filled: true,
                        fillColor: isDarkMode 
                            ? Colors.black.withOpacity(0.2) 
                            : Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Colors.orange, width: 2),
                        ),
                      ),
                      onSubmitted: (_) => widget.isAdding || widget.isOffline ? null : widget.onAdd(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Quantity Row
                  Row(
                    children: [
                      // Number input
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: widget.quantityController,
                          enabled: !widget.isOffline,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[\d./]')),
                          ],
                          style: TextStyle(
                            fontSize: 16,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Jumlah',
                            hintStyle: TextStyle(
                              color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
                            ),
                            prefixIcon: Icon(
                              Icons.numbers_rounded,
                              color: Colors.blue.shade400,
                            ),
                            filled: true,
                            fillColor: isDarkMode 
                                ? Colors.black.withOpacity(0.2) 
                                : Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Colors.blue, width: 2),
                            ),
                          ),
                          onSubmitted: (_) => widget.isAdding || widget.isOffline ? null : widget.onAdd(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Unit dropdown
                      Expanded(
                        flex: 1,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: isDarkMode 
                                ? Colors.black.withOpacity(0.2) 
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedUnit,
                              isExpanded: true,
                              icon: Icon(
                                Icons.arrow_drop_down_rounded,
                                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                              dropdownColor: isDarkMode ? const Color(0xFF2A2A3E) : Colors.white,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDarkMode ? Colors.white : Colors.black87,
                              ),
                              items: _units.map((unit) {
                                return DropdownMenuItem(
                                  value: unit,
                                  child: Text(unit),
                                );
                              }).toList(),
                              onChanged: widget.isOffline ? null : (value) {
                                if (value != null) {
                                  setState(() => _selectedUnit = value);
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Add Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: widget.isAdding || widget.isOffline ? null : () {
                        if (widget.quantityController.text.isNotEmpty) {
                          final quantityValue = widget.quantityController.text.trim();
                          final combined = '$quantityValue $_selectedUnit';
                          widget.quantityController.text = combined;
                        }
                        widget.onAdd();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: widget.isAdding
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add_rounded, size: 22),
                                const SizedBox(width: 8),
                                Text(
                                  lang.getText('add_btn'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
