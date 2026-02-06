import 'package:flutter/material.dart';
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
  bool _isLoading = false;

  Future<void> _submit() async {
    if (_newPassController.text != _confirmPassController.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Passwords do not match")));
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      // Call API to change password
      await ApiService().changePassword(_newPassController.text);
      
      if (mounted) {
        // If successful, go to Dashboard
       Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const DashboardScreen(),
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Hide AppBar back button if forced
      appBar: AppBar(title: const Text("Set New Password"), automaticallyImplyLeading: !widget.isForced),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            if (widget.isForced)
              const Padding(
                padding: EdgeInsets.only(bottom: 20),
                child: Text("For security, please change your password before continuing.", style: TextStyle(color: Colors.red)),
              ),
            TextField(
              controller: _newPassController,
              decoration: const InputDecoration(labelText: "New Password", border: OutlineInputBorder()),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPassController,
              decoration: const InputDecoration(labelText: "Confirm Password", border: OutlineInputBorder()),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              child: _isLoading ? const CircularProgressIndicator() : const Text("UPDATE PASSWORD", style: TextStyle(fontSize: 16)),
            )
          ],
        ),
      ),
    );
  }
}