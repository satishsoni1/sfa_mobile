import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TourPlanAnalytics extends StatelessWidget {
  final double coverage; // 0.0 to 1.0
  final int frdCount;
  final int kblCount;
  final int otherCount;
  final int totalVisits;

  const TourPlanAnalytics({
    super.key,
    required this.coverage,
    required this.frdCount,
    required this.kblCount,
    required this.otherCount,
    required this.totalVisits,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Circular Coverage Chart
              _buildCircularCoverage(),
              const SizedBox(width: 24),
              // Main Stats Row
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildQuickStat("Total Visits", "$totalVisits", Icons.directions_walk, Colors.blue),
                    const Divider(height: 24),
                    _buildQuickStat("Total Doctors", "${frdCount + kblCount + otherCount}", Icons.people_outline, Colors.teal),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Category Breakdown Grid
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildCategoryBox("FRD", frdCount, Colors.orange),
              _buildCategoryBox("KBL", kblCount, Colors.purple),
              _buildCategoryBox("Other", otherCount, Colors.lightBlue),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCircularCoverage() {
    return SizedBox(
      width: 100,
      height: 100,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: coverage,
            strokeWidth: 10,
            backgroundColor: Colors.grey.shade100,
            valueColor: const AlwaysStoppedAnimation(Color(0xFF2E3192)),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "${(coverage * 100).toInt()}%",
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2E3192),
                  ),
                ),
                Text(
                  "Coverage",
                  style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(label, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryBox(String label, int count, Color color) {
    return Container(
      width: 95,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            "$count",
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: color),
          ),
          Text(label, style: GoogleFonts.poppins(fontSize: 11, color: color.withOpacity(0.8))),
        ],
      ),
    );
  }
}