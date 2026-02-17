import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/services/api_service.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;
  final String otp; // Pass the verified OTP to validate the reset request on backend

  const ResetPasswordScreen({super.key, required this.email, required this.otp});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  final Color _primaryColor = const Color(0xFF4A148C);

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await ApiService().resetPasswordWithOtp(widget.email, widget.otp, _passwordController.text);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password changed successfully!"), backgroundColor: Colors.green));
        // Pop all screens and go back to Login Screen
        Navigator.popUntil(context, (route) => route.isFirst); 
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, iconTheme: IconThemeData(color: _primaryColor)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Create New Password", style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 8),
                Text("Your new password must be unique from those previously used.", style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600)),
                const SizedBox(height: 40),
                
                // New Password
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePass,
                  decoration: InputDecoration(
                    labelText: "New Password",
                    prefixIcon: Icon(Icons.lock_outline, color: _primaryColor),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                      onPressed: () => setState(() => _obscurePass = !_obscurePass),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true, fillColor: Colors.grey[50],
                  ),
                  validator: (v) => v!.length < 6 ? "Password must be at least 6 characters" : null,
                ),
                
                const SizedBox(height: 20),
                
                // Confirm Password
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    labelText: "Confirm Password",
                    prefixIcon: Icon(Icons.lock_outline, color: _primaryColor),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                      onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true, fillColor: Colors.grey[50],
                  ),
                  validator: (v) {
                    if (v != _passwordController.text) return "Passwords do not match";
                    return null;
                  },
                ),
                
                const SizedBox(height: 40),
                
                // Reset Button
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _resetPassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text("Reset Password", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}