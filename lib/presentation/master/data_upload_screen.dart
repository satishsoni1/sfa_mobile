import 'package:flutter/foundation.dart'; // Needed for web bytes
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zforce/data/services/api_service.dart';
import 'package:zforce/presentation/master/view_master_data_screen.dart';

class DataUploadScreen extends StatefulWidget {
  final bool isManager; // Pass true if the logged-in user is a manager

  // Note: currentUserId is removed because the API safely uses the Token ID

  const DataUploadScreen({super.key, required this.isManager});

  @override
  State<DataUploadScreen> createState() => _DataUploadScreenState();
}

class _DataUploadScreenState extends State<DataUploadScreen> {
  // Using PlatformFile instead of File for Web + Mobile compatibility
  PlatformFile? _doctorFile;
  PlatformFile? _chemistFile;
  String? _selectedSubordinate;
  bool _isUploading = false;

  // --- Dynamic subordinates state ---
  List<Map<String, String>> _subordinates = [];
  bool _isLoadingSubordinates = false;

  @override
  void initState() {
    super.initState();
    // Fetch subordinates as soon as the screen opens if the user is a manager
    if (widget.isManager) {
      _fetchSubordinates();
    }
  }

  // Fetch Subordinates Logic
  Future<void> _fetchSubordinates() async {
    setState(() => _isLoadingSubordinates = true);
    try {
      final subs = await ApiService().getSubordinatesUpload();
      setState(() {
        _subordinates = subs;
        _isLoadingSubordinates = false;
      });
    } catch (e) {
      setState(() => _isLoadingSubordinates = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load subordinates: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickFile(bool isDoctor) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
      withData: true, // IMPORTANT: Required for web to get file bytes
    );

    if (result != null) {
      setState(() {
        if (isDoctor) {
          _doctorFile = result.files.single; // Store the PlatformFile
        } else {
          _chemistFile = result.files.single; // Store the PlatformFile
        }
      });
    }
  }

  // --- Actual Download Logic ---
  Future<void> _downloadSample(String fileType) async {
    // Base URL of your uploads folder
    const String baseUrl = "https://zorvia.globalspace.in/assets/uploads";

    // Set the exact filename based on the type requested
    String fileName = "";
    if (fileType == 'doctor_master') {
      fileName =
          "ZF1_Doctor_Master_Format.xlsx"; // Ensure this exactly matches server filename
    } else if (fileType == 'chemist_master') {
      fileName =
          "TOP_CHEMIST_FORMAT.xlsx"; // Ensure this exactly matches server filename
    }

    final Uri url = Uri.parse("$baseUrl/$fileName");

    try {
      // Launch in an external browser to trigger the native download behavior
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw "Could not launch $url";
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open download link: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadData() async {
    if (_doctorFile == null && _chemistFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one file to upload'),
        ),
      );
      return;
    }

    // Only enforce subordinate selection if they actually HAVE subordinates
    if (widget.isManager &&
        _subordinates.isNotEmpty &&
        _selectedSubordinate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a subordinate to assign this data'),
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    // If manager picked someone, use that. Otherwise, send empty string.
    String assignedTo = _selectedSubordinate ?? '';

    try {
      final response = await ApiService().uploadMasterData(
        doctorFile: _doctorFile,
        chemistFile: _chemistFile,
        assignedTo: assignedTo,
      );

      setState(() => _isUploading = false);

      int docCount = response['data']['doctors_added'] ?? 0;
      int chemCount = response['data']['chemists_added'] ?? 0;

      _showUploadSummary(doctorsAdded: docCount, chemistsAdded: chemCount);

      setState(() {
        _doctorFile = null;
        _chemistFile = null;
        _selectedSubordinate = null;
      });
    } catch (e) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showUploadSummary({
    required int doctorsAdded,
    required int chemistsAdded,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 50),
            const SizedBox(height: 10),
            Text(
              "Upload Successful",
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_doctorFile != null)
              ListTile(
                leading: const Icon(
                  Icons.local_hospital,
                  color: Color(0xFF4A148C),
                ),
                title: Text(
                  "Doctors Master Data",
                  style: GoogleFonts.poppins(),
                ),
                trailing: Text(
                  "+$doctorsAdded",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            if (_chemistFile != null)
              ListTile(
                leading: const Icon(Icons.storefront, color: Color(0xFF4A148C)),
                title: Text(
                  "Chemist Master Data",
                  style: GoogleFonts.poppins(),
                ),
                trailing: Text(
                  "+$chemistsAdded",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ViewMasterDataScreen(
                    assignedToId: _selectedSubordinate ?? '',
                  ),
                ),
              );
            },
            child: Text(
              "View Uploaded Data",
              style: GoogleFonts.poppins(color: const Color(0xFF4A148C)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A148C),
            ),
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Done",
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper to get selected subordinate name ---
  String _getSelectedSubordinateName() {
    if (_selectedSubordinate == null)
      return "Tap to search & select subordinate";
    final sub = _subordinates.firstWhere(
      (s) => s['id'] == _selectedSubordinate,
      orElse: () => {'name': 'Unknown'},
    );
    return sub['name'] ?? 'Unknown';
  }

  // --- Open Searchable Bottom Sheet ---
  void _showSubordinatePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SubordinateSearchSheet(
        subordinates: _subordinates,
        onSelect: (String id) {
          setState(() {
            _selectedSubordinate = id;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: Text(
          'Data Upload',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF4A148C),
        elevation: 0,
        // --- App Bar Button for quick access to view data ---
        actions: [
          IconButton(
            tooltip: "View Uploaded Data",
            icon: const Icon(Icons.list_alt_rounded, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ViewMasterDataScreen(
                    assignedToId: _selectedSubordinate ?? '',
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: _isUploading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF4A148C)),
                  const SizedBox(height: 16),
                  Text(
                    "Parsing Excel files & Validating...",
                    style: GoogleFonts.poppins(color: Colors.grey.shade700),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // INSTRUCTIONS BANNER
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Instructions:\n1. Fill in your data without altering the headers.\n3. Upload the completed .xlsx or .csv file.",
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.blue.shade900,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- Dynamic Manager Assignment Section ---
                  // Shows loading OR dropdown ONLY if subordinates exist. Hides if empty.
                  if (widget.isManager &&
                      (_isLoadingSubordinates || _subordinates.isNotEmpty)) ...[
                    Text(
                      "Assign Data To:",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _isLoadingSubordinates
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF4A148C),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  "Loading subordinates...",
                                  style: GoogleFonts.poppins(
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : InkWell(
                            onTap: _showSubordinatePicker,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _selectedSubordinate != null
                                      ? Colors.green
                                      : Colors.grey.shade300,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      _getSelectedSubordinateName(),
                                      style: GoogleFonts.poppins(
                                        color: _selectedSubordinate == null
                                            ? Colors.grey.shade600
                                            : Colors.black87,
                                        fontWeight: _selectedSubordinate != null
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.search,
                                    color: Color(0xFF4A148C),
                                  ),
                                ],
                              ),
                            ),
                          ),
                    const SizedBox(height: 24),
                  ],

                  // Doctor Master Upload Card
                  _buildUploadCard(
                    title: "Doctor Master",
                    icon: Icons.local_hospital,
                    selectedFile: _doctorFile,
                    onTap: () => _pickFile(true),
                    onClear: () => setState(() => _doctorFile = null),
                    onDownloadSample: () => _downloadSample('doctor_master'),
                  ),
                  const SizedBox(height: 16),

                  // Chemist Master Upload Card
                  _buildUploadCard(
                    title: "Chemist Master",
                    icon: Icons.storefront,
                    selectedFile: _chemistFile,
                    onTap: () => _pickFile(false),
                    onClear: () => setState(() => _chemistFile = null),
                    onDownloadSample: () => _downloadSample('chemist_master'),
                  ),
                  const SizedBox(height: 40),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A148C),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.cloud_upload, color: Colors.white),
                      label: Text(
                        "UPLOAD TO SERVER",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      onPressed: _uploadData,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- Secondary View Data Button ---
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: Color(0xFF4A148C),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(
                        Icons.folder_shared,
                        color: Color(0xFF4A148C),
                      ),
                      label: Text(
                        "VIEW UPLOADED DATA",
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF4A148C),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ViewMasterDataScreen(
                              assignedToId: _selectedSubordinate ?? '',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  // Upload Card Widget
  Widget _buildUploadCard({
    required String title,
    required IconData icon,
    required PlatformFile? selectedFile, // Using PlatformFile
    required VoidCallback onTap,
    required VoidCallback onClear,
    required VoidCallback onDownloadSample,
  }) {
    bool hasFile = selectedFile != null;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasFile ? Colors.green : Colors.grey.shade200,
          width: hasFile ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              onTap: hasFile ? null : onTap,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      icon,
                      size: 40,
                      color: hasFile ? Colors.green : const Color(0xFF4A148C),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (hasFile) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.insert_drive_file,
                              size: 16,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                selectedFile
                                    .name, // Displaying PlatformFile.name safely
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.red,
                                size: 20,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: onClear,
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Text(
                        "Tap to select .xlsx or .csv file",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (!hasFile) ...[
            // Divider(height: 1, color: Colors.grey.shade200),
            // InkWell(
            //   borderRadius: const BorderRadius.vertical(
            //     bottom: Radius.circular(16),
            //   ),
            //   onTap: onDownloadSample,
            //   child: Container(
            //     width: double.infinity,
            //     padding: const EdgeInsets.symmetric(vertical: 12),
            //     decoration: BoxDecoration(
            //       color: Colors.grey.shade50,
            //       borderRadius: const BorderRadius.vertical(
            //         bottom: Radius.circular(16),
            //       ),
            //     ),
            //     child: Row(
            //       mainAxisAlignment: MainAxisAlignment.center,
            //       children: [
            //         Icon(Icons.download, size: 16, color: Colors.blue.shade700),
            //         const SizedBox(width: 6),
            //         Text(
            //           "Download Sample Format",
            //           style: GoogleFonts.poppins(
            //             fontSize: 13,
            //             fontWeight: FontWeight.w600,
            //             color: Colors.blue.shade700,
            //           ),
            //         ),
            //       ],
            //     ),
            //   ),
            // ),
          ],
        ],
      ),
    );
  }
}

// =========================================================================
// CUSTOM SEARCHABLE BOTTOM SHEET
// =========================================================================
class _SubordinateSearchSheet extends StatefulWidget {
  final List<Map<String, String>> subordinates;
  final Function(String) onSelect;

  const _SubordinateSearchSheet({
    required this.subordinates,
    required this.onSelect,
  });

  @override
  State<_SubordinateSearchSheet> createState() =>
      _SubordinateSearchSheetState();
}

class _SubordinateSearchSheetState extends State<_SubordinateSearchSheet> {
  String _searchQuery = "";
  late List<Map<String, String>> _filteredList;

  @override
  void initState() {
    super.initState();
    _filteredList = widget.subordinates;
  }

  void _filter(String query) {
    setState(() {
      _searchQuery = query;
      _filteredList = widget.subordinates.where((s) {
        final name = s['name']?.toLowerCase() ?? '';
        return name.contains(query.toLowerCase());
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header & Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              children: [
                Container(
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Search Subordinate",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  onChanged: _filter,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: "Type name to search...",
                    hintStyle: GoogleFonts.poppins(color: Colors.grey),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFF4A148C),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // List View
          Expanded(
            child: _filteredList.isEmpty
                ? Center(
                    child: Text(
                      "No subordinates found",
                      style: GoogleFonts.poppins(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredList.length,
                    itemBuilder: (context, index) {
                      final sub = _filteredList[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(
                            0xFF4A148C,
                          ).withOpacity(0.1),
                          child: const Icon(
                            Icons.person,
                            color: Color(0xFF4A148C),
                          ),
                        ),
                        title: Text(
                          sub['name']!,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        onTap: () {
                          widget.onSelect(sub['id']!);
                          Navigator.pop(context); // Close sheet after selection
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
