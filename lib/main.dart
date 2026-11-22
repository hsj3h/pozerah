
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gal/gal.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PozerahApp());
}

class PozerahApp extends StatelessWidget {
  const PozerahApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pozerah',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF101114),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFB8F36B),
          surface: Color(0xFF202126),
        ),
      ),
      home: const CameraWorkspace(),
    );
  }
}

class CameraWorkspace extends StatefulWidget {
  const CameraWorkspace({super.key});

  @override
  State<CameraWorkspace> createState() => _CameraWorkspaceState();
}

class _CameraWorkspaceState extends State<CameraWorkspace> {
  CameraController? _camera;
  final ImagePicker _picker = ImagePicker();

  File? _referenceImage;

  double _opacity = 0.5;
  double _scale = 1;
  double _rotation = 0;
  double _startScale = 1;
  double _startRotation = 0;

  Offset _offset = Offset.zero;
  Offset _startOffset = Offset.zero;

  bool _locked = false;
  bool _showGrid = false;
  bool _flipped = false;
  bool _cameraReady = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) return;

      final selectedCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        selectedCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _camera = controller;
        _cameraReady = true;
      });
    } catch (e) {
      debugPrint('Camera initialization: $e');
    }
  }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 95,
    );

    if (image == null || !mounted) return;

    setState(() {
      _referenceImage = File(image.path);
      _opacity = 0.5;
      _scale = 1;
      _rotation = 0;
      _offset = Offset.zero;
      _flipped = false;
    });
  }

  
Future<void> _capture() async {
  if (_camera == null || !_cameraReady) {
    _message('Camera is unavailable. Test capture on your iPhone.');
    return;
  }

  try {
    final picture = await _camera!.takePicture();

    await Gal.putImage(picture.path);

    if (!mounted) return;

    _message('Photo saved to your Photos library!');
  } catch (e) {
    if (!mounted) return;
    _message('Could not save photo: $e');
  }
}


  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _camera?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildCameraWorkspace()),
            _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Row(
        children: [
          const Text(
            'POZERAH',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
          ),
          const Spacer(),
          _headerButton(
            icon: Icons.grid_on_rounded,
            selected: _showGrid,
            onTap: () => setState(() => _showGrid = !_showGrid),
          ),
          const SizedBox(width: 10),
          _headerButton(
            icon: _locked ? Icons.lock : Icons.lock_open,
            selected: _locked,
            onTap: () => setState(() => _locked = !_locked),
          ),
        ],
      ),
    );
  }

  Widget _headerButton({
    required IconData icon,
    required VoidCallback onTap,
    bool selected = false,
  }) {
    return IconButton(
      onPressed: onTap,
      style: IconButton.styleFrom(
        backgroundColor: selected
            ? const Color(0xFFB8F36B)
            : const Color(0xFF25262B),
        foregroundColor: selected ? Colors.black : Colors.white,
      ),
      icon: Icon(icon, size: 20),
    );
  }

  Widget _buildCameraWorkspace() {
    return ClipRect(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: _buildCameraPreview()),

          if (_showGrid) _buildGrid(),

          if (_referenceImage != null)
            Positioned.fill(
              child: GestureDetector(
                onScaleStart: _locked
                    ? null
                    : (details) {
                        _startScale = _scale;
                        _startRotation = _rotation;
                        _startOffset = _offset;
                      },
                onScaleUpdate: _locked
                    ? null
                    : (details) {
                        setState(() {
                          _scale = (_startScale * details.scale)
                              .clamp(0.3, 4.0);
                          _rotation =
                              _startRotation + details.rotation;
                          _offset = _startOffset +
                              details.focalPointDelta;
                        });
                      },
                child: Center(
                  child: Transform.translate(
                    offset: _offset,
                    child: Transform.rotate(
                      angle: _rotation,
                      child: Transform.scale(
                        scale: _scale,
                        child: Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.rotationY(
                            _flipped ? math.pi : 0,
                          ),
                          child: Opacity(
                            opacity: _opacity,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: 320,
                                maxHeight: 460,
                              ),
                              child: Image.file(
                                _referenceImage!,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          if (_referenceImage == null)
            _emptyWorkspace(),

          Positioned(
            left: 16,
            bottom: 16,
            child: _statusLabel(
              _cameraReady ? 'CAMERA READY' : 'PREVIEW MODE',
              _cameraReady
                  ? const Color(0xFFB8F36B)
                  : Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_cameraReady && _camera != null) {
      return CameraPreview(_camera!);
    }

    return Container(
      color: const Color(0xFF191A1F),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.camera_alt_outlined,
              size: 54,
              color: Colors.white30,
            ),
            const SizedBox(height: 12),
            const Text(
              'Camera preview',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 5),
            Text(
              'Import a reference photo to get started',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyWorkspace() {
    return Center(
      child: GestureDetector(
        onTap: _pickImage,
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF25262B),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_photo_alternate_outlined,
                size: 36,
                color: Color(0xFFB8F36B),
              ),
              SizedBox(height: 12),
              Text(
                'Add reference photo',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 5),
              Text(
                'Choose an image from your gallery',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrid() {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: GridPainter(),
      ),
    );
  }

  Widget _statusLabel(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: const BoxDecoration(
        color: Color(0xFF191A1F),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.opacity, color: Colors.white70),
              const SizedBox(width: 12),
              const Text(
                'Opacity',
                style: TextStyle(color: Colors.white70),
              ),
              Expanded(
                child: Slider(
                  value: _opacity,
                  min: 0.05,
                  max: 1,
                  onChanged: _referenceImage == null
                      ? null
                      : (value) =>
                          setState(() => _opacity = value),
                ),
              ),
              SizedBox(
                width: 38,
                child: Text(
                  '${(_opacity * 100).round()}%',
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    color: Color(0xFFB8F36B),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _toolButton(
                Icons.photo_library_outlined,
                'Gallery',
                _pickImage,
              ),
              _toolButton(
                Icons.flip,
                'Flip',
                _referenceImage == null
                    ? null
                    : () => setState(
                          () => _flipped = !_flipped,
                        ),
              ),
              _captureButton(),
              _toolButton(
                Icons.rotate_right,
                'Rotate',
                _referenceImage == null
                    ? null
                    : () => setState(
                          () => _rotation += math.pi / 2,
                        ),
              ),
              _toolButton(
                Icons.refresh,
                'Reset',
                _referenceImage == null
                    ? null
                    : () => setState(() {
                          _scale = 1;
                          _rotation = 0;
                          _offset = Offset.zero;
                          _flipped = false;
                          _opacity = 0.5;
                        }),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'DRAG TO MOVE  •  PINCH TO ZOOM  •  TWIST TO ROTATE',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white38,
              fontSize: 9,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolButton(
    IconData icon,
    String label,
    VoidCallback? onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.35 : 1,
        child: Column(
          children: [
            Icon(icon, color: Colors.white70, size: 23),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _captureButton() {
    return GestureDetector(
      onTap: _capture,
      child: Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFFB8F36B),
            width: 3,
          ),
        ),
        child: Container(
          margin: const EdgeInsets.all(5),
          decoration: const BoxDecoration(
            color: Color(0xFFB8F36B),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.camera_alt,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 0.7;

    for (int i = 1; i < 3; i++) {
      final x = size.width * i / 3;
      final y = size.height * i / 3;

      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );

      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) => false;
}
