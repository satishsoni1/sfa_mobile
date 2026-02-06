import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key}); 

  // --- CONFIGURATION ---
  final String _supportPhone = "+919876543210"; // Replace with actual number
  final String _supportEmail = "support@globalspace.com"; // Replace with actual email
  final String _supportUrl = "https://globalspace.com/support-ticket"; // Replace with actual form URL

  Future<void> _launchAction(Uri uri) async {
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint("Could not launch $uri");
      }
    } catch (e) {
      debugPrint("Error launching URL: $e");
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
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        leading: const BackButton(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
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
              onTap: () => _launchAction(Uri.parse("tel:$_supportPhone")),
            ),

            const SizedBox(height: 16),

            // 2. EMAIL SUPPORT
            _buildContactCard(
              icon: Icons.email_outlined,
              title: "Email Support",
              subtitle: "Send us a detailed query",
              actionText: "Send Email",
              color: Colors.orange,
              onTap: () => _launchAction(Uri.parse("mailto:$_supportEmail?subject=App Support Request")),
            ),

            const SizedBox(height: 16),

            // 3. SUBMIT TICKET (WEB)
            _buildContactCard(
              icon: Icons.assignment_outlined,
              title: "Submit an Issue",
              subtitle: "Fill out a form regarding bugs or technical issues",
              actionText: "Open Form",
              color: const Color(0xFF4A148C),
              onTap: () => _launchAction(Uri.parse(_supportUrl)),
            ),
            
            const SizedBox(height: 40),
            
            // Footer Info
            Center(
              child: Column(
                children: [
                  Text(
                    "Available Mon-Sat, 9 AM - 6 PM",
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "v1.0.0",
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
          ],
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
                const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}