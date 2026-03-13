import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../app/di/providers.dart';
import '../../../../config/constants/app_constants.dart';
import '../../../../config/router/route_names.dart';
import '../../../../config/theme/spacing.dart';
import '../../../../domain/models/transaction_model.dart';
import '../providers/scanner_provider.dart';
import '../widgets/viewfinder_overlay.dart';

/// Receipt scanner screen with camera preview, viewfinder overlay,
/// capture/gallery buttons, and OCR result bottom sheet.
class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isFlashOn = false;
  bool _hasPermission = false;
  String? _permissionError;
  bool _isCapturing = false;

  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _requestCameraPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
      _cameraController = null;
      if (mounted) setState(() => _isCameraInitialized = false);
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  // ── Permission & Camera Setup ──

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (!mounted) return;

    if (status.isGranted) {
      setState(() {
        _hasPermission = true;
        _permissionError = null;
      });
      await _initializeCamera();
    } else if (status.isPermanentlyDenied) {
      setState(() {
        _hasPermission = false;
        _permissionError =
            'Camera permission is permanently denied. Please enable it in Settings.';
      });
    } else {
      setState(() {
        _hasPermission = false;
        _permissionError = 'Camera permission is required to scan receipts.';
      });
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _permissionError = 'No cameras available on this device.';
          });
        }
        return;
      }

      final backCamera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();
      await _cameraController!.setFlashMode(FlashMode.off);

      if (mounted) {
        setState(() => _isCameraInitialized = true);
      }
    } on CameraException catch (e) {
      if (mounted) {
        setState(() {
          _permissionError =
              'Camera error: ${e.description ?? 'Unknown error'}';
        });
      }
    }
  }

  // ── Actions ──

  Future<void> _toggleFlash() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      final newMode = _isFlashOn ? FlashMode.off : FlashMode.torch;
      await _cameraController!.setFlashMode(newMode);
      if (mounted) setState(() => _isFlashOn = !_isFlashOn);
    } on CameraException {
      // Flash not available on this device
    }
  }

  Future<void> _captureImage() async {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isCapturing) {
      return;
    }

    setState(() => _isCapturing = true);

    try {
      // Turn off flash for the capture itself (use auto)
      if (_isFlashOn) {
        await _cameraController!.setFlashMode(FlashMode.auto);
      }

      final xFile = await _cameraController!.takePicture();

      // Validate file size
      final fileSize = await File(xFile.path).length();
      if (fileSize > AppConstants.maxReceiptImageSizeKb * 1024) {
        if (mounted) {
          _showSnackBar(
            'Image is too large. Please try again with a closer shot.',
          );
        }
        return;
      }

      await _processImage(xFile.path);
    } on CameraException catch (e) {
      if (mounted) {
        _showSnackBar('Capture failed: ${e.description ?? 'Unknown error'}');
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
      // Restore flash state
      if (_isFlashOn && _cameraController != null) {
        await _cameraController!.setFlashMode(FlashMode.torch);
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final xFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );

      if (xFile == null) return;
      await _processImage(xFile.path);
    } on PlatformException catch (e) {
      if (mounted) {
        _showSnackBar('Gallery error: ${e.message ?? 'Could not pick image'}');
      }
    }
  }

  Future<void> _processImage(String imagePath) async {
    final notifier = ref.read(scannerStateProvider.notifier);
    await notifier.processImage(imagePath);

    if (!mounted) return;

    final state = ref.read(scannerStateProvider);
    if (state.receiptData != null) {
      _showResultsBottomSheet();
    } else if (state.error != null) {
      _showSnackBar(state.error!);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: AppConstants.snackBarDuration,
      ),
    );
  }

  // ── Results Bottom Sheet ──

  void _showResultsBottomSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Consumer(
          builder: (context, ref, _) {
            final state = ref.watch(scannerStateProvider);
            final data = state.receiptData;
            if (data == null) return const SizedBox.shrink();

            return _ReceiptResultSheet(
              receiptData: data,
              onSave: () => _saveAsTransaction(data),
              onFieldChanged: (updated) {
                ref
                    .read(scannerStateProvider.notifier)
                    .updateReceiptData(updated);
              },
            );
          },
        );
      },
    );
  }

  Future<void> _saveAsTransaction(ReceiptData data) async {
    // Save receipt image
    String? savedImagePath;
    final imagePath = ref.read(scannerStateProvider).imagePath;
    if (imagePath != null) {
      savedImagePath = await ref
          .read(scannerStateProvider.notifier)
          .saveReceiptImage(imagePath);
    }

    if (!mounted) return;

    // Pop the bottom sheet
    Navigator.of(context).pop();

    // Create a pre-filled transaction model and navigate to add screen
    final transaction = TransactionModel(
      amount: data.totalAmount ?? 0.0,
      type: 1, // expense
      note: data.merchantName ?? '',
      date: data.date ?? DateTime.now(),
      receiptImagePath: savedImagePath,
      createdAt: DateTime.now(),
    );

    context.pushNamed(RouteNames.addTransaction, extra: transaction);
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final scannerState = ref.watch(scannerStateProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.scrim,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview or error state
          _buildCameraLayer(theme),

          // Viewfinder overlay (only when camera is active)
          if (_isCameraInitialized) const ViewfinderOverlay(),

          // Top controls bar
          _buildTopBar(theme),

          // Bottom capture controls
          _buildBottomControls(theme),

          // Loading overlay during OCR processing
          if (scannerState.isProcessing) _buildLoadingOverlay(theme),
        ],
      ),
    );
  }

  Widget _buildCameraLayer(ThemeData theme) {
    if (!_hasPermission || _permissionError != null) {
      return _buildErrorState(theme);
    }

    if (!_isCameraInitialized || _cameraController == null) {
      return Center(
        child: CircularProgressIndicator(color: theme.colorScheme.onSurface),
      );
    }

    return Center(child: CameraPreview(_cameraController!));
  }

  Widget _buildErrorState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: Spacing.paddingLg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(
              FontAwesomeIcons.cameraRotate,
              size: 56,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
            ),
            const SizedBox(height: Spacing.md),
            Text(
              _permissionError ?? 'Camera unavailable',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: Spacing.lg),
            if (_permissionError?.contains('permanently') == true)
              FilledButton.icon(
                onPressed: openAppSettings,
                icon: const FaIcon(FontAwesomeIcons.gear, size: 16),
                label: const Text('Open Settings'),
              )
            else
              FilledButton.icon(
                onPressed: _requestCameraPermission,
                icon: const FaIcon(FontAwesomeIcons.camera, size: 16),
                label: const Text('Grant Permission'),
              ),
            const SizedBox(height: Spacing.md),
            TextButton.icon(
              onPressed: _pickFromGallery,
              icon: FaIcon(
                FontAwesomeIcons.images,
                size: 16,
                color: theme.colorScheme.onSurface,
              ),
              label: Text(
                'Pick from Gallery',
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(ThemeData theme) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md,
            vertical: Spacing.sm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Flash toggle
              _CircleIconButton(
                icon: _isFlashOn
                    ? FontAwesomeIcons.solidLightbulb
                    : FontAwesomeIcons.lightbulb,
                onPressed: _isCameraInitialized ? _toggleFlash : null,
                isActive: _isFlashOn,
              ).animate().fadeIn(duration: 300.ms).slideX(begin: -0.3),

              // Gallery pick
              _CircleIconButton(
                icon: FontAwesomeIcons.images,
                onPressed: _pickFromGallery,
              ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls(ThemeData theme) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: Spacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Capture button
              GestureDetector(
                    onTap: _isCameraInitialized && !_isCapturing
                        ? _captureImage
                        : null,
                    child: _CaptureButton(isCapturing: _isCapturing),
                  )
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .scale(begin: const Offset(0.8, 0.8)),

              const SizedBox(height: Spacing.md),

              // Close button
              TextButton(
                onPressed: () => context.pop(),
                child: Text(
                  'Cancel',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay(ThemeData theme) {
    return Container(
      color: theme.colorScheme.scrim.withValues(alpha: 0.72),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: theme.colorScheme.primary,
              strokeWidth: 3,
            ),
            const SizedBox(height: Spacing.lg),
            Text(
              'Processing receipt...',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              'Extracting text with OCR',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ).animate().fadeIn(duration: 300.ms),
      ),
    );
  }
}

// ── Capture Button ──

class _CaptureButton extends StatelessWidget {
  final bool isCapturing;

  const _CaptureButton({required this.isCapturing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.88),
          width: 4,
        ),
      ),
      padding: const EdgeInsets.all(4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isCapturing
              ? colorScheme.primary.withValues(alpha: 0.5)
              : colorScheme.primary,
        ),
        child: Center(
          child: isCapturing
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: colorScheme.onPrimary,
                    strokeWidth: 2,
                  ),
                )
              : FaIcon(
                  FontAwesomeIcons.camera,
                  color: colorScheme.onPrimary,
                  size: 24,
                ),
        ),
      ),
    );
  }
}

// ── Circle Icon Button ──

class _CircleIconButton extends StatelessWidget {
  final FaIconData icon;
  final VoidCallback? onPressed;
  final bool isActive;

  const _CircleIconButton({
    required this.icon,
    this.onPressed,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive
              ? colorScheme.primary.withValues(alpha: 0.30)
              : colorScheme.scrim.withValues(alpha: 0.42),
          border: Border.all(
            color: colorScheme.onSurface.withValues(alpha: 0.22),
          ),
        ),
        child: Center(
          child: FaIcon(
            icon,
            color: isActive ? colorScheme.secondary : colorScheme.onSurface,
            size: 18,
          ),
        ),
      ),
    );
  }
}

// ── Receipt Result Bottom Sheet ──

class _ReceiptResultSheet extends StatefulWidget {
  final ReceiptData receiptData;
  final VoidCallback onSave;
  final ValueChanged<ReceiptData> onFieldChanged;

  const _ReceiptResultSheet({
    required this.receiptData,
    required this.onSave,
    required this.onFieldChanged,
  });

  @override
  State<_ReceiptResultSheet> createState() => _ReceiptResultSheetState();
}

class _ReceiptResultSheetState extends State<_ReceiptResultSheet> {
  late final TextEditingController _merchantController;
  late final TextEditingController _amountController;
  late final TextEditingController _dateController;
  late final List<_LineItemControllers> _lineItemControllers;

  @override
  void initState() {
    super.initState();
    final data = widget.receiptData;
    _merchantController = TextEditingController(text: data.merchantName ?? '');
    _amountController = TextEditingController(
      text: data.totalAmount?.toStringAsFixed(2) ?? '',
    );
    _dateController = TextEditingController(
      text: data.date != null
          ? DateFormat('dd/MM/yyyy').format(data.date!)
          : '',
    );
    _lineItemControllers = data.lineItems.map((item) {
      return _LineItemControllers(
        description: TextEditingController(text: item.description),
        amount: TextEditingController(text: item.amount.toStringAsFixed(2)),
      );
    }).toList();
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _amountController.dispose();
    _dateController.dispose();
    for (final c in _lineItemControllers) {
      c.description.dispose();
      c.amount.dispose();
    }
    super.dispose();
  }

  void _notifyChanges() {
    final lineItems = _lineItemControllers.map((c) {
      return LineItem(
        description: c.description.text,
        amount: double.tryParse(c.amount.text) ?? 0.0,
      );
    }).toList();

    // Parse date from text
    DateTime? parsedDate;
    final parts = _dateController.text.split('/');
    if (parts.length == 3) {
      final d = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final y = int.tryParse(parts[2]);
      if (d != null && m != null && y != null) {
        parsedDate = DateTime(y, m, d);
      }
    }

    widget.onFieldChanged(
      ReceiptData(
        merchantName: _merchantController.text.isNotEmpty
            ? _merchantController.text
            : null,
        totalAmount: double.tryParse(_amountController.text),
        date: parsedDate ?? widget.receiptData.date,
        lineItems: lineItems,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Radii.xl),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: Spacing.sm),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: Radii.borderFull,
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(Spacing.md),
            child: Row(
              children: [
                FaIcon(
                  FontAwesomeIcons.receipt,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: Spacing.sm),
                Text(
                  'Receipt Details',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const FaIcon(FontAwesomeIcons.xmark, size: 18),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Editable fields
          Flexible(
            child: SingleChildScrollView(
              padding: Spacing.paddingMd,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Merchant name
                  TextField(
                    controller: _merchantController,
                    onChanged: (_) => _notifyChanges(),
                    decoration: const InputDecoration(
                      labelText: 'Merchant Name',
                      prefixIcon: Icon(Icons.store_outlined),
                    ),
                  ),
                  const SizedBox(height: Spacing.md),

                  // Amount and Date row
                  Row(
                    children: [
                      Expanded(
                        child: Consumer(
                          builder: (context, ref, _) => TextField(
                            controller: _amountController,
                            onChanged: (_) => _notifyChanges(),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Total Amount',
                              prefixText:
                                  '${ref.watch(currencySymbolProvider)} ',
                              prefixIcon: const Icon(Icons.currency_exchange),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: Spacing.md),
                      Expanded(
                        child: TextField(
                          controller: _dateController,
                          onChanged: (_) => _notifyChanges(),
                          decoration: const InputDecoration(
                            labelText: 'Date',
                            hintText: 'DD/MM/YYYY',
                            prefixIcon: Icon(Icons.calendar_today_outlined),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Line items
                  if (_lineItemControllers.isNotEmpty) ...[
                    const SizedBox(height: Spacing.lg),
                    Text(
                      'Line Items',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: Spacing.sm),
                    ...List.generate(_lineItemControllers.length, (i) {
                      final c = _lineItemControllers[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: Spacing.sm),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: c.description,
                                onChanged: (_) => _notifyChanges(),
                                style: theme.textTheme.bodySmall,
                                decoration: InputDecoration(
                                  isDense: true,
                                  hintText: 'Item ${i + 1}',
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: Spacing.sm,
                                    vertical: Spacing.sm,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: Spacing.sm),
                            Expanded(
                              flex: 1,
                              child: TextField(
                                controller: c.amount,
                                onChanged: (_) => _notifyChanges(),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                style: theme.textTheme.bodySmall,
                                textAlign: TextAlign.end,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: Spacing.sm,
                                    vertical: Spacing.sm,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],

                  const SizedBox(height: Spacing.lg),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: widget.onSave,
                      icon: const FaIcon(FontAwesomeIcons.floppyDisk, size: 18),
                      label: const Text('Save as Transaction'),
                    ),
                  ),

                  const SizedBox(height: Spacing.sm),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().slideY(begin: 0.1, duration: 300.ms, curve: Curves.easeOut);
  }
}

class _LineItemControllers {
  final TextEditingController description;
  final TextEditingController amount;

  _LineItemControllers({required this.description, required this.amount});
}
