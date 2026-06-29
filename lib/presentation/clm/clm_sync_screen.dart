import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/clm_models.dart';
import '../../providers/clm_provider.dart';
import '../../providers/data_bank_provider.dart';

class ClmSyncScreen extends StatefulWidget {
  const ClmSyncScreen({super.key});

  @override
  State<ClmSyncScreen> createState() => _ClmSyncScreenState();
}

class _ClmSyncScreenState extends State<ClmSyncScreen> {
  static const _purple = Color(0xFF4A148C);

  bool _wifiOnly = true;
  String? _downloadingBrandId;
  bool _seeding = false;

  Future<void> _clearAndResync(BuildContext context, ClmProvider clmProv) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear & Resync'),
        content: const Text(
          'This will delete all locally cached doctors, brands, products, '
          'chemists, and training materials, then reload everything fresh from the server.\n\n'
          'Unsynced visit data will NOT be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.deepPurple),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear & Sync'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    setState(() => _seeding = true);
    try {
      // Clear CLM + DCR data and resync
      await clmProv.clearAndResync();

      // Clear DataBank data and resync
      if (context.mounted) {
        final dbProv = context.read<DataBankProvider>();
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('auth_token') ?? '';
        if (token.isNotEmpty) {
          await dbProv.clearAndResync(token: token);
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('All data cleared and resynced from server'),
            backgroundColor: Colors.deepPurple.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: Text('Sync & Download',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Consumer<ClmProvider>(
        builder: (_, prov, child) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _buildSyncStatusCard(prov),
              const SizedBox(height: 16),
              _buildSyncActionsCard(prov),
              const SizedBox(height: 16),
              _buildSettingsCard(),
              const SizedBox(height: 20),
              _buildBrandsHeader(prov),
              const SizedBox(height: 10),
              ...prov.allBrands.map((b) => _BrandDownloadCard(
                    brand: b,
                    isDownloading: _downloadingBrandId == b.id.toString(),
                    wifiOnly: _wifiOnly,
                    onDownload: () => _downloadBrand(context, prov, b),
                  )),
              if (prov.allBrands.isEmpty)
                _buildEmptyBrands(),
            ],
          );
        },
      ),
    );
  }

  // ─── Sync Status Card ─────────────────────────────────────────────────────────

  Widget _buildSyncStatusCard(ClmProvider prov) {
    final status = prov.syncStatus;
    final isSyncing = status.state == SyncState.syncing;

    Color stateColor;
    IconData stateIcon;
    String stateLabel;

    switch (status.state) {
      case SyncState.syncing:
        stateColor = Colors.blue.shade600;
        stateIcon = Icons.sync;
        stateLabel = 'Syncing…';
      case SyncState.success:
        stateColor = Colors.green.shade600;
        stateIcon = Icons.check_circle_outline;
        stateLabel = 'Up to date';
      case SyncState.error:
        stateColor = Colors.red.shade600;
        stateIcon = Icons.error_outline;
        stateLabel = 'Sync failed';
      case SyncState.idle:
        stateColor = Colors.grey.shade500;
        stateIcon = Icons.cloud_done_outlined;
        stateLabel = 'Ready';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: stateColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle),
                child: isSyncing
                    ? Padding(
                        padding: const EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: stateColor),
                      )
                    : Icon(stateIcon, color: stateColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stateLabel,
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: stateColor)),
                    if (status.message.isNotEmpty)
                      Text(status.message,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
            ],
          ),
          if (isSyncing && status.progress > 0) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: status.progress,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(stateColor),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 6),
            Text('${(status.progress * 100).toStringAsFixed(0)}%',
                style:
                    TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ],
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              _statBadge(
                  Icons.pending_outlined,
                  '${prov.pendingUploads}',
                  'Pending uploads',
                  Colors.orange.shade600),
              const SizedBox(width: 12),
              _statBadge(
                  Icons.people_alt_outlined,
                  '${prov.filteredDoctors.length}',
                  'Doctors',
                  Colors.blue.shade600),
              const SizedBox(width: 12),
              _statBadge(
                  Icons.medication_outlined,
                  '${prov.allBrands.length}',
                  'Brands',
                  _purple),
            ],
          ),
          if (status.lastSyncAt != null) ...[
            const SizedBox(height: 10),
            Text(
              'Last sync: ${DateFormat('d MMM yy, h:mm a').format(status.lastSyncAt!)}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statBadge(
      IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10)),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(value,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: color)),
            Text(label,
                style: TextStyle(fontSize: 9, color: color),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  // ─── Sync Actions Card ────────────────────────────────────────────────────────

  Widget _buildSyncActionsCard(ClmProvider prov) {
    final isSyncing = prov.syncStatus.state == SyncState.syncing;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sync Actions',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  icon: Icons.cloud_sync_outlined,
                  label: 'Full Sync',
                  subtitle: 'Doctors + brands',
                  color: _purple,
                  loading: isSyncing,
                  onTap: isSyncing ? null : () => prov.syncNow(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _actionButton(
                  icon: Icons.upload_outlined,
                  label: 'Upload',
                  subtitle: 'Pending analytics',
                  color: Colors.teal.shade700,
                  loading: false,
                  onTap: isSyncing
                      ? null
                      : () => prov.analyticsService
                          .getPendingUploadsCount()
                          .then((_) => null),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: _seeding
                  ? const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.cloud_sync_outlined, size: 16),
              label: Text(_seeding ? 'Syncing…' : 'Force Sync from Server',
                  style: const TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.deepPurple.shade400,
                side: BorderSide(color: Colors.deepPurple.shade200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _seeding
                  ? null
                  : () => _clearAndResync(context, prov),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required bool loading,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: onTap == null ? Colors.grey.shade50 : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: onTap == null
                  ? Colors.grey.shade200
                  : color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            loading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: color))
                : Icon(icon, color: onTap == null ? Colors.grey : color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: onTap == null ? Colors.grey : Colors.black87)),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 10, color: Colors.grey.shade500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Settings Card ────────────────────────────────────────────────────────────

  Widget _buildSettingsCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text('Wi-Fi only downloads',
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
        subtitle: Text(
          'Prevent large media files from using mobile data',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
        value: _wifiOnly,
        activeThumbColor: _purple,
        onChanged: (v) => setState(() => _wifiOnly = v),
      ),
    );
  }

  // ─── Brands ───────────────────────────────────────────────────────────────────

  Widget _buildBrandsHeader(ClmProvider prov) {
    final downloaded = prov.allBrands.where((b) => b.isDownloaded).length;
    return Row(
      children: [
        Text('Brand Media',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.black87)),
        const Spacer(),
        Text('$downloaded / ${prov.allBrands.length} downloaded',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
      ],
    );
  }

  Widget _buildEmptyBrands() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Icon(Icons.medication_outlined, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          Text('No brands yet',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
          const SizedBox(height: 4),
          Text('Run a Full Sync to download brand data',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _downloadBrand(
      BuildContext context, ClmProvider prov, ClmBrand brand) async {
    setState(() => _downloadingBrandId = brand.id.toString());
    try {
      await prov.downloadBrand(brand.id, onProgress: (p) {
        if (mounted) setState(() {});
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Download failed: $e'),
              backgroundColor: Colors.red.shade600),
        );
      }
    } finally {
      if (mounted) setState(() => _downloadingBrandId = null);
    }
  }
}

// ─── Brand Download Card ──────────────────────────────────────────────────────

class _BrandDownloadCard extends StatelessWidget {
  final ClmBrand brand;
  final bool isDownloading;
  final bool wifiOnly;
  final VoidCallback onDownload;

  static const _purple = Color(0xFF4A148C);

  const _BrandDownloadCard({
    required this.brand,
    required this.isDownloading,
    required this.wifiOnly,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Brand icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: _purple.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10)),
                child: brand.thumbnailLocalPath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          brand.thumbnailLocalPath!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Icon(
                              Icons.medication_outlined,
                              color: _purple,
                              size: 22),
                        ),
                      )
                    : Icon(Icons.medication_outlined, color: _purple, size: 22),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(brand.name,
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Colors.black87)),
                    Text(brand.therapyArea,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500)),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.photo_library_outlined,
                            size: 11, color: Colors.grey.shade400),
                        const SizedBox(width: 3),
                        Text('${brand.slideCount} slides',
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey.shade500)),
                        const SizedBox(width: 10),
                        _statusBadge(),
                      ],
                    ),
                  ],
                ),
              ),

              // Action button
              _buildActionButton(),
            ],
          ),

          // Progress bar
          if (isDownloading || (brand.downloadProgress > 0 && !brand.isDownloaded)) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: isDownloading
                    ? (brand.downloadProgress > 0 ? brand.downloadProgress : null)
                    : brand.downloadProgress,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(_purple),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isDownloading
                  ? 'Downloading… ${(brand.downloadProgress * 100).toStringAsFixed(0)}%'
                  : 'Paused at ${(brand.downloadProgress * 100).toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusBadge() {
    if (brand.isDownloaded) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(4)),
        child: Text('Downloaded',
            style: TextStyle(
                fontSize: 9,
                color: Colors.green.shade700,
                fontWeight: FontWeight.w600)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(4)),
      child: Text('Not downloaded',
          style: TextStyle(
              fontSize: 9,
              color: Colors.orange.shade700,
              fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildActionButton() {
    if (isDownloading) {
      return const SizedBox(
        width: 36,
        height: 36,
        child: Padding(
          padding: EdgeInsets.all(8),
          child: CircularProgressIndicator(strokeWidth: 2.5, color: _purple),
        ),
      );
    }

    if (brand.isDownloaded) {
      return GestureDetector(
        onTap: onDownload,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8)),
          child: Icon(Icons.refresh, color: Colors.green.shade600, size: 18),
        ),
      );
    }

    return GestureDetector(
      onTap: onDownload,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
            color: _purple.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.download_outlined, color: _purple, size: 18),
      ),
    );
  }
}
