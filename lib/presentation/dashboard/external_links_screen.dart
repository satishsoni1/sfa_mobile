import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zforce/core/constants/app_colors.dart';
import 'package:zforce/data/services/api_service.dart';
import 'package:zforce/presentation/webview/internal_webview_screen.dart';

class ExternalLinksScreen extends StatefulWidget {
  final String employeeCode;

  const ExternalLinksScreen({super.key, required this.employeeCode});

  @override
  State<ExternalLinksScreen> createState() => _ExternalLinksScreenState();
}

class _ExternalLinksScreenState extends State<ExternalLinksScreen> {
  late final Future<List<_ExternalLink>> _linksFuture;

  @override
  void initState() {
    super.initState();
    _linksFuture = _loadLinks();
  }

  Future<List<_ExternalLink>> _loadLinks() async {
    final response =
        await ApiService().getExternalLinks(employeeCode: widget.employeeCode);

    return response
        .whereType<Map<String, dynamic>>()
        .map(_ExternalLink.fromJson)
        .where(
          (link) => link.isWeb && link.title.isNotEmpty && link.url.isNotEmpty,
        )
        .toList();
  }

  String _buildEmployeeUrl(String rawUrl) {
    // Employee code is already sent while fetching /links; use backend URLs as-is.
    final uri = Uri.tryParse(rawUrl.trim());
    return uri?.toString() ?? rawUrl;
  }

 Future<void> _openLink(_ExternalLink link) async {
    final url = _buildEmployeeUrl(link.url);
    final uri = Uri.tryParse(url);
    final opensInsideApp = uri?.host == 'zorvia.globalspace.in';

    if (!opensInsideApp && uri != null) {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        _showSnack('Unable to open ${link.title}.');
      }
      return;
    }
    Navigator.pushNamed(
      context,
      InternalWebViewScreen.routeName,
      arguments: InternalWebViewArgs(
        url:url,
        title: link.title,
      ),
    );
  }

   void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text(
          'Other Links',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: FutureBuilder<List<_ExternalLink>>(
        future: _linksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (snapshot.hasError) {
            return _StateMessage(
              icon: Icons.error_outline,
              message: 'Unable to load links.',
            );
          }

          final links = snapshot.data ?? [];
          if (links.isEmpty) {
            return _StateMessage(
              icon: Icons.link_off,
              message: 'No web links available.',
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.35,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
            itemCount: links.length,
            itemBuilder: (context, index) {
              final link = links[index];
              return _LinkCard(
                link: link,
                onTap: () => _openLink(link),
              );
            },
          );
        },
      ),
    );
  }
}

class _LinkCard extends StatelessWidget {
  final _ExternalLink link;
  final VoidCallback onTap;

  const _LinkCard({required this.link, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              link.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  final IconData icon;
  final String message;

  const _StateMessage({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.grey, size: 42),
          const SizedBox(height: 12),
          Text(
            message,
            style: GoogleFonts.poppins(
              color: Colors.black54,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExternalLink {
  final String title;
  final String url;
  final bool isWeb;

  const _ExternalLink({
    required this.title,
    required this.url,
    required this.isWeb,
  });

  factory _ExternalLink.fromJson(Map<String, dynamic> json) {
    return _ExternalLink(
      title: json['title']?.toString().trim() ?? '',
      url: json['url']?.toString().trim() ?? '',
      isWeb: json['is_web'] == 1 || json['is_web'] == true,
      // Future backend support: when a "logo" field is added, read it here and
      // render the image inside _LinkCard above the title.
    );
  }
}
