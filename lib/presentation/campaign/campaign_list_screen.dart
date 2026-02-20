import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'campaign_planning_screen.dart';

class CampaignListScreen extends StatefulWidget {
  const CampaignListScreen({super.key});

  @override
  State<CampaignListScreen> createState() => _CampaignListScreenState();
}

class _CampaignListScreenState extends State<CampaignListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;

  final Color _primaryColor = const Color(0xFF4A148C);
  final Color _bgColor = const Color(0xFFF4F6F9);

  // MOCK DATA: Replace with ApiService call
  final List<Map<String, dynamic>> _campaigns = [
    {
      "id": 101,
      "name": "Monsoon Cardio Drive",
      "products": "CardioMax, BP-Clear",
      "start_date": "2026-06-01",
      "end_date": "2026-06-30",
      "target_doctors": 2,
      "visits_per_doctor": 2,
      "status": "Action Required", // Needs planning
      "progress": 0.0,
    },
    {
      "id": 102,
      "name": "Pedia Care Q2 Focus",
      "products": "KidVita Syrup",
      "start_date": "2026-05-15",
      "end_date": "2026-07-15",
      "target_doctors": 10,
      "visits_per_doctor": 1,
      "status": "Active", // Planned and executing
      "progress": 0.6, // 60% complete
    },
    {
      "id": 103,
      "name": "Derma Launch Promo",
      "products": "GlowCream",
      "start_date": "2026-01-01",
      "end_date": "2026-01-31",
      "target_doctors": 5,
      "visits_per_doctor": 1,
      "status": "Completed",
      "progress": 1.0,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        elevation: 0,
        title: Text(
          "Campaign Hub",
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          unselectedLabelStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.normal,
          ),
          tabs: const [
            Tab(text: "Action Required"),
            Tab(text: "Active"),
            Tab(text: "Completed"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCampaignList("Action Required"),
          _buildCampaignList("Active"),
          _buildCampaignList("Completed"),
        ],
      ),
    );
  }

  Widget _buildCampaignList(String statusFilter) {
    final filteredList = _campaigns
        .where((c) => c['status'] == statusFilter)
        .toList();

    if (filteredList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.campaign_outlined,
              size: 60,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              "No $statusFilter campaigns",
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredList.length,
      itemBuilder: (context, index) {
        final campaign = filteredList[index];
        final bool isActionReq = statusFilter == "Action Required";
        final bool isActive = statusFilter == "Active";

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isActionReq
                  ? Colors.redAccent.shade100
                  : Colors.grey.shade200,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              if (isActionReq) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        CampaignPlanningScreen(campaignData: campaign),
                  ),
                ).then((_) {
                  // TODO: Refresh campaigns via API on return
                });
              } else {
                // TODO: Navigate to Campaign Analytics/Progress Detail Screen
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          campaign['name'],
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (isActionReq)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "Needs Plan",
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Products: ${campaign['products']}",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: _primaryColor,
                    ),
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_month,
                        size: 14,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "${DateFormat('dd MMM').format(DateTime.parse(campaign['start_date']))} - ${DateFormat('dd MMM yyyy').format(DateTime.parse(campaign['end_date']))}",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMetricBox(
                        "Target Dr.",
                        campaign['target_doctors'].toString(),
                        Icons.people,
                      ),
                      _buildMetricBox(
                        "Visits/Dr.",
                        campaign['visits_per_doctor'].toString(),
                        Icons.repeat,
                      ),
                    ],
                  ),
                  if (isActive) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: campaign['progress'],
                            backgroundColor: Colors.grey.shade200,
                            valueColor: const AlwaysStoppedAnimation(
                              Colors.green,
                            ),
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          "${(campaign['progress'] * 100).toInt()}%",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ] else if (isActionReq) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CampaignPlanningScreen(
                                campaignData: campaign,
                              ),
                            ),
                          );
                        },
                        child: Text(
                          "CREATE CAMPAIGN PLAN",
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetricBox(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade500),
        const SizedBox(width: 4),
        Text(
          "$label: ",
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}
