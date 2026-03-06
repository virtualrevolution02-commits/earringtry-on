import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import '../providers/ar_provider.dart';

/// Consolidated ActionBar for the AR Screen.
/// Combines Wishlist, Capture, and Buy actions to prevent overflow.
class ARActionBar extends StatelessWidget {
  final ScreenshotController screenshotController;

  const ARActionBar({super.key, required this.screenshotController});

  @override
  Widget build(BuildContext context) {
    return Consumer<ARProvider>(
      builder: (context, provider, _) {
        final isLiked = provider.selectedEarring != null && 
            provider.isInWishlist(provider.selectedEarring!.id);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // 1. Wishlist Button (Icon only circle)
              _buildRoundButton(
                icon: isLiked ? Icons.favorite : Icons.favorite_border,
                color: isLiked ? Colors.red : Colors.white,
                onTap: () {
                  if (provider.selectedEarring != null) {
                    provider.toggleWishlist(provider.selectedEarring!.id);
                  }
                },
              ),
              
              const Spacer(),

              // 2. Capture / Shutter Button (Large center)
              _buildShutterButton(context, provider),

              const Spacer(),

              // 3. Buy Now Button (Pill shaped)
              _buildPillButton(
                label: 'BUY NOW',
                icon: Icons.shopping_bag_outlined,
                onTap: () => _handleBuyAction(context, provider),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRoundButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.1),
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }

  Widget _buildShutterButton(BuildContext context, ARProvider provider) {
    return GestureDetector(
      onTap: () => _capturePhoto(context, provider),
      child: Container(
        width: 76,
        height: 76,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white60, width: 2),
        ),
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
          child: const Icon(Icons.camera_alt_outlined, color: Colors.black, size: 32),
        ),
      ),
    );
  }

  Widget _buildPillButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFC9A84C),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.black, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _capturePhoto(BuildContext context, ARProvider provider) async {
    provider.setCapturing(true);
    try {
      final image = await screenshotController.capture();
      if (image != null) {
        await ImageGallerySaverPlus.saveImage(image);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Screenshot saved to gallery')),
          );
        }
      }
    } finally {
      provider.setCapturing(false);
    }
  }

  void _handleBuyAction(BuildContext context, ARProvider provider) {
    // Show a small success mock or bottom sheet
    if (provider.selectedEarring == null) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Added ${provider.selectedEarring!.name} to Cart!',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const LinearProgressIndicator(color: Color(0xFFC9A84C)),
          ],
        ),
      ),
    );
  }
}
