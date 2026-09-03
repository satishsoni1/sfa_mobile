import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../data/services/api_service.dart';

class TpDeviationFormScreen extends StatefulWidget {
  const TpDeviationFormScreen({super.key});

  @override
  State<TpDeviationFormScreen> createState() => _TpDeviationFormScreenState();
}

class _TpDeviationFormScreenState extends State<TpDeviationFormScreen> {
  DateTime? _selectedDate;
  String _currentRoute = '';
  List<dynamic> _allRoutes = [];
  List<dynamic> _selectedNewRoutes = [];
  final TextEditingController _remarkController = TextEditingController();
  
  bool _isLoading = false;
  bool _isSubmitting = false;
  final ApiService _api = ApiService();

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _fetchRoutes();
    if (mounted) await _fetchCurrentPlan(_selectedDate!);
  }
  
  @override
  void dispose() {
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _fetchRoutes() async {
    setState(() => _isLoading = true);
    try {
      final routes = await _api.fetchUserAreas();
      if (mounted) {
        setState(() {
          _allRoutes = routes;
        });
      }
    } catch (e) {
      debugPrint('Error fetching routes: ');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchCurrentPlan(DateTime date) async {
    setState(() => _isLoading = true);
    try {
      final response = await _api.getMonthlyAreaPlans(DateTime(date.year, date.month, 1));
      
      String foundRoute = 'No approved plan found for this date.';
      if (response['plans'] != null && response['plans'] is Map) {
        final plans = response['plans'] as Map;
        final dateKey = DateFormat('yyyy-MM-dd').format(date);
        
        if (plans.containsKey(dateKey)) {
          final p = plans[dateKey];
          if (p['areas'] is Map) {
            foundRoute = (p['areas'] as Map).values.join('\n');
          } else if (p['areas'] is List) {
            foundRoute = (p['areas'] as List).join('\n');
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _currentRoute = foundRoute;
        });
      }
    } catch (e) {
      debugPrint('Error fetching current plan: ');
      if (mounted) setState(() => _currentRoute = 'Error loading plan.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(DateTime.now().year, DateTime.now().month - 1, 1),
      lastDate: DateTime(DateTime.now().year, DateTime.now().month + 2, 0),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _currentRoute = 'Loading current plan...';
        _selectedNewRoutes = [];
      });
      _fetchCurrentPlan(picked);
    }
  }

  void _showSingleSelectSheet() {
    dynamic tempSelected = _selectedNewRoutes.isNotEmpty ? _selectedNewRoutes.first : null;
    String searchQuery = '';
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setSheet) {
          final filteredItems = _allRoutes.where((item) {
            final name = item['name']?.toString() ?? 'Unknown';
            final val = item['dr_count'] != null
                ? '$name (Tagged doctor\'s: ${item['dr_count']})'
                : name;
            return val.toLowerCase().contains(searchQuery.toLowerCase());
          }).toList();

          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            expand: false,
            builder: (_, scrollController) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Select Requested Route', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search route...',
                        prefixIcon: const Icon(Icons.search),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      onChanged: (val) => setSheet(() => searchQuery = val),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: filteredItems.isEmpty
                        ? Center(child: Text('No routes found', style: GoogleFonts.poppins(color: Colors.grey.shade500)))
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: filteredItems.length,
                            itemBuilder: (_, index) {
                              final item = filteredItems[index];
                              final rawName = item['name']?.toString() ?? 'Unknown';
                              final drCount = item['dr_count'];
                              final displayName = drCount != null
                                  ? '$rawName (Tagged doctor\'s: $drCount)'
                                  : rawName;
                                  
                              final isSelected = tempSelected != null && 
                                  tempSelected['id']?.toString() == item['id']?.toString();

                              return RadioListTile<String>(
                                value: item['id']?.toString() ?? '',
                                groupValue: tempSelected?['id']?.toString(),
                                activeColor: AppColors.primary,
                                title: Text(
                                  displayName, 
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                                onChanged: (val) {
                                  setSheet(() {
                                    tempSelected = item;
                                  });
                                },
                              );
                            },
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: tempSelected == null
                            ? null
                            : () {
                                setState(() {
                                  _selectedNewRoutes = [tempSelected];
                                });
                                Navigator.pop(ctx);
                              },
                        child: Text('Confirm', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        });
      },
    );
  }

  Future<void> _submitRequest() async {
    if (_selectedDate == null) {
      _showSnack('Please select a date first.');
      return;
    }
    if (_selectedNewRoutes.isEmpty) {
      _showSnack('Please select a new route.');
      return;
    }
    if (_remarkController.text.trim().isEmpty) {
      _showSnack('Please enter a reason for deviation.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final payload = {
        'date': DateFormat('yyyy-MM-dd').format(_selectedDate!),
        'old_route': _currentRoute,
        'new_routes': _selectedNewRoutes.map((r) => r['id']).toList(),
        'user_remark': _remarkController.text.trim(),
      };
      
      final success = await _api.submitTpDeviationRequest(payload);
      if (success) {
        if (mounted) {
          _showSnack('Deviation request submitted successfully!');
          Navigator.pop(context, true); // return true to refresh history
        }
      } else {
        if (mounted) _showSnack('Failed to submit request.');
      }
    } catch (e) {
      if (mounted) _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, style: GoogleFonts.poppins())));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text('New Deviation Request', style: GoogleFonts.poppins(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _isLoading && _allRoutes.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Date Selection
                  _buildSectionTitle('Date'),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Colors.grey, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          _selectedDate == null ? '' : DateFormat('dd MMMM yyyy').format(_selectedDate!),
                          style: GoogleFonts.poppins(fontSize: 14, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Current Route
                  _buildSectionTitle('Current Planned Route'),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: _selectedDate == null
                        ? Text(
                            'Select date to view current route',
                            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
                          )
                        : _isLoading 
                            ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                            : Text(
                                _currentRoute.isEmpty ? 'No approved plan found for this date.' : _currentRoute,
                                style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
                              ),
                  ),
                  const SizedBox(height: 24),

                  // 3. New Route Selection
                  _buildSectionTitle('Requested New Route'),
                  InkWell(
                    onTap: _showSingleSelectSheet,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.alt_route, color: AppColors.primary, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Builder(
                              builder: (_) {
                                if (_selectedNewRoutes.isEmpty) {
                                  return Text(
                                    'Tap to select requested route',
                                    style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
                                  );
                                }
                                final r = _selectedNewRoutes.first;
                                final name = r['name']?.toString() ?? '';
                                final drCount = r['dr_count'];
                                final display = drCount != null ? '$name (Tagged doctor\'s: $drCount)' : name;
                                return Text(
                                  display,
                                  style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500),
                                );
                              },
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 4. Remark
                  _buildSectionTitle('Reason for Deviation'),
                  TextField(
                    controller: _remarkController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Enter a detailed reason for this deviation...',
                      hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isSubmitting ? null : _submitRequest,
                      child: _isSubmitting 
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text('Submit Request', style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
      ),
    );
  }
}
