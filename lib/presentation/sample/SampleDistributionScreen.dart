import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:signature/signature.dart';
import '../../providers/report_provider.dart';
import '../../data/models/doctor.dart';

// --- MOCK PRODUCT MODEL (Replace with your actual model) ---
class Product {
  final int id;
  final String name;
  final String type; // e.g., 'Tablet', 'Syrup'

  Product({required this.id, required this.name, required this.type});
}

class SampleDistributionScreen extends StatefulWidget {
  const SampleDistributionScreen({super.key});

  @override
  State<SampleDistributionScreen> createState() =>
      _SampleDistributionScreenState();
}

class _SampleDistributionScreenState extends State<SampleDistributionScreen> {
  // Controllers
  final SignatureController _sigController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  final TextEditingController _remarkController = TextEditingController();

  // State
  Doctor? _selectedDoctor;
  final List<Map<String, dynamic>> _addedItems =
      []; // Stores {product: Product, qty: int}
  bool _isSubmitting = false;

  // Mock Data (Replace with Provider/API)
  final List<Product> _allProducts = [
    Product(id: 1, name: "Dolo 650", type: "Tablet"),
    Product(id: 2, name: "Azithral 500", type: "Tablet"),
    Product(id: 3, name: "Cough Syrup A", type: "Syrup"),
    Product(id: 4, name: "Vitamin C", type: "Capsule"),
  ];

  @override
  void initState() {
    super.initState();
    // Load doctors if not loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<ReportProvider>(context, listen: false);
      if (provider.doctors.isEmpty) {
        provider.fetchDoctors();
      }
    });
  }

  @override
  void dispose() {
    _sigController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  // --- ACTIONS ---

  void _addItem() {
    setState(() {
      // Add empty placeholder row
      _addedItems.add({'product': null, 'qty': 1});
    });
  }

  void _removeItem(int index) {
    setState(() {
      _addedItems.removeAt(index);
    });
  }

  Future<void> _submit() async {
    // Validation
    if (_selectedDoctor == null) {
      _showError("Please select a doctor.");
      return;
    }
    if (_addedItems.isEmpty ||
        _addedItems.any((item) => item['product'] == null)) {
      _showError("Please add valid products.");
      return;
    }
    if (_sigController.isEmpty) {
      _showError("Doctor's signature is required.");
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // 1. Export Signature to Bytes (Image)
      final Uint8List? signatureBytes = await _sigController.toPngBytes();

      if (signatureBytes != null) {
        // 2. Prepare Data Payload
        final payload = {
          'doctor_id': _selectedDoctor!.id,
          'remark': _remarkController.text,
          'items': _addedItems
              .map(
                (e) => {
                  'product_id': (e['product'] as Product).id,
                  'qty': e['qty'],
                },
              )
              .toList(),
          // 'signature': base64Encode(signatureBytes), // Send to API
        };

        // 3. Simulate API Call
        await Future.delayed(const Duration(seconds: 2));

        // print("Submitting: $payload"); // Debug

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Samples Distributed Successfully!"),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      _showError("Submission failed: $e");
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  // --- UI BUILDER ---

  @override
  Widget build(BuildContext context) {
    final doctors = Provider.of<ReportProvider>(context).doctors;
    final primaryColor = const Color(0xFF5E35B1);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          "Sample Distribution",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. DOCTOR SELECTION
            _buildSectionLabel("Select Doctor"),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Doctor>(
                  value: _selectedDoctor,
                  hint: Text(
                    "Choose a doctor...",
                    style: GoogleFonts.poppins(color: Colors.grey),
                  ),
                  isExpanded: true,
                  icon: const Icon(
                    Icons.arrow_drop_down_circle,
                    color: Color(0xFF5E35B1),
                  ),
                  items: doctors.map((doc) {
                    return DropdownMenuItem(
                      value: doc,
                      child: Text(
                        doc.name,
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedDoctor = val),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 2. PRODUCTS LIST
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionLabel("Products Given"),
                TextButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add_circle, size: 18),
                  label: const Text("Add Item"),
                  style: TextButton.styleFrom(foregroundColor: primaryColor),
                ),
              ],
            ),

            if (_addedItems.isEmpty)
              _buildEmptyState()
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _addedItems.length,
                itemBuilder: (context, index) {
                  return _buildProductRow(index);
                },
              ),

            // 3. SUMMARY
            if (_addedItems.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 18,
                      color: Color(0xFF5E35B1),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Total Quantity: ${_addedItems.fold<int>(0, (sum, item) => sum + (item['qty'] as int))}",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // 4. SIGNATURE PAD
            _buildSectionLabel("Doctor's Signature"),
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    Signature(
                      controller: _sigController,
                      backgroundColor: Colors.white,
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        onPressed: () => _sigController.clear(),
                        icon: const Icon(Icons.refresh, color: Colors.red),
                        tooltip: "Clear Signature",
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Text(
                        "Sign Here",
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 5. REMARKS
            _buildSectionLabel("Remarks (Optional)"),
            TextField(
              controller: _remarkController,
              decoration: InputDecoration(
                hintText: "Enter any notes...",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              maxLines: 2,
            ),

            const SizedBox(height: 30),

            // 6. SUBMIT BUTTON
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        "SUBMIT DISTRIBUTION",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildProductRow(int index) {
    final item = _addedItems[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Product Dropdown
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<Product>(
              value: item['product'],
              decoration: const InputDecoration(
                labelText: "Product",
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              items: _allProducts
                  .map(
                    (p) => DropdownMenuItem(
                      value: p,
                      child: Text(p.name, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                setState(() {
                  _addedItems[index]['product'] = val;
                });
              },
            ),
          ),

          // Qty Input
          Expanded(
            flex: 1,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextFormField(
                initialValue: item['qty'].toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  labelText: "Qty",
                ),
                onChanged: (val) {
                  setState(() {
                    _addedItems[index]['qty'] = int.tryParse(val) ?? 1;
                  });
                },
              ),
            ),
          ),

          // Delete Btn
          InkWell(
            onTap: () => _removeItem(index),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline,
                size: 18,
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.grey.shade300,
          style: BorderStyle.solid,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            color: Colors.grey.shade400,
            size: 30,
          ),
          const SizedBox(height: 8),
          Text(
            "No products added",
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
