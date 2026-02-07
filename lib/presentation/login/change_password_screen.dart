import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zforce/presentation/dashboard/dashboard_screen.dart';
import '../../data/services/api_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  final bool isForced; // If true, hide back button
  const ChangePasswordScreen({this.isForced = false, super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();
  final _formKey = GlobalKey<FormState>(); // For validation

  bool _isLoading = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await ApiService().changePassword(_newPassController.text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Password updated successfully!"),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to Dashboard
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF4A148C);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: !widget.isForced
            ? const BackButton(color: Colors.black)
            : null,
        centerTitle: true,
        title: Text(
          "Set New Password",
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Header Icon & Text
                const SizedBox(height: 20),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_reset,
                      size: 60,
                      color: primaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  widget.isForced
                      ? "Security Update Required"
                      : "Create Strong Password",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.isForced
                      ? "For your security, please update your password before continuing."
                      : "Your new password must be different from previous used passwords.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),

                const SizedBox(height: 40),

                // 2. New Password Field
                TextFormField(
                  controller: _newPassController,
                  obscureText: _obscureNew,
                  validator: (value) {
                    if (value == null || value.length < 6)
                      return "Password must be at least 6 characters";
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: "New Password",
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureNew ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () =>
                          setState(() => _obscureNew = !_obscureNew),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 3. Confirm Password Field
                TextFormField(
                  controller: _confirmPassController,
                  obscureText: _obscureConfirm,
                  validator: (value) {
                    if (value != _newPassController.text)
                      return "Passwords do not match";
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: "Confirm Password",
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // 4. Submit Button
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            "UPDATE PASSWORD",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
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
