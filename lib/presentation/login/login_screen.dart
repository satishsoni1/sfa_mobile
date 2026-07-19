import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zforce/presentation/dashboard/dashboard_screen.dart';
import 'package:zforce/presentation/login/change_password_screen.dart';
// Add the import for your new Forgot Password Screen (adjust path as needed)
import 'forgot_password_screen.dart'; 
import '../../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {

  final _empIdController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;

  final String _appVersion = "v1.0.0";
  final String _supportNumber = "+919321962944";

  @override
  void dispose() {
    _empIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _callSupport() async {
    final Uri launchUri = Uri(scheme: 'tel', path: _supportNumber);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Unable to open dialer"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleLogin() async {
    FocusManager.instance.primaryFocus?.unfocus();

    if (_empIdController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter Employee ID and Password"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final success = await Provider.of<AuthProvider>(
      context,
      listen: false,
    ).login(
      _empIdController.text,
      _passwordController.text,
    );

    if (mounted) setState(() => _isLoading = false);

    if (success == "FIRST_LOGIN") {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const ChangePasswordScreen(isForced: true),
          ),
        );
      }
    } else if (success == "SUCCESS") {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => const DashboardScreen()),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text("Invalid Credentials or Network Error"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: true,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.white,
          child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.grey[300]!,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                      // Logo
                  SizedBox(
                    height: 45,
                    child: Image.asset(
                      'assets/images/vodo_clm_new_logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.broken_image, size: 50, color: Colors.grey);
                      },
                    ),
                  ),
                      const SizedBox(height: 16),
                      Text(
                        "Welcome Back",
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF4A148C),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Sign in to continue",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 35),

                      // Employee ID Field
                  TextField(
                    controller: _empIdController,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Employee ID',
                          labelStyle: TextStyle(color: Colors.grey[600]),
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF4A148C), width: 1.5),
                          ),
                          prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF4A148C)),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Password Field
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _handleLogin(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                          labelStyle: TextStyle(color: Colors.grey[600]),
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF4A148C), width: 1.5),
                          ),
                          prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF4A148C)),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Forgot Password
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ForgotPasswordScreen(),
                          ),
                        );
                      },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(50, 30),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                      child: Text(
                        "Forgot Password?",
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF6A1B9A),
                          fontWeight: FontWeight.w600,
                              fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                      const SizedBox(height: 30),

                      // Login Button
                  SizedBox(
                    height: 54,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A148C),
                        foregroundColor: Colors.white,
                            elevation: 5,
                            shadowColor: const Color(0xFF4A148C).withOpacity(0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text(
                              'LOGIN',
                              style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                              ),
                            ),
                    ),
                  ),
                      const SizedBox(height: 30),

                      // Support & Version
                      Divider(color: Colors.grey[200], thickness: 1.5),
                  const SizedBox(height: 15),
                  TextButton.icon(
                    onPressed: _callSupport,
                    icon: const Icon(
                      Icons.support_agent_rounded,
                      color: Color(0xFF6A1B9A),
                      size: 20,
                    ),
                    label: Text(
                      "Need Help? Call Support",
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: const Color(0xFF6A1B9A),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Powered by GlobalSpace',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _appVersion,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}