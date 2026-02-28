import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/services/api_service.dart';
import 'reset_password_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;

  const OtpVerificationScreen({super.key, required this.email});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otpController = TextEditingController();
  bool _isLoading = false;
  final Color _primaryColor = const Color(0xFF4A148C);

  // Resend Timer Logic
  int _resendTimer = 60;
  Timer? _timer;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _otpController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _resendTimer = 60;
      _canResend = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimer == 0) {
        setState(() => _canResend = true);
        timer.cancel();
      } else {
        setState(() => _resendTimer--);
      }
    });
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enter a valid 6-digit OTP")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ApiService().verifyPasswordResetOtp(widget.email, _otpController.text.trim());
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => ResetPasswordScreen(email: widget.email, otp: _otpController.text.trim())),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Invalid OTP"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendOtp() async {
    setState(() => _isLoading = true);
    try {
      await ApiService().sendPasswordResetOtp(widget.email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("OTP Resent Successfully!"), backgroundColor: Colors.green));
        _startTimer();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to resend"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: _primaryColor),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "OTP Verification",
                style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              Text(
                "Enter the verification code we just sent to your email address: ${widget.email}",
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 40),
              
              // OTP Input
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                style: GoogleFonts.poppins(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  counterText: "",
                  hintText: "------",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
              
              const SizedBox(height: 30),
              
              // Verify Button
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text("Verify", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
              
              const SizedBox(height: 30),
              
              // Resend Logic
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Didn't receive code? ", style: GoogleFonts.poppins(color: Colors.grey.shade600)),
                  _canResend 
                    ? InkWell(
                        onTap: _isLoading ? null : _resendOtp,
                        child: Text("Resend", style: GoogleFonts.poppins(color: _primaryColor, fontWeight: FontWeight.bold)),
                      )
                    : Text("Wait ${_resendTimer}s", style: GoogleFonts.poppins(color: Colors.grey, fontWeight: FontWeight.bold)),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}