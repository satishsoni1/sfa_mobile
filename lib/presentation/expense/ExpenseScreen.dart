import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/services/api_service.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  // Controllers
  final _otherAmtController = TextEditingController();
  final _remarkController = TextEditingController();

  // State Variables
  DateTime _selectedDate = DateTime.now();
  Map<String, dynamic>? _calcData;
  bool _isLoading = false;
  // File? _attachment;

  // Dynamic Total
  double _displayTotal = 0.0;

  @override
  void initState() {
    super.initState();
    // 1. Listen for changes in "Other Amount" to update total instantly
    _otherAmtController.addListener(_recalculateTotal);

    // 2. Fetch initial calculation for today
    _fetchCalculation();
  }

  @override
  void dispose() {
    _otherAmtController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  // --- LOGIC ---

  void _recalculateTotal() {
    if (_calcData == null) return;

    // FIX: Safely convert whatever comes from API (Int/String/Double) to Double
    double da = double.tryParse(_calcData!['da_amount'].toString()) ?? 0.0;
    double ta = double.tryParse(_calcData!['ta_amount'].toString()) ?? 0.0;

    double baseAmount = da + ta;

    // Safely parse the manual input text
    double otherAmount = double.tryParse(_otherAmtController.text) ?? 0.0;

    setState(() {
      _displayTotal = baseAmount + otherAmount;
    });
  }

  void _fetchCalculation() async {
    setState(() {
      _isLoading = true;
      _calcData = null;
      _displayTotal = 0.0;
    });

    try {
      final data = await ApiService().calculateExpense(_selectedDate);

      if (mounted) {
        setState(() {
          _calcData = data;
          // Trigger total calculation once data is loaded
          _recalculateTotal();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Note: $e"),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 50,
    );

    if (pickedFile != null) {
      // setState(() => _attachment = File(pickedFile.path));
    }
  }

  void _submit() async {
    if (_calcData == null) return;

    setState(() => _isLoading = true);

    try {
      // 1. Prepare the data with FORCED String conversion
      // Using "$value" ensures it is ALWAYS a string, no matter what.
      final Map<String, String> payload = {
        'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'da_type': "${_calcData!['da_type']}", // Force String
        'da_amount': "${_calcData!['da_amount']}", // Force String
        'ta_distance': "${_calcData!['total_km']}", // Force String
        'ta_amount': "${_calcData!['ta_amount']}", // Force String
        'other_amount': _otherAmtController.text.isEmpty
            ? "0"
            : _otherAmtController.text,
        'remarks': _remarkController.text.isEmpty ? "" : _remarkController.text,
      };

      // 2. Call API
      // await ApiService().submitExpense(payload, _attachment);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Submitted Successfully!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
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
  // --- UI ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: Text("Daily Expense", style: GoogleFonts.poppins()),
        backgroundColor: const Color(0xFF4A148C),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Date Picker
            InkWell(
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2023),
                  lastDate: DateTime.now(),
                );
                if (d != null) {
                  setState(() => _selectedDate = d);
                  _fetchCalculation();
                }
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('dd MMMM yyyy').format(_selectedDate),
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const Icon(Icons.calendar_month, color: Color(0xFF4A148C)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 2. Main Content
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 50.0),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_calcData == null)
              Padding(
                padding: const EdgeInsets.only(top: 50.0),
                child: Center(
                  child: Text(
                    "No visits found for this date.\nCannot calculate expense.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(color: Colors.grey),
                  ),
                ),
              )
            else ...[
              // DA Card
              _buildSectionHeader("Daily Allowance (DA)"),
              _buildInfoCard(
                title: "${_calcData!['da_type']} Allowance",
                subtitle: "Based on visited territories",
                amount: "₹${_calcData!['da_amount']}",
                icon: Icons.person_pin_circle,
                color: Colors.blue,
              ),

              const SizedBox(height: 16),

              // TA Card
              _buildSectionHeader("Travel Allowance (TA)"),
              _buildInfoCard(
                title: "${_calcData!['total_km']} KM",
                subtitle: "Rate: ₹${_calcData!['ta_rate']}/km",
                amount: "₹${_calcData!['ta_amount']}",
                icon: Icons.directions_car,
                color: Colors.green,
              ),

              const SizedBox(height: 20),

              // Manual Inputs Section
              _buildSectionHeader("Additional Expenses"),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _otherAmtController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: "Other Amount (₹)",
                        border: OutlineInputBorder(),
                        hintText: "0.00",
                        prefixIcon: Icon(Icons.currency_rupee),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _remarkController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: "Remarks / Reason",
                        border: OutlineInputBorder(),
                        hintText: "e.g. Stationary, Toll, etc.",
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Attachment Button
                    InkWell(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.grey.shade400,
                            style: BorderStyle.solid,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey.shade50,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Icon(
                            //   _attachment == null
                            //       ? Icons.attach_file
                            //       : Icons.check_circle,
                            //   color: _attachment == null
                            //       ? Colors.grey
                            //       : Colors.green,
                            // ),
                            const SizedBox(width: 8),
                            // Text(
                            //   _attachment == null
                            //       ? "Attach Bill / Ticket"
                            //       : "Image Attached",
                            //   style: TextStyle(
                            //     fontWeight: FontWeight.w600,
                            //     color: _attachment == null
                            //         ? Colors.grey[700]
                            //         : Colors.green,
                            //   ),
                            // ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Total & Submit
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A148C).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF4A148C).withOpacity(0.1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Total Payable:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      "₹${_displayTotal.toStringAsFixed(2)}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                        color: Color(0xFF4A148C),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A148C),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    "SUBMIT EXPENSE",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30), // Bottom padding
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          color: Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String subtitle,
    required String amount,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}
