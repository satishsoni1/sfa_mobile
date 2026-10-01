import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zforce/features/pod/config/pod_config.dart';
import 'package:zforce/features/pod/models/upload_record.dart';
import 'package:zforce/features/pod/screens/document_upload_screen.dart';
import 'package:zforce/features/pod/screens/notifications_screen.dart';
import 'package:zforce/features/pod/screens/pod_upload_screen.dart';
import 'package:zforce/features/pod/screens/e_invoice_data_screen.dart';
import 'package:zforce/features/pod/screens/batches_list_screen.dart';
import 'package:zforce/features/pod/services/secondary_sales_background_monitor.dart';
import 'package:zforce/features/pod/services/secondary_sales_data_refresh.dart';
import 'package:zforce/features/pod/services/secondary_sales_upload_history_sync.dart';
import 'package:zforce/features/pod/services/upload_record_store.dart';
import 'package:zforce/features/pod/widgets/modern_ui_components.dart';
import 'package:zforce/features/pod/routes/pod_routes.dart';

class ModernDocumentUploadScreen extends StatefulWidget {
  const ModernDocumentUploadScreen({super.key, this.isActive = true});

  final bool isActive;

  @override
  State<ModernDocumentUploadScreen> createState() =>
      _ModernDocumentUploadScreenState();
}

class _ModernDocumentUploadScreenState extends State<ModernDocumentUploadScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late List<TabInfo> _tabs;
  int _currentIndex = 0;
  final GlobalKey<_PODUploadPageState> _uploadPageKey =
      GlobalKey<_PODUploadPageState>();

  @override
  void initState() {
    super.initState();
    _tabs = [
      TabInfo(
        title: 'Secondary Sales Documents Upload',
        icon: Icons.description,
        color: const Color(0xFF450095),
        page: PODUploadPage(key: _uploadPageKey),
      ),
    ];
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _currentIndex = _tabController.index;
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant ModernDocumentUploadScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _uploadPageKey.currentState?.syncHistory();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: _buildModernAppBar(),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _tabs.map((tab) => tab.page).toList(),
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildModernAppBar() {
    return ModernUIComponents.buildModernAppBar(
      title: 'Document Upload',
      subtitle: 'Upload & Process Documents',
      icon: Icons.cloud_upload,
      color: const Color(0xFF450095),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black),
        tooltip: 'Back',
        onPressed: () {
          Navigator.maybePop(context);
        },
      ),
      actions: const [
        // Notification icon hidden as per requirement
        // Container(
        //   margin: const EdgeInsets.only(right: 16),
        //   child: IconButton(
        //     onPressed: () {
        //       Navigator.pushNamed(context, PodRoutes.notifications);
        //     },
        //     icon: Stack(
        //       children: [
        //         const Icon(Icons.notifications),
        //         Positioned(
        //           right: 0,
        //           top: 0,
        //           child: Container(
        //             width: 8,
        //             height: 8,
        //             decoration: const BoxDecoration(
        //               color: Colors.red,
        //               shape: BoxShape.circle,
        //             ),
        //           ),
        //         ),
        //       ],
        //     ),
        //   ),
        // ),
      ],
    );
  }

  Widget _buildTabBar() {
    return ModernUIComponents.buildTabBar(
      controller: _tabController,
      tabs: _tabs,
      currentIndex: _currentIndex,
    );
  }
}

// POD Upload Page
class PODUploadPage extends StatefulWidget {
  const PODUploadPage({super.key});

  @override
  State<PODUploadPage> createState() => _PODUploadPageState();
}

class _PODUploadPageState extends State<PODUploadPage> {
  List<UploadRecord> _allRecords = const [];
  final SecondarySalesUploadHistorySync _historySync =
      SecondarySalesUploadHistorySync();
  bool _isRefreshing = false;
  Timer? _uiRefreshTimer;

  List<UploadRecord> get _activeBatches =>
      secondarySalesActiveBatches(_allRecords);

  @override
  void initState() {
    super.initState();
    SecondarySalesDataRefresh.tick.addListener(_onDataRefresh);
    syncHistory();
    if (isSecondarySalesUpload) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        SecondarySalesBackgroundMonitor.instance
            .attachMessengerContext(context);
        SecondarySalesBackgroundMonitor.instance.ensureStarted();
      });
    }
  }

  @override
  void dispose() {
    SecondarySalesDataRefresh.tick.removeListener(_onDataRefresh);
    _uiRefreshTimer?.cancel();
    super.dispose();
  }

  void _onDataRefresh() {
    if (!mounted) return;
    _loadRecentUploads();
  }

  void _syncUiRefreshTimer() {
    if (!isSecondarySalesUpload || _activeBatches.isEmpty) {
      _uiRefreshTimer?.cancel();
      _uiRefreshTimer = null;
      return;
    }
    _uiRefreshTimer ??= Timer.periodic(const Duration(seconds: 5), (_) async {
      final local = await UploadRecordStore.instance.loadAll();
      if (!mounted) return;
      setState(() => _allRecords = local);
      _syncUiRefreshTimer();
    });
  }

  Future<void> syncHistory() async {
    final local = await UploadRecordStore.instance.loadAll();
    if (mounted) {
      setState(() {
        _allRecords = local;
      });
      _syncUiRefreshTimer();
    }
    if (!isSecondarySalesUpload) return;
    SecondarySalesBackgroundMonitor.instance.ensureStarted();
    try {
      final synced = await _historySync.synchronize();
      if (!mounted) return;
      setState(() {
        _allRecords = synced;
      });
      _syncUiRefreshTimer();
      SecondarySalesBackgroundMonitor.instance.ensureStarted();
    } catch (_) {
      // Keep the local list already shown. Network failure is not deletion.
    }
  }

  Future<void> _loadRecentUploads() => syncHistory();

  @override
  Widget build(BuildContext context) {
    final active = _activeBatches;
    return RefreshIndicator(
      color: const Color(0xFF450095),
      onRefresh: () async {
        setState(() => _isRefreshing = true);
        await syncHistory();
        if (mounted) setState(() => _isRefreshing = false);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ModernUIComponents.buildUploadCard(
              title: 'Upload Secondary Sales Documents',
              subtitle: 'Select and upload your secondary sales files',
              icon: Icons.upload_file,
              color: const Color(0xFF450095),
              onTap: () async {
                await Navigator.pushNamed(context, PodRoutes.podUpload);
                await _loadRecentUploads();
              },
            ),
            const SizedBox(height: 16),
            ModernUIComponents.buildUploadCard(
              title: 'View Uploaded Batches',
              subtitle: 'See all your uploaded batch records',
              icon: Icons.list_alt,
              color: const Color(0xFF1E88E5),
              onTap: () async {
                await Navigator.pushNamed(context, PodRoutes.batchesList);
                await _loadRecentUploads();
              },
            ),
            if (_isRefreshing) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(
                color: Color(0xFF450095),
                backgroundColor: Color(0xFFE8EEF2),
              ),
            ],
            if (active.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Background Processing',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(height: 12),
              ...active.map(_buildActiveProcessingCard),
            ],
            const SizedBox(height: 16),
            ModernUIComponents.buildInfoCard(
              title: 'Secondary sales Requirements',
              items: [
                'Supported formats: JPG, JPEG, PNG, PDF, XLS, XLSX, TXT, DOC, DOCX, ZIP',
                'Clear, readable document images',
                'Valid delivery confirmation',
                'Proper customer signatures',
                'Date and time stamps',
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveProcessingCard(UploadRecord record) {
    final fileHint = record.fileNames.isNotEmpty
        ? record.fileNames.first
        : 'Secondary Sales statement';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        elevation: 2,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            await Navigator.pushNamed(
              context,
              PodRoutes.uploadStatus,
              arguments: {
                'batchId': record.batchId,
                'totalFiles': record.totalFiles,
                'fileNames': record.fileNames,
                'uploadType': record.uploadType,
                'uploadData': {
                  'batch_id': record.batchId,
                  'batch_db_id': record.batchDbId,
                  'status': record.status,
                  'documents': [
                    for (final id in record.documentIds) {'id': id},
                  ],
                },
              },
            );
            await _loadRecentUploads();
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF450095).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Color(0xFF450095),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Secondary Sales',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Batch #${record.batchId}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        secondarySalesActiveStatusLabel(record.status),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF450095),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        fileHint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// E-Invoice Upload Page
class EInvoiceUploadPage extends StatefulWidget {
  const EInvoiceUploadPage({super.key});

  @override
  State<EInvoiceUploadPage> createState() => _EInvoiceUploadPageState();
}

class _EInvoiceUploadPageState extends State<EInvoiceUploadPage> {
  // Sample QR data for demonstration - in real app this would come from upload process
  final Map<String, dynamic> _sampleQrData = {
    'DocNo': '5EN13986',
    'DocDt': '15/12/2024',
    'DocTyp': 'INV',
    'TotInvVal': '25000.00',
    'Gstin': '27AABCU9603R1ZX',
    'CgstAmt': '2250.00',
    'SgstAmt': '2250.00',
    'IgstAmt': '0.00',
    'TotGstAmt': '4500.00',
    'SellerName': 'Zydus Healthcare Ltd',
    'BuyerName': 'Global Healthcare Solutions',
    'BuyerGstin': '07AABCU9603R1ZX',
    'ItemName': 'Pharmaceutical Products',
    'HsnCode': '3004',
    'Qty': '100',
    'UnitPrice': '250.00',
    'TaxableAmt': '25000.00',
  };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ModernUIComponents.buildPageHeader(
            title: 'E-Invoice Upload',
            subtitle: 'Upload and process E-Invoice documents',
            icon: Icons.receipt_long,
            color: const Color(0xFF8E24AA),
          ),
          const SizedBox(height: 24),
          ModernUIComponents.buildUploadCard(
            title: 'Upload E-Invoice',
            subtitle: 'Select and process E-Invoice files',
            icon: Icons.receipt,
            color: const Color(0xFF8E24AA),
            onTap: () {
              _handleEInvoiceUpload();
            },
          ),
          const SizedBox(height: 16),
          ModernUIComponents.buildUploadCard(
            title: 'View Sample QR Data',
            subtitle: 'Preview scanned QR code information',
            icon: Icons.qr_code_scanner,
            color: const Color(0xFF9C27B0),
            onTap: () {
              _showSampleQrData();
            },
          ),
          const SizedBox(height: 16),
          ModernUIComponents.buildUploadCard(
            title: 'Open Empty E-Invoice Page',
            subtitle: 'Test the new QR scan functionality',
            icon: Icons.add_circle_outline,
            color: const Color(0xFFFF9800),
            onTap: () {
              _showEmptyEInvoicePage();
            },
          ),
          const SizedBox(height: 16),
          ModernUIComponents.buildInfoCard(
            title: 'E-Invoice Features',
            items: [
              'Automatic QR code extraction',
              'Manual QR code scanning',
              'GST validation',
              'Invoice data parsing',
              'Digital signature verification',
            ],
          ),
        ],
      ),
    );
  }

  void _handleEInvoiceUpload() {
    // Navigate to original DocumentUploadScreen with E-Invoice type
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DocumentUploadScreen()),
    ).then((result) {
      // Handle result from DocumentUploadScreen
      if (result != null && result is Map<String, dynamic>) {
        _showQrData(result);
      }
    });
  }

  void _showSampleQrData() {
    _showQrData(_sampleQrData, fileName: 'Sample_E-Invoice_5EN13986.pdf');
  }

  void _showEmptyEInvoicePage() {
    Navigator.pushNamed(
      context,
      PodRoutes.eInvoiceData,
      arguments: {
        'qrData': null, // No QR data - will show scan options
        'fileName': 'Test_E-Invoice.pdf',
        'uploadTime': DateTime.now(),
        'podId': '0',
      },
    );
  }

  void _showQrData(Map<String, dynamic> qrData, {String? fileName}) {
    Navigator.pushNamed(
      context,
      PodRoutes.eInvoiceData,
      arguments: {
        'qrData': qrData,
        'fileName': fileName ?? 'E-Invoice_${qrData['DocNo'] ?? 'Unknown'}.pdf',
        'uploadTime': DateTime.now(),
        'podId': '0',
      },
    );
  }
}

// GRN Upload Page
class GRNUploadPage extends StatefulWidget {
  const GRNUploadPage({super.key});

  @override
  State<GRNUploadPage> createState() => _GRNUploadPageState();
}

class _GRNUploadPageState extends State<GRNUploadPage> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ModernUIComponents.buildPageHeader(
            title: 'GRN Upload',
            subtitle: 'Upload Goods Receipt Notes',
            icon: Icons.inventory,
            color: const Color(0xFF4CAF50),
          ),
          const SizedBox(height: 24),
          ModernUIComponents.buildUploadCard(
            title: 'Upload GRN Documents',
            subtitle: 'Select and upload your GRN files',
            icon: Icons.inventory_2,
            color: const Color(0xFF4CAF50),
            onTap: () {
              // Navigate to original DocumentUploadScreen with GRN type
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DocumentUploadScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          ModernUIComponents.buildInfoCard(
            title: 'GRN Requirements',
            items: [
              'Clear document images',
              'Valid receipt confirmation',
              'Item details and quantities',
              'Supplier information',
            ],
          ),
        ],
      ),
    );
  }
}

// Documents Page
class DocumentsPage extends StatefulWidget {
  const DocumentsPage({super.key});

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ModernUIComponents.buildPageHeader(
            title: 'Document Management',
            subtitle: 'View and manage your uploaded documents',
            icon: Icons.folder_open,
            color: const Color(0xFF2196F3),
          ),
          const SizedBox(height: 24),
          _buildDocumentStats(),
          const SizedBox(height: 16),
          _buildRecentDocuments(),
        ],
      ),
    );
  }

  Widget _buildDocumentStats() {
    return Row(
      children: [
        Expanded(
          child: ModernUIComponents.buildStatCard(
            title: 'Total Documents',
            value: '24',
            icon: Icons.description,
            color: const Color(0xFF2196F3),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ModernUIComponents.buildStatCard(
            title: 'Processed',
            value: '18',
            icon: Icons.check_circle,
            color: const Color(0xFF4CAF50),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ModernUIComponents.buildStatCard(
            title: 'Pending',
            value: '6',
            icon: Icons.pending,
            color: const Color(0xFFFF9800),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentDocuments() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Documents',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 16),
            ModernUIComponents.buildDocumentItem(
              title: 'POD_2024_001.pdf',
              subtitle: 'Uploaded 2 hours ago',
              status: 'Processed',
              statusColor: Colors.green,
            ),
            const Divider(),
            ModernUIComponents.buildDocumentItem(
              title: 'E-Invoice_2024_002.pdf',
              subtitle: 'Uploaded 5 hours ago',
              status: 'Processing',
              statusColor: Colors.orange,
            ),
            const Divider(),
            ModernUIComponents.buildDocumentItem(
              title: 'GRN_2024_003.pdf',
              subtitle: 'Uploaded 1 day ago',
              status: 'Processed',
              statusColor: Colors.green,
            ),
          ],
        ),
      ),
    );
  }
}
