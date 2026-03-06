import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ar_provider.dart';
import '../models/earring_model.dart';

/// Bottom horizontal carousel for selecting earrings.
/// Matches the screenshot layout with round thumbnails and a "Select Earring" label.
class EarringCarousel extends StatelessWidget {
  const EarringCarousel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ARProvider>(
      builder: (context, provider, _) {
        final earrings = provider.earrings;

        return Container(
          height: 150,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Text(
                  'COLLECTION',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    letterSpacing: 2.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: provider.isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFC9A84C),
                          strokeWidth: 2,
                        ),
                      )
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        itemCount: earrings.length,
                        itemBuilder: (context, index) {
                          return _EarringItem(earring: earrings[index]);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EarringItem extends StatelessWidget {
  final EarringModel earring;

  const _EarringItem({required this.earring});

  @override
  Widget build(BuildContext context) {
    return Consumer<ARProvider>(
      builder: (context, provider, _) {
        final isSelected = provider.selectedEarring?.id == earring.id;

        return GestureDetector(
          onTap: () => provider.selectEarring(earring),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: 80,
            margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white.withOpacity(0.08) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? const Color(0xFFC9A84C).withOpacity(0.5) : Colors.transparent,
                width: 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Thumbnail circle
                Stack(
                  alignment: Alignment.center,
                  children: [
                    if (isSelected)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFC9A84C).withOpacity(0.2),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withOpacity(0.3),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFC9A84C)
                              : Colors.white12,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          earring.thumbnail,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.diamond,
                            color: Color(0xFFC9A84C),
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Price label
                Text(
                  '₹${earring.price.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white60,
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
