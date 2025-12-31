import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';

class CeiShowcaseWrapper extends StatelessWidget {
  final GlobalKey showcaseKey;
  final String title;
  final String description;
  final Widget child;
  final ShapeBorder? shapeBorder;

  const CeiShowcaseWrapper({
    super.key,
    required this.showcaseKey,
    required this.title,
    required this.description,
    required this.child,
    this.shapeBorder,
  });

  @override
  Widget build(BuildContext context) {
    return Showcase.withWidget(
      key: showcaseKey,
      targetShapeBorder: shapeBorder ?? const CircleBorder(),
      container: Container(
        height: 230, 
        width: 260,  
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/Chef_Cei/chefceiguide.png', 
              height: 100,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.orange, 
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.3),
            ),
          ],
        ),
      ),
      child: child,
    );
  }
}
