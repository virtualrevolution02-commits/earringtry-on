import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ar_provider.dart';

/// Displays the current workflow state of the AR experience.
/// Shows a glassmorphism status card that transitions through states.
class StatusBar extends StatelessWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ARProvider>(
      builder: (context, provider, _) {
        final label = _getLabel(provider.workflowState);
        final icon = _getIcon(provider.workflowState);
        final color = _getColor(provider.workflowState);

        return Container(
          margin: const EdgeInsets.only(top: 16, left: 8, right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.black.withOpacity(0.4),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pulsing status dot
                _PulsingDot(color: color),
                const SizedBox(width: 8),
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getLabel(ARWorkflowState state) {
    switch (state) {
      case ARWorkflowState.initializing:
        return 'Initializing Camera...';
      case ARWorkflowState.cameraReady:
        return 'Live Camera Preview';
      case ARWorkflowState.faceDetected:
        return 'Face Detected';
      case ARWorkflowState.earDetected:
        return 'Ear Position Detected!';
      case ARWorkflowState.earringSelected:
        return 'Preview Earrings in AR';
    }
  }

  IconData _getIcon(ARWorkflowState state) {
    switch (state) {
      case ARWorkflowState.initializing:
        return Icons.camera_alt_outlined;
      case ARWorkflowState.cameraReady:
        return Icons.videocam_outlined;
      case ARWorkflowState.faceDetected:
        return Icons.face_outlined;
      case ARWorkflowState.earDetected:
        return Icons.hearing_outlined;
      case ARWorkflowState.earringSelected:
        return Icons.auto_awesome;
    }
  }

  Color _getColor(ARWorkflowState state) {
    switch (state) {
      case ARWorkflowState.initializing:
        return const Color(0xFF888888);
      case ARWorkflowState.cameraReady:
        return const Color(0xFF4A90D9);
      case ARWorkflowState.faceDetected:
        return const Color(0xFF2ECC71);
      case ARWorkflowState.earDetected:
        return const Color(0xFF2ECC71);
      case ARWorkflowState.earringSelected:
        return const Color(0xFFC9A84C);
    }
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _animation = Tween(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) => Opacity(
        opacity: _animation.value,
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
          ),
        ),
      ),
    );
  }
}
