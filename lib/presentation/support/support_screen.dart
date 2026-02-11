import 'package:flutter/foundation.dart'; // For kIsWeb check
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  // --- CONFIGURATION ---
  final String _supportPhone = "+919321962944";
  final String _supportEmail = "gstsupport@globalspace.in";
  final String _supportUrl = "https://crm.globalspace.in/forms/ticket?styled=1";

  Future<void> _launchAction(BuildContext context, Uri uri) async {
    try {
      // 1. Try launching with external application mode (Best for Mobile & tel/mailto)
      bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      // 2. Fallback for Web: If external mode fails (common for http links on some browsers),
      // try platform default (which usually opens a new tab).
      if (!launched) {
        launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
      }

      // 3. Error Handling
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Could not launch ${uri.scheme} link"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error launching URL: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4A148C),
        title: Text(
          "Help & Support",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        leading: const BackButton(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: Container(
          // Constrain width for Web to prevent cards stretching too wide
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Text
                Text(
                  "Get in touch",
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "We are here to help you. Choose a method below to contact our support team.",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 32),

                // 1. CALL SUPPORT
                _buildContactCard(
                  icon: Icons.phone_in_talk,
                  title: "Call Us",
                  subtitle: "Talk to a representative immediately",
                  actionText: "Call Now",
                  color: Colors.green,
                  onTap: () =>
                      _launchAction(context, Uri.parse("tel:$_supportPhone")),
                ),

                const SizedBox(height: 16),

                // 2. EMAIL SUPPORT
                _buildContactCard(
                  icon: Icons.email_outlined,
                  title: "Email Support",
                  subtitle: "Send us a detailed query",
                  actionText: "Send Email",
                  color: Colors.orange,
                  onTap: () => _launchAction(
                    context,
                    Uri.parse(
                      "mailto:$_supportEmail?subject=App Support Request",
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 3. SUBMIT TICKET (WEB)
                _buildContactCard(
                  icon: Icons.assignment_outlined,
                  title: "Submit an Issue",
                  subtitle:
                      "Fill out a form regarding bugs or technical issues",
                  actionText: "Open Form",
                  color: const Color(0xFF4A148C),
                  onTap: () => _launchAction(context, Uri.parse(_supportUrl)),
                ),
                const SizedBox(height: 40),

                // Footer Info
                Center(
                  child: Column(
                    children: [
                      Text(
                        "Available Mon-Fri, 10 AM - 6 PM",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "v1.0.0",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionText,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  height: 50,
                  width: 50,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                // Hide arrow on web if you want, or keep it. Keeping it for consistency.
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
