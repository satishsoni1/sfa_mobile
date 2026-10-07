import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/gift_acceptance_provider.dart';
import '../../data/models/gift_shipment_model.dart';

class GiftShipmentDetailScreen extends StatefulWidget {
  final String shipmentId;

  const GiftShipmentDetailScreen({
    super.key,
    required this.shipmentId,
  });

  @override
  State<GiftShipmentDetailScreen> createState() => _GiftShipmentDetailScreenState();
}

class _GiftShipmentDetailScreenState extends State<GiftShipmentDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _qtyControllers = {};
  final Map<String, TextEditingController> _reasonControllers = {};

  static const Color _primaryColor = Color(0xFF00796B); // Consistent Teal Theme

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initControllers();
    });
  }

  void _initControllers() {
    final provider = Provider.of<GiftAcceptanceProvider>(context, listen: false);
    final shipment = provider.pendingShipments.firstWhere(
      (s) => s.shipmentId == widget.shipmentId,
      orElse: () => GiftShipmentModel(
        shipmentId: '',
        shippedOn: '',
        shippedBy: '',
        items: [],
      ),
    );

    for (var item in shipment.items) {
      final initialQty = item.acceptedQty ?? item.shippedQty;
      provider.updateAcceptedQty(widget.shipmentId, item.giftId, initialQty);

      _qtyControllers.putIfAbsent(
        item.giftId,
        () => TextEditingController(text: initialQty.toString()),
      );
      _reasonControllers.putIfAbsent(
        item.giftId,
        () => TextEditingController(text: item.rejectionReason ?? ''),
      );
    }
    setState(() {});
  }

  TextEditingController _getQtyController(ShipmentItem item) {
    return _qtyControllers.putIfAbsent(
      item.giftId,
      () => TextEditingController(text: (item.acceptedQty ?? item.shippedQty).toString()),
    );
  }

  TextEditingController _getReasonController(ShipmentItem item) {
    return _reasonControllers.putIfAbsent(
      item.giftId,
      () => TextEditingController(text: item.rejectionReason ?? ''),
    );
  }

  @override
  void dispose() {
    for (var c in _qtyControllers.values) {
      c.dispose();
    }
    for (var c in _reasonControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _acceptAllInFull(GiftShipmentModel shipment) {
    final provider = Provider.of<GiftAcceptanceProvider>(context, listen: false);
    setState(() {
      for (var item in shipment.items) {
        provider.updateAcceptedQty(widget.shipmentId, item.giftId, item.shippedQty);
        provider.updateRejectionReason(widget.shipmentId, item.giftId, '');
        _getQtyController(item).text = item.shippedQty.toString();
        _getReasonController(item).text = '';
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("All quantities set to full shipment count."),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final provider = Provider.of<GiftAcceptanceProvider>(context, listen: false);
    final success = await provider.submitAcceptance(widget.shipmentId);

    if (!mounted) return;

    if (success) {
      _showSuccessDialog();
    } else {
      final errorMsg = provider.errorMessage ?? "Failed to submit acceptance.";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 28),
            const SizedBox(width: 10),
            Text(
              "Acceptance Submitted",
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          "Shipment ${widget.shipmentId} has been successfully processed and approved stock added to your inventory.",
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade700),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx); // Close dialog
              Navigator.pop(context, true); // Return true to dashboard
            },
            child: const Text("Done", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GiftAcceptanceProvider>(context);
    final shipment = provider.pendingShipments.firstWhere(
      (s) => s.shipmentId == widget.shipmentId,
      orElse: () => GiftShipmentModel(
        shipmentId: widget.shipmentId,
        shippedOn: '',
        shippedBy: '',
        items: [],
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        title: Text(
          "Shipment Details",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: shipment.items.isEmpty
          ? const Center(child: CircularProgressIndicator(color: _primaryColor))
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Shipment Meta Card
                    _buildShipmentMetaCard(shipment),
                    const SizedBox(height: 16),

                    // Items Section Header + Quick Action
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "SHIPMENT ITEMS (${shipment.items.length})",
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                            letterSpacing: 1.1,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _acceptAllInFull(shipment),
                          icon: const Icon(Icons.done_all, size: 16, color: _primaryColor),
                          label: Text(
                            "Accept All in Full",
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Items List / Table Cards
                    ...shipment.items.map((item) => _buildItemCard(provider, item)),

                    const SizedBox(height: 24),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 1,
                        ),
                        onPressed: provider.isSubmitting ? null : _handleSubmit,
                        child: provider.isSubmitting
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(
                                "SUBMIT ACCEPTANCE",
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildShipmentMetaCard(GiftShipmentModel shipment) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "SHIPMENT NUMBER",
                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      shipment.shipmentId,
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryColor),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    "Action Required",
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.amber.shade900),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildMetaColumn(
                    label: "Shipped By",
                    value: shipment.shippedBy.isNotEmpty ? shipment.shippedBy : "Head Office",
                    icon: Icons.business,
                  ),
                ),
                Expanded(
                  child: _buildMetaColumn(
                    label: "Shipped Date",
                    value: shipment.shippedOn.isNotEmpty ? shipment.shippedOn : "-",
                    icon: Icons.calendar_today,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaColumn({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              Text(
                value,
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildItemCard(GiftAcceptanceProvider provider, ShipmentItem item) {
    final acceptedQty = item.acceptedQty ?? item.shippedQty;
    final isShort = acceptedQty < item.shippedQty;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isShort ? Colors.orange.shade300 : Colors.grey.shade200,
          width: isShort ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item Header: Gift Name + Batch
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: _primaryColor.withValues(alpha: 0.08),
                  child: const Icon(Icons.card_giftcard, color: _primaryColor, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.giftName,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Gift ID: ${item.giftId} • Batch: ${item.batchNo}",
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Quantities Grid: Shipped Qty vs Accepted Qty Input
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Shipped Qty (Read Only)
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FD),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Shipped Qty",
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "${item.shippedQty}",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Accepted Qty (Editable)
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _getQtyController(item),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "Accepted Qty *",
                      labelStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade700),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _primaryColor, width: 1.5),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return "Enter quantity";
                      }
                      final parsed = int.tryParse(val.trim());
                      if (parsed == null) {
                        return "Invalid number";
                      }
                      if (parsed < 0) {
                        return "Cannot be negative";
                      }
                      if (parsed > item.shippedQty) {
                        return "Max: ${item.shippedQty}";
                      }
                      return null;
                    },
                    onChanged: (val) {
                      final parsed = int.tryParse(val.trim());
                      if (parsed != null && parsed >= 0 && parsed <= item.shippedQty) {
                        provider.updateAcceptedQty(widget.shipmentId, item.giftId, parsed);
                      }
                      setState(() {});
                    },
                  ),
                ),
              ],
            ),

            // Mandated Reason Field if Accepted Qty < Shipped Qty
            if (isShort) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange.shade900),
                        const SizedBox(width: 6),
                        Text(
                          "Shortage of ${item.shippedQty - acceptedQty} unit(s). Reason is mandatory.",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Quick Reason Suggestions
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildReasonChip(provider, item, "Damaged in transit"),
                        _buildReasonChip(provider, item, "Missing items"),
                        _buildReasonChip(provider, item, "Defective quality"),
                        _buildReasonChip(provider, item, "Incorrect batch"),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Rejection Reason Input
                    TextFormField(
                      controller: _getReasonController(item),
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: "Enter rejection/shortage reason...",
                        hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.orange.shade300),
                        ),
                      ),
                      validator: (val) {
                        if (isShort && (val == null || val.trim().isEmpty)) {
                          return "Please provide a reason for the shortage.";
                        }
                        return null;
                      },
                      onChanged: (val) {
                        provider.updateRejectionReason(widget.shipmentId, item.giftId, val.trim());
                      },
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReasonChip(GiftAcceptanceProvider provider, ShipmentItem item, String reason) {
    final reasonCtrl = _getReasonController(item);
    final isSelected = reasonCtrl.text == reason;

    return InkWell(
      onTap: () {
        setState(() {
          reasonCtrl.text = reason;
        });
        provider.updateRejectionReason(widget.shipmentId, item.giftId, reason);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? _primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _primaryColor : Colors.grey.shade300,
          ),
        ),
        child: Text(
          reason,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : Colors.grey.shade800,
          ),
        ),
      ),
    );
  }
}
