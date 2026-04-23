import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:zforce/core/constants/app_colors.dart';

import 'iframe_view_stub.dart'
    if (dart.library.html) 'iframe_view_web.dart';

class InternalWebViewArgs {
  final String url;
  final String title;

  const InternalWebViewArgs({
    required this.url,
    this.title = 'Tab Joint Work',
  });
}

class InternalWebViewScreen extends StatefulWidget {
  static const String routeName = '/webview';

  final InternalWebViewArgs args;

  const InternalWebViewScreen({super.key, required this.args});

  @override
  State<InternalWebViewScreen> createState() => _InternalWebViewScreenState();
}

class _InternalWebViewScreenState extends State<InternalWebViewScreen> {
  late final String _viewType;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _viewType =
        'internal-iframe-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(99999)}';
    if (!kIsWeb) {
      _isLoading = false;
    }
  }

  void _handleLoaded() {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _errorMessage = null;
    });
  }

  void _handleError(String message) {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _errorMessage = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8F9),
      appBar: AppBar(
        title: Text(
          widget.args.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final frameHeight = max(320.0, constraints.maxHeight - 24);

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 24,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    height: frameHeight,
                    color: Colors.white,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: kIsWeb
                              ? buildInternalIFrameView(
                                  url: widget.args.url,
                                  viewType: _viewType,
                                  onFrameLoaded: _handleLoaded,
                                  onFrameError: _handleError,
                                )
                              : const _FallbackMessage(
                                  message:
                                      'This screen is available only in Flutter Web.',
                                ),
                        ),
                        if (_isLoading)
                          const Positioned.fill(
                            child: ColoredBox(
                              color: Colors.white,
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                        if (_errorMessage != null)
                          Positioned.fill(
                            child: _FallbackMessage(message: _errorMessage!),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FallbackMessage extends StatelessWidget {
  final String message;

  const _FallbackMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.orange,
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
