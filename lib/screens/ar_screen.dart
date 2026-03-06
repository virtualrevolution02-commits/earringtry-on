import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import '../providers/ar_provider.dart';
import '../services/face_tracker_service.dart';
import '../widgets/face_mesh_painter.dart';
import '../widgets/earring_carousel.dart';
import '../widgets/earring_overlay.dart';
import '../widgets/ar_action_bar.dart';
import '../widgets/status_bar.dart';

/// Main AR screen — orchestrates camera, face tracking, and all widgets.
class ARScreen extends StatefulWidget {
  const ARScreen({super.key});

  @override
  State<ARScreen> createState() => _ARScreenState();
}

class _ARScreenState extends State<ARScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  FaceTrackerService? _faceTracker;
  bool _processingFrame = false;
  final ScreenshotController _screenshotController = ScreenshotController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ARProvider>().loadEarrings();
    });
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      // Select front camera
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        front,
        ResolutionPreset.high, // 1280x720 on most devices
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();

      if (!mounted) return;

      context.read<ARProvider>().setCameraReady();

      // Initialize face tracker
      _faceTracker = createFaceTracker();
      await _faceTracker!.initialize();

      // Start processing frames on native (web uses video element directly)
      if (kIsWeb) {
        _startWebPolling();
      } else {
        _cameraController!.startImageStream(_onCameraFrame);
      }

      setState(() {});
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  /// Process each camera frame through the face tracker.
  void _onCameraFrame(CameraImage image) async {
    if (_processingFrame) return;
    _processingFrame = true;

    try {
      final result = await _faceTracker!.processFrame(image);
      if (mounted) {
        context.read<ARProvider>().updateFaceTrackResult(result);
      }
    } finally {
      _processingFrame = false;
    }
  }

  /// Web alternate logic: continuously poll the face tracker.
  void _startWebPolling() async {
    // Wait a bit longer for the camera video element to be injected into the DOM
    await Future.delayed(const Duration(seconds: 2));
    debugPrint('Starting web face tracking polling...');
    
    while (mounted && _faceTracker != null) {
      final result = await _faceTracker!.processFrame(null);
      if (mounted) {
        context.read<ARProvider>().updateFaceTrackResult(result);
      }
      await Future.delayed(const Duration(milliseconds: 40)); // ~25fps
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      controller.stopImageStream().catchError((_) {});
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.stopImageStream().catchError((_) {});
    _cameraController?.dispose();
    _faceTracker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Screenshot(
        controller: _screenshotController,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Layer 1: Camera feed ──────────────────────────────
            _buildCameraPreview(),

            // ── Layer 2: Face mesh wireframe ──────────────────────
            Consumer<ARProvider>(
              builder: (_, provider, __) {
                if (!provider.showMesh || provider.landmarks.isEmpty) {
                  return const SizedBox.shrink();
                }
                return CustomPaint(
                  painter: FaceMeshPainter(
                    landmarks: provider.landmarks,
                    previewSize: size,
                    imgW: provider.imageWidth,
                    imgH: provider.imageHeight,
                  ),
                  size: size,
                );
              },
            ),

            // ── Layer 3: 3D Earring overlay ───────────────────────
            EarringOverlay(
              screenWidth: size.width,
              screenHeight: size.height,
            ),

            // ── Layer 4: UI overlay ───────────────────────────────
            Column(
              children: [
                // Top status bar
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Brand Watermark
                        Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'VISTARA',
                                style: TextStyle(
                                  color: Color(0xFFC9A84C),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                              ),
                              Text(
                                'TECH AR',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 8,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Expanded(child: StatusBar()),
                        // Mesh toggle button
                        Consumer<ARProvider>(
                          builder: (_, provider, __) => IconButton(
                            icon: Icon(
                              provider.showMesh
                                  ? Icons.grid_on
                                  : Icons.grid_off,
                              color: Colors.white70,
                            ),
                            onPressed: provider.toggleMesh,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // App title
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'AR Earring Try-On',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

                const Spacer(),

                // Bottom panel: carousel + action buttons
                Container(
                  padding: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.9),
                        Colors.black.withOpacity(0.5),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.6, 1.0],
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const EarringCarousel(),
                        const SizedBox(height: 12),
                        ARActionBar(screenshotController: _screenshotController),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildCameraPreview() {
    final controller = _cameraController;

    if (controller == null || !controller.value.isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Color(0xFFC9A84C),
                strokeWidth: 2,
              ),
              SizedBox(height: 16),
              Text(
                'Initializing Camera...',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    // On web, the CameraPreview is an HTML <video> element.
    // We just let it fill the container; the browser handles aspect ratio.
    // On mobile, we use FittedBox to handle the aspect ratio correctly.
    if (kIsWeb) {
      return SizedBox.expand(
        child: CameraPreview(controller),
      );
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: controller.value.previewSize!.height,
          height: controller.value.previewSize!.width,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}
