import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DoctorPrioritySubordinateSheet extends StatefulWidget {
  final List<dynamic> subordinates;
  final int? selectedSubId;
  final ValueChanged<int> onSelect;
  final Color primaryColor;

  const DoctorPrioritySubordinateSheet({
    super.key,
    required this.subordinates,
    this.selectedSubId,
    required this.onSelect,
    this.primaryColor = const Color(0xFF4A148C),
  });

  @override
  State<DoctorPrioritySubordinateSheet> createState() =>
      _DoctorPrioritySubordinateSheetState();
}

class _DoctorPrioritySubordinateSheetState
    extends State<DoctorPrioritySubordinateSheet> {
  late List<dynamic> _filteredList;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredList = widget.subordinates;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _filter(String query) {
    setState(() {
      final q = query.toLowerCase().trim();
      if (q.isEmpty) {
        _filteredList = widget.subordinates;
      } else {
        _filteredList = widget.subordinates.where((sub) {
          final name = (sub['name'] ?? sub['full_name'] ?? '').toString().toLowerCase();
          final desig = (sub['designation'] ?? '').toString().toLowerCase();
          final hq = (sub['head_qtr'] ?? '').toString().toLowerCase();
          final code = (sub['employee_code'] ?? '').toString().toLowerCase();
          return name.contains(q) || desig.contains(q) || hq.contains(q) || code.contains(q);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
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
                      "Select Team Member",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _searchCtrl,
                  onChanged: _filter,
                  decoration: InputDecoration(
                    hintText: "Search name, HQ, designation...",
                    hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
                    prefixIcon: Icon(Icons.search, color: widget.primaryColor),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _filteredList.isEmpty
                ? Center(
                    child: Text(
                      "No team members found",
                      style: GoogleFonts.poppins(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _filteredList.length,
                    itemBuilder: (context, index) {
                      final sub = _filteredList[index];
                      final id = int.tryParse(sub['id']?.toString() ?? '0') ?? 0;
                      final bool isSelected = widget.selectedSubId == id;

                      final name = (sub['name'] ?? sub['full_name'] ?? 'Unknown').toString();
                      final desig = (sub['designation'] ?? 'Team Member').toString();
                      final hq = (sub['head_qtr'] ?? '').toString();

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected ? widget.primaryColor : Colors.grey.shade200,
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        color: isSelected ? widget.primaryColor.withOpacity(0.06) : Colors.white,
                        child: ListTile(
                          onTap: () {
                            Navigator.pop(context);
                            widget.onSelect(id);
                          },
                          leading: CircleAvatar(
                            backgroundColor: widget.primaryColor.withOpacity(0.12),
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: TextStyle(
                                color: widget.primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            name,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            hq.isNotEmpty ? '$desig • $hq' : desig,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          trailing: isSelected
                              ? Icon(Icons.check_circle, color: widget.primaryColor)
                              : null,
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
