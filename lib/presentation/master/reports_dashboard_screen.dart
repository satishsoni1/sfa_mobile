import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zforce/core/constants/app_colors.dart';
import 'package:zforce/providers/auth_provider.dart';
import 'package:zforce/presentation/reporting/daily_call_report_screen.dart';
import 'package:zforce/presentation/webview/internal_webview_screen.dart';
import 'hierarchy_report_view_screen.dart';

// Enum defined outside so it can be used across files
enum ReportType {
  summary,
  callAvg,
  missedCall,
  tpDeviation,
  jointWork,
  tourPlan,
  pobSummary,
  visitSummary,
}

class ReportsDashboardScreen extends StatelessWidget {
  const ReportsDashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 7 Team report cards
    final List<Map<String, dynamic>> reports = [
      {
        'title': 'Summary',
        'icon': Icons.summarize_outlined,
        'type': ReportType.summary,
      },
      {
        'title': 'Call Average',
        'icon': Icons.data_usage,
        'type': ReportType.callAvg,
      },
      {
        'title': 'Missed Calls',
        'icon': Icons.phone_missed,
        'type': ReportType.missedCall,
      },
      {
        'title': 'TP Deviation',
        'icon': Icons.route_outlined,
        'type': ReportType.tpDeviation,
      },
      {
        'title': 'Joint Work',
        'icon': Icons.handshake_outlined,
        'type': ReportType.jointWork,
      },
      {
        'title': 'Tour Plan (TP)',
        'icon': Icons.calendar_month_outlined,
        'type': ReportType.tourPlan,
      },
      {
        'title': 'Execution Report',
        'icon': Icons.insights_outlined,
        'screen': const CallReportScreen(),
      },
      {
        'title': 'Daily POBS Campaign',
        'icon': Icons.storefront_outlined,
        'type': ReportType.pobSummary,
      },
      {
        'title': 'Doctor Selection',
        'icon': Icons.person_search_outlined,
        'type': ReportType.visitSummary,
      },
      {
        'title': 'Visit Report',
        'icon': Icons.assignment_outlined,
        'external_path': 'visit',
      },
      {
        'title': 'DCR',
        'icon': Icons.description_outlined,
        'external_path': 'dcrview',
      },
      {
        'title': 'MCL Updation report',
        'icon': Icons.list_alt_outlined,
        'external_path': 'mcl-updation',
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8F9),
      appBar: AppBar(
        title: const Text(
          "Team Reports",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Select Report to View",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.0,
                ),
                itemCount: reports.length,
                itemBuilder: (context, index) {
                  return _buildReportCard(context, reports[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(BuildContext context, Map<String, dynamic> report) {
    return InkWell(
      onTap: () {
        if (report['external_path'] != null) {
          _openReportWebLink(
            context,
            report['title']?.toString() ?? '',
            report['external_path']?.toString() ?? '',
          );
          return;
        }
        final Widget? directScreen = report['screen'] as Widget?;
        if (directScreen != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => directScreen),
          );
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => HierarchyReportViewScreen(
              reportTitle: report['title'],
              reportType: report['type'],
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: AppColors.primary.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(report['icon'], size: 32, color: AppColors.primary),
            ),
            const SizedBox(height: 12),
            Text(
              report['title'],
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openReportWebLink(
    BuildContext context,
    String title,
    String path,
  ) async {
    final employeeCode =
        Provider.of<AuthProvider>(context, listen: false).user?.employeeCode.trim();

    if (employeeCode == null || employeeCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Employee code not available.")),
      );
      return;
    }

    // These report links are opened directly with the logged-in user's employee code.
    final url =
        'https://zorvia.globalspace.in/$path?employee_code=${Uri.encodeComponent(employeeCode)}';

    Navigator.pushNamed(
      context,
      InternalWebViewScreen.routeName,
      arguments: InternalWebViewArgs(
        url: url,
        title: title,
      ),
    );
  }
}
