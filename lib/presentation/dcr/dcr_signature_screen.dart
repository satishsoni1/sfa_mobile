import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:signature/signature.dart';

class DcrSignatureScreen extends StatefulWidget {
  const DcrSignatureScreen({super.key});

  @override
  State<DcrSignatureScreen> createState() => _DcrSignatureScreenState();
}

class _DcrSignatureScreenState extends State<DcrSignatureScreen> {
  static const _purple = Color(0xFF4A148C);

  late final SignatureController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = SignatureController(
      penColor: Colors.black,
      penStrokeWidth: 2.5,
      exportBackgroundColor: Colors.white,
    );
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _hasSignature => _controller.isNotEmpty;

  Future<void> _confirm() async {
    if (!_hasSignature) return;
    setState(() => _saving = true);
    try {
      final Uint8List? pngBytes = await _controller.toPngBytes();
      if (pngBytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not export signature.')));
        }
        return;
      }
      final dir = await getApplicationDocumentsDirectory();
      final sigDir =
          Directory(p.join(dir.path, 'dcr', 'signatures'));
      await sigDir.create(recursive: true);
      final path = p.join(sigDir.path,
          'sig_${DateTime.now().millisecondsSinceEpoch}.png');
      await File(path).writeAsBytes(pngBytes);
      if (mounted) Navigator.pop(context, path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Digital Signature',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed:
                _hasSignature ? () => _controller.clear() : null,
            child: const Text('Clear',
                style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            'Please sign below to confirm sample receipt',
            style: GoogleFonts.poppins(
                fontSize: 13, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                    color: _purple.withValues(alpha: 0.3), width: 1.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Signature(
                  controller: _controller,
                  backgroundColor: Colors.white,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),
          ),
        ),
        if (!_hasSignature)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('↑ Sign here',
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade400)),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SafeArea(
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    _hasSignature && !_saving ? _confirm : null,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check_outlined),
                label: Text('Confirm Signature',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _purple,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
