import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../models/face_geometry.dart';
import '../../services/face_geometry_service.dart';
import '../../services/face_mesh_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/scan/geometry_overlay_painter.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with TickerProviderStateMixin {
  CameraController? _camera;
  FaceDetector?     _faceDetector;
  FaceMeshService?  _meshService;

  // Image orientation snapshot taken at init, reused for every frame's point
  // transform so landmarks rotate/mirror into the same space as the preview.
  InputImageRotation _rotation = InputImageRotation.rotation0deg;
  bool _isFrontCam = false;

  ScanPhase    _phase    = ScanPhase.searching;
  FaceMesh?    _mesh;
  FaceGeometry? _geometry;
  double       _progress = 0.0;
  int          _countdown = 3;
  bool         _busy = false;

  Timer? _measureTimer;
  Timer? _countdownTimer;

  int _faceFrames = 0;
  static const int _requiredFrames = 10;

  bool _processing = false;


  // Rotating copy per phase
  static const _scanCopy = [
    '468 landmarks',
    'Orbital vector resolving',
    'Jaw angle acquired',
    'FWHR locking',
    'Structural archetype match running',
  ];
  int _copyIdx = 0;
  Timer? _copyTimer;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;
    final front = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableContours: true,
        enableLandmarks: true,
        enableClassification: true,
        minFaceSize: 0.25,
      ),
    );

    _rotation = Platform.isIOS
        ? InputImageRotation.rotation0deg
        : (InputImageRotationValue.fromRawValue(front.sensorOrientation)
              ?? InputImageRotation.rotation270deg);
    _isFrontCam = front.lensDirection == CameraLensDirection.front;

    // Google ML Kit Face Mesh Detection is Android-only — trying to use it
    // on iOS throws MissingPluginException and kills the processing loop.
    // On iOS, mesh stays null and we fall back to face_detection contour points.
    if (Platform.isAndroid) {
      _meshService = FaceMeshService();
    }

    _camera = CameraController(
      front,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    try {
      await _camera!.initialize();
      if (!mounted) return;
      setState(() {});
      _camera!.startImageStream(_processFrame);
    } catch (e) {
      debugPrint('Camera init: $e');
    }
  }

  // Input image conversion — identical approach to fitnessos-repo which is
  // running this exact pipeline on thousands of devices without issues.
  InputImage? _buildInputImage(CameraImage image) {
    final camera = _camera;
    if (camera == null) return null;

    final rotation = Platform.isIOS
        ? InputImageRotation.rotation0deg
        : (InputImageRotationValue.fromRawValue(camera.description.sensorOrientation)
              ?? InputImageRotation.rotation270deg);

    final size = Size(image.width.toDouble(), image.height.toDouble());

    if (Platform.isAndroid) {
      return _yuv420ToNv21InputImage(image, size, rotation);
    } else {
      return _bgraInputImage(image, size, rotation);
    }
  }

  InputImage? _yuv420ToNv21InputImage(
      CameraImage image, Size size, InputImageRotation rotation) {
    try {
      final w = image.width;
      final h = image.height;
      final yRow  = image.planes[0].bytesPerRow;
      final uvRow = image.planes[1].bytesPerRow;
      final uvPx  = image.planes[1].bytesPerPixel ?? 1;

      final yLen  = w * h;
      final uvLen = w * h ~/ 2;
      final nv21  = Uint8List(yLen + uvLen);

      final y = image.planes[0].bytes;
      var idx = 0;
      for (var row = 0; row < h; row++) {
        for (var col = 0; col < w; col++) {
          nv21[idx++] = y[row * yRow + col];
        }
      }

      final u = image.planes[1].bytes;
      final v = image.planes[2].bytes;
      idx = yLen;
      for (var row = 0; row < h ~/ 2; row++) {
        for (var col = 0; col < w ~/ 2; col++) {
          final off = row * uvRow + col * uvPx;
          nv21[idx++] = v[off]; // V first for NV21
          nv21[idx++] = u[off];
        }
      }

      return InputImage.fromBytes(
        bytes: nv21,
        metadata: InputImageMetadata(
          size: size,
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: w,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  InputImage _bgraInputImage(
      CameraImage image, Size size, InputImageRotation rotation) {
    return InputImage.fromBytes(
      bytes: image.planes[0].bytes,
      metadata: InputImageMetadata(
        size: size,
        rotation: rotation,
        format: InputImageFormat.bgra8888,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  // ML Kit returns landmark points in the *buffer* coordinate system (the raw,
  // un-rotated camera frame). Our preview is rotated to upright + mirrored for
  // the front cam, so we apply the matching rotation + mirror to every point
  // before painting, otherwise the mesh lands off the face (or off-screen).
  Offset _normalize(double bx, double by, double bufW, double bufH) {
    double rx, ry, rw, rh;
    switch (_rotation) {
      case InputImageRotation.rotation90deg:
        rx = bufH - by; ry = bx;          rw = bufH; rh = bufW; break;
      case InputImageRotation.rotation180deg:
        rx = bufW - bx; ry = bufH - by;   rw = bufW; rh = bufH; break;
      case InputImageRotation.rotation270deg:
        rx = by;        ry = bufW - bx;   rw = bufH; rh = bufW; break;
      case InputImageRotation.rotation0deg:
        rx = bx;        ry = by;          rw = bufW; rh = bufH; break;
    }
    var nx = rx / rw;
    final ny = ry / rh;
    if (_isFrontCam) nx = 1.0 - nx;
    return Offset(nx, ny);
  }

  Future<void> _processFrame(CameraImage image) async {
    if (_processing ||
        _phase == ScanPhase.capturing ||
        _phase == ScanPhase.analysing) { return; }
    _processing = true;

    try {
      final inputImage = _buildInputImage(image);
      if (inputImage == null) return;

      final imgW = image.width.toDouble();
      final imgH = image.height.toDouble();

      // Run face detection always. Run mesh detection only where supported.
      List<Face> faces = [];
      FaceMesh? mesh;
      try {
        faces = await _faceDetector!.processImage(inputImage);
      } catch (_) {}
      if (_meshService != null) {
        try {
          mesh = await _meshService!.detect(
            inputImage,
            (x, y) => _normalize(x, y, imgW, imgH),
          );
        } catch (_) {}
      }

      if (!mounted) return;

      if (faces.isEmpty) {
        _faceFrames = 0;
        if (_phase != ScanPhase.searching) {
          setState(() {
            _phase    = ScanPhase.searching;
            _progress = 0;
            _mesh     = null;
          });
        }
        return;
      }

      final face = faces.first;

      // Fallback: if MediaPipe face-mesh didn't fire (older iPhone, unsupported
      // device), synthesize a point cloud from ML Kit face contours. Fewer
      // points but still renders a visible landmark overlay.
      if (mesh == null || !mesh.isValid) {
        final pts = <Offset>[];
        for (final contour in face.contours.values) {
          if (contour == null) continue;
          for (final p in contour.points) {
            pts.add(_normalize(p.x.toDouble(), p.y.toDouble(), imgW, imgH));
          }
        }
        if (pts.length >= 20) {
          mesh = FaceMesh(pts);
        }
      }

      if (mesh == null || !mesh.isValid) {
        // Still nothing — skip this frame, wait for the next detection.
        return;
      }

      _faceFrames++;
      final geom = FaceGeometryService.computeGeometry(face, imgW, imgH);

      setState(() {
        _mesh     = mesh;
        _geometry = geom;
      });

      if (_phase == ScanPhase.searching && _faceFrames >= 2) {
        _startScanning();
      }

      if (_phase == ScanPhase.scanning) {
        final p = (_faceFrames / _requiredFrames).clamp(0.0, 1.0);
        setState(() => _progress = p);

        if (_faceFrames >= _requiredFrames) {
          _startMeasuring();
        }
      }
    } finally {
      _processing = false;
    }
  }

  void _startScanning() {
    setState(() {
      _phase    = ScanPhase.scanning;
      _progress = 0;
    });
    HapticFeedback.lightImpact();
    _copyTimer?.cancel();
    _copyTimer = Timer.periodic(700.ms, (_) {
      if (!mounted) return;
      setState(() => _copyIdx = (_copyIdx + 1) % _scanCopy.length);
    });
  }

  void _startMeasuring() {
    setState(() {
      _phase    = ScanPhase.measuring;
      _progress = 0.6;
    });
    HapticFeedback.mediumImpact();
    _measureTimer?.cancel();
    _measureTimer = Timer.periodic(30.ms, (t) {
      if (!mounted) { t.cancel(); return; }
      final np = _progress + 0.02;
      setState(() => _progress = np.clamp(0.0, 1.0));
      if (np >= 1.0) {
        t.cancel();
        _startCapture();
      }
    });
  }

  void _startCapture() {
    setState(() {
      _phase     = ScanPhase.capturing;
      _progress  = 1.0;
      _countdown = 3;
    });
    HapticFeedback.mediumImpact();

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted) { t.cancel(); return; }
      if (_countdown > 1) {
        HapticFeedback.lightImpact();
        setState(() => _countdown--);
      } else {
        t.cancel();
        HapticFeedback.heavyImpact();
        await _captureAndShip();
      }
    });
  }

  Future<void> _captureAndShip() async {
    if (_busy) return;
    _busy = true;
    setState(() => _phase = ScanPhase.analysing);

    try {
      await _camera?.stopImageStream();
      final file = await _camera?.takePicture();
      if (file == null) throw Exception('capture failed');
      final bytes = await File(file.path).readAsBytes();

      if (!mounted) return;
      final geometry = _geometry ??
          const FaceGeometry(
            canthalTilt: 0, symmetryScore: 70, facialThirdTop: 33,
            facialThirdMid: 33, facialThirdLow: 34, fwhr: 1.9,
            eyeSpacingRatio: 0.46, jawAngle: 125, chinProjection: 0,
            hasReliableData: false,
          );

      context.go('/report', extra: {
        'imageBytes': bytes,
        'geometry':   geometry,
      });
    } catch (e) {
      debugPrint('Capture/ship error: $e');
      if (mounted) {
        setState(() {
          _phase = ScanPhase.searching;
          _faceFrames = 0;
        });
        _camera?.startImageStream(_processFrame);
        _busy = false;
      }
    }
  }

  String get _phaseTitle {
    switch (_phase) {
      case ScanPhase.searching:  return 'POSITION YOUR FACE';
      case ScanPhase.scanning:   return _scanCopy[_copyIdx];
      case ScanPhase.measuring:  return 'GEOMETRY RESOLVED';
      case ScanPhase.capturing:  return 'HOLD STILL';
      case ScanPhase.analysing:  return 'COMPOSITING';
    }
  }

  String get _phaseSub {
    switch (_phase) {
      case ScanPhase.searching:  return 'Look directly into the lens';
      case ScanPhase.scanning:   return 'Mapping 468 landmarks at 30fps';
      case ScanPhase.measuring:  return 'Structural archetype match running';
      case ScanPhase.capturing:  return 'Capturing reference frame';
      case ScanPhase.analysing:  return 'Rendering maximized version';
    }
  }

  @override
  void dispose() {
    _measureTimer?.cancel();
    _countdownTimer?.cancel();
    _copyTimer?.cancel();
    _camera?.stopImageStream();
    _camera?.dispose();
    _faceDetector?.close();
    _meshService?.close();
    super.dispose();
  }

  // Cover-fill camera: scale the CameraPreview's natural AspectRatio box
  // up until it fully covers the screen (parts of the preview are clipped on
  // the overflow side). The mesh overlay is passed as CameraPreview's `child`
  // so it inhabits the SAME coord space as the preview texture and therefore
  // stays aligned with the face no matter how much we scale.
  Widget _fullscreenCamera(CameraController c) {
    final size = MediaQuery.of(context).size;
    var scale = size.aspectRatio * c.value.aspectRatio;
    if (scale < 1) scale = 1 / scale;

    return ClipRect(
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.center,
        child: Center(
          child: CameraPreview(
            c,
            child: LayoutBuilder(
              builder: (_, __) => CustomPaint(
                painter: GeometryOverlayPainter(
                  mesh:      _mesh,
                  phase:     _phase,
                  progress:  _progress,
                  countdown: _countdown,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = _camera;
    final initialized = preview != null && preview.value.isInitialized;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (initialized)
            _fullscreenCamera(preview)
          else
            const ColoredBox(color: Colors.black),

          // Darken edges for focus
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.85,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),
          ),

          // Phase HUD — bottom, editorial format (indexed label + italic sub)
          Positioned(
            left: 0, right: 0, bottom: 84,
            child: Column(
              children: [
                // Index badge — "01 / 05" surgical counter feel
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.35), width: 0.8),
                  ),
                  child: Text(
                    '${(_phase.index + 1).toString().padLeft(2, '0')} / 05  ·  '
                    '${_phase.name.toUpperCase()}',
                    style: AppTypography.label.copyWith(
                      color: AppColors.gold,
                      fontSize: 9,
                      letterSpacing: 2.4,
                    ),
                  ),
                ).animate(key: ValueKey(_phase))
                  .fadeIn(duration: 260.ms)
                  .slideY(begin: 0.3, end: 0, duration: 260.ms, curve: Curves.easeOut),

                // Main phase title
                Text(_phaseTitle,
                  key: ValueKey('$_phase-$_copyIdx'),
                  textAlign: TextAlign.center,
                  style: AppTypography.labelBold.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    letterSpacing: 3.2,
                  ),
                ).animate(key: ValueKey('$_phase-$_copyIdx'))
                  .fadeIn(duration: 220.ms),

                const SizedBox(height: 8),

                // Italic sub — luxury editorial undertext
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Text(_phaseSub,
                    textAlign: TextAlign.center,
                    style: AppTypography.h1Italic.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      letterSpacing: 0.1,
                      height: 1.4,
                    ),
                  ).animate(key: ValueKey(_phase))
                    .fadeIn(duration: 300.ms),
                ),
              ],
            ),
          ),

          // Progress bar during scanning — gold hairline
          if (_phase == ScanPhase.scanning || _phase == ScanPhase.measuring)
            Positioned(
              left: 40, right: 40, bottom: 56,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: AppColors.surface3.withValues(alpha: 0.5),
                  valueColor: const AlwaysStoppedAnimation(AppColors.gold),
                  minHeight: 1.5,
                ),
              ),
            ),

          // Top bar — editorial masthead
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.sm, Sp.md, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Wordmark — serif, editorial
                      Text('Mirrorly',
                        style: AppTypography.h1.copyWith(
                          fontSize: 22,
                          letterSpacing: -0.6,
                          color: AppColors.textPrimary,
                          height: 1,
                        )),
                      const SizedBox(width: 10),
                      Container(
                        width: 4, height: 4,
                        margin: const EdgeInsets.only(top: 6),
                        decoration: const BoxDecoration(
                          color: AppColors.gold,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const Spacer(),
                      // Settings button — gold-lined, minimal
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => context.push('/settings'),
                          borderRadius: BorderRadius.circular(22),
                          child: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.4),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.gold.withValues(alpha: 0.4),
                                width: 0.8),
                            ),
                            child: const Icon(Icons.tune,
                              size: 16, color: AppColors.gold),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  // Under-byline
                  Text('THE FACE, MEASURED',
                    style: AppTypography.label.copyWith(
                      color: AppColors.textMuted, fontSize: 8, letterSpacing: 2.8)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
