import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Camera page that detects the first QR code in view and returns its raw
/// content via `Navigator.pop(context, rawString)`.
///
/// Pops `null` if the user cancels with the back button.
class EInvoiceQrScannerPage extends StatefulWidget {
  const EInvoiceQrScannerPage({super.key, this.title = 'Scan e-Invoice QR', this.typeHint, this.prompt = 'Fill the box with the e-invoice QR'});

  /// The app bar title (the delivery challan scan reuses this page).
  final String title;

  /// When set, a "Type it" action lets the user key the code in instead
  /// (no camera, or a damaged print); the hint shows in the field.
  final String? typeHint;

  /// The line under the camera box telling the user what to point it at.
  final String prompt;

  @override
  State<EInvoiceQrScannerPage> createState() => _EInvoiceQrScannerPageState();
}

class _EInvoiceQrScannerPageState extends State<EInvoiceQrScannerPage> {
  late final MobileScannerController _controller;
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
      // Tally e-invoice QRs encode a ~700-byte JWT — Version 25+ codes with
      // very small modules. The default 640x480 analyzer cannot resolve them
      // reliably. Bumping to 720p plus autoZoom drastically improves decode
      // rate on dense QR codes.
      cameraResolution: const Size(1280, 720),
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      returnImage: false,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _typeIt() async {
    final controller = TextEditingController();
    final typed = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(widget.title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(hintText: widget.typeHint),
          onSubmitted: (v) => Navigator.of(d).pop(v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(d).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(d).pop(controller.text), child: const Text('Find')),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || typed == null || typed.trim().isEmpty || _handled) return;
    _handled = true;
    Navigator.of(context).pop(typed.trim());
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final raw = barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;
    _handled = true;
    Navigator.of(context).pop(raw);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (widget.typeHint != null)
            IconButton(
              tooltip: 'Type it',
              icon: const Icon(Icons.keyboard_outlined),
              onPressed: _typeIt,
            ),
          IconButton(
            tooltip: 'Toggle torch',
            icon: const Icon(Icons.flash_on_outlined),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            tooltip: 'Switch camera',
            icon: const Icon(Icons.cameraswitch_outlined),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.redAccent, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        'Camera unavailable',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        error.errorDetails?.message ?? error.errorCode.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          IgnorePointer(
            child: Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = (constraints.maxWidth < constraints.maxHeight
                              ? constraints.maxWidth
                              : constraints.maxHeight) *
                          0.78;
                  return Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 32,
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.prompt,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Hold steady • good light • 15-25 cm distance',
                      style:
                          TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
