import 'package:flutter/material.dart';
import 'package:zforce/features/pod/models/statement_detail_model.dart';

// ============================================================
// DoctorMappingBanner — modern pill-style stats row
// ============================================================

class DoctorMappingBanner extends StatelessWidget {
  final StatementMappingSummary summary;
  const DoctorMappingBanner({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final stats = [
      _Stat(
        icon: Icons.person_rounded,
        label: 'Doctors Mapped',
        value: '${summary.doctorsMapped}',
        iconColor: const Color(0xFF2196F3),
        highlight: false,
      ),
      _Stat(
        icon: Icons.inventory_2_outlined,
        label: 'Products Mapped',
        value: '${summary.productsMapped}',
        iconColor: const Color(0xFF4CAF50),
        highlight: false,
      ),
      _Stat(
        icon: Icons.pending_actions_rounded,
        label: 'Pending Products',
        value: '${summary.pendingProducts}',
        iconColor: const Color(0xFFFF9800),
        highlight: summary.pendingProducts > 0,
      ),
      _Stat(
        icon: Icons.assignment_turned_in_outlined,
        label: 'Allocated Qty',
        value: summary.allocatedQty.toStringAsFixed(2),
        iconColor: const Color(0xFF009688),
        highlight: false,
      ),
      _Stat(
        icon: Icons.hourglass_bottom_rounded,
        label: 'Remaining Qty',
        value: summary.remainingQty.toStringAsFixed(2),
        iconColor: const Color(0xFF9C27B0),
        highlight: false,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFF450095).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.medical_services_outlined,
                    color: Color(0xFF450095), size: 15),
              ),
              const SizedBox(width: 8),
              const Text(
                'Doctor Mapping Summary',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                    letterSpacing: -0.2),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Row(
              children: stats.asMap().entries.map((e) {
                return Row(children: [
                  _StatPill(stat: e.value),
                  if (e.key < stats.length - 1)
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.grey.shade100,
                      margin: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                ]);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;
  final bool highlight;
  const _Stat({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
    required this.highlight,
  });
}

class _StatPill extends StatelessWidget {
  final _Stat stat;
  const _StatPill({required this.stat});

  @override
  Widget build(BuildContext context) {
    final valueColor =
        stat.highlight ? const Color(0xFFE65100) : Colors.black87;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: stat.iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(stat.icon, color: stat.iconColor, size: 15),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(stat.label,
                style: TextStyle(fontSize: 9, color: Colors.grey.shade500)),
            const SizedBox(height: 2),
            Text(
              stat.value,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: valueColor,
                  letterSpacing: -0.5),
            ),
          ],
        ),
      ],
    );
  }
}
