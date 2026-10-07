import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/gift_acceptance_provider.dart';
import '../../data/models/gift_shipment_model.dart';
import 'gift_shipment_detail_screen.dart';

class GiftAcceptanceDashboard extends StatefulWidget {
  const GiftAcceptanceDashboard({super.key});

  @override
  State<GiftAcceptanceDashboard> createState() => _GiftAcceptanceDashboardState();
}

class _GiftAcceptanceDashboardState extends State<GiftAcceptanceDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _inventorySearchController = TextEditingController();
  String _inventorySearchQuery = '';

  static const Color _primaryColor = Color(0xFF4A148C);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _inventorySearchController.dispose();
    super.dispose();
  }

  void _loadData() {
    final provider = Provider.of<GiftAcceptanceProvider>(context, listen: false);
    provider.fetchPendingShipments();
    provider.fetchCurrentInventory();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GiftAcceptanceProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        title: Text(
          "Gift Acceptance",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: "Refresh",
            onPressed: _loadData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3.5,
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withValues(alpha: 0.75),
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white),
          unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 14, color: Colors.white.withValues(alpha: 0.75)),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.local_shipping_outlined, size: 19, color: Colors.white),
                  const SizedBox(width: 8),
                  const Text(
                    "Pending Shipments",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  if (provider.pendingShipments.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade700,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "${provider.pendingShipments.length}",
                        style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 19, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    "Current Inventory",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Pending Shipments
          _buildPendingShipmentsTab(provider),

          // Tab 2: Current Inventory
          _buildCurrentInventoryTab(provider),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TAB 1: PENDING SHIPMENTS
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildPendingShipmentsTab(GiftAcceptanceProvider provider) {
    if (provider.isLoading && provider.pendingShipments.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: _primaryColor));
    }

    if (provider.errorMessage != null && provider.pendingShipments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
              const SizedBox(height: 12),
              Text(
                provider.errorMessage!,
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
                onPressed: () => provider.fetchPendingShipments(),
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text("Retry", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    if (provider.pendingShipments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _primaryColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline,
                size: 54,
                color: _primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "No Pending Shipments",
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "All gift shipments have been reviewed and accepted.",
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _primaryColor,
      onRefresh: () async {
        await provider.fetchPendingShipments();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: provider.pendingShipments.length,
        itemBuilder: (context, index) {
          final shipment = provider.pendingShipments[index];
          return _buildShipmentCard(shipment);
        },
      ),
    );
  }

  Widget _buildShipmentCard(GiftShipmentModel shipment) {
    final itemCount = shipment.items.length;
    final totalQty = shipment.items.fold<int>(0, (sum, item) => sum + item.shippedQty);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GiftShipmentDetailScreen(shipmentId: shipment.shipmentId),
            ),
          );

          if (result == true) {
            _loadData();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Shipment ID + Status Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.local_shipping, color: _primaryColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shipment.shipmentId,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            "By: ${shipment.shippedBy}",
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ],
                  ),
                  _buildStatusChip(shipment.status),
                ],
              ),
              const SizedBox(height: 14),

              const Divider(height: 1),
              const SizedBox(height: 12),

              // Details Row: Date, Items count, Total quantity
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        shipment.shippedOn.isNotEmpty ? shipment.shippedOn : "Recent",
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      _buildInfoBadge(Icons.category_outlined, "$itemCount Items"),
                      const SizedBox(width: 8),
                      _buildInfoBadge(Icons.numbers, "$totalQty Qty"),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bg = Colors.amber.shade50;
    Color fg = Colors.amber.shade800;
    String label = "Pending Acceptance";

    if (status == 'accepted') {
      bg = Colors.green.shade50;
      fg = Colors.green.shade800;
      label = "Accepted";
    } else if (status == 'partial') {
      bg = Colors.orange.shade50;
      fg = Colors.orange.shade800;
      label = "Partially Accepted";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildInfoBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: _primaryColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: _primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TAB 2: CURRENT INVENTORY
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildCurrentInventoryTab(GiftAcceptanceProvider provider) {
    if (provider.isLoading && provider.currentInventory.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: _primaryColor));
    }

    if (provider.errorMessage != null && provider.currentInventory.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
              const SizedBox(height: 12),
              Text(
                provider.errorMessage!,
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
                onPressed: () => provider.fetchCurrentInventory(),
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text("Retry", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    final filteredList = _inventorySearchQuery.isEmpty
        ? provider.currentInventory
        : provider.currentInventory.where((item) {
            final q = _inventorySearchQuery.toLowerCase();
            return item.giftName.toLowerCase().contains(q) ||
                item.batchNo.toLowerCase().contains(q) ||
                item.giftId.toLowerCase().contains(q);
          }).toList();

    final totalStockQty = provider.currentInventory.fold<int>(0, (sum, i) => sum + i.quantity);

    return RefreshIndicator(
      color: _primaryColor,
      onRefresh: () async {
        await provider.fetchCurrentInventory();
      },
      child: Column(
        children: [
          // Inventory Header Stats & Search
          Container(
            color: Colors.white,
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
                          "Total Stock",
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        Text(
                          "$totalStockQty Units",
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _primaryColor,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "${provider.currentInventory.length} Gift Types",
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.teal.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Search Bar
                TextField(
                  controller: _inventorySearchController,
                  onChanged: (val) => setState(() => _inventorySearchQuery = val.trim()),
                  decoration: InputDecoration(
                    hintText: "Search gifts by name, ID or batch...",
                    hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade400),
                    prefixIcon: const Icon(Icons.search, size: 20, color: _primaryColor),
                    suffixIcon: _inventorySearchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _inventorySearchController.clear();
                              setState(() => _inventorySearchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF8F9FD),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Inventory List
          Expanded(
            child: filteredList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 10),
                        Text(
                          _inventorySearchQuery.isEmpty
                              ? "No inventory in stock"
                              : "No gifts match your search",
                          style: GoogleFonts.poppins(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final item = filteredList[index];
                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: _primaryColor.withValues(alpha: 0.08),
                                child: const Icon(Icons.card_giftcard, color: _primaryColor, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.giftName,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Text(
                                          "ID: ${item.giftId}",
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          "• Batch: ${item.batchNo}",
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      "${item.quantity}",
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade900,
                                      ),
                                    ),
                                    Text(
                                      "Available",
                                      style: TextStyle(fontSize: 10, color: Colors.blue.shade700),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
