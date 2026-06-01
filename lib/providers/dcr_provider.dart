import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../data/models/dcr_models.dart';
import '../data/models/clm_models.dart';
import '../data/services/clm_database_service.dart';

class DcrProvider extends ChangeNotifier {
  final ClmDatabaseService _db = ClmDatabaseService();

  // ─── Master data ──────────────────────────────────────────────────────────────
  List<DcrProduct> _products = [];
  List<DcrChemist> _chemists = [];
  List<DcrEmployee> _employees = [];
  List<ClmBrand> _brands = [];
  List<ClmDoctor> _doctors = [];

  List<DcrProduct> get products => _products;
  List<DcrChemist> get chemists => _chemists;
  List<DcrEmployee> get employees => _employees;
  List<ClmBrand> get brands => _brands;
  List<ClmDoctor> get doctors => _doctors;

  // ─── Today's DCR ─────────────────────────────────────────────────────────────
  DcrDaySummary _todaySummary = DcrDaySummary(date: '');
  DcrDaySummary get todaySummary => _todaySummary;

  bool _loading = false;
  bool get loading => _loading;

  String get todayDateKey => DateFormat('yyyy-MM-dd').format(DateTime.now());

  // ─── Init ─────────────────────────────────────────────────────────────────────

  Future<void> init() async {
    _loading = true;
    notifyListeners();
    try {
      await Future.wait([
        _loadMasterData(),
        loadTodaySummary(),
      ]);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _loadMasterData() async {
    _products = await _db.getAllDcrProducts();
    _chemists = await _db.getAllDcrChemists();
    _employees = await _db.getAllDcrEmployees();
    _brands = await _db.getAllBrands();
    _doctors = await _db.getAllDoctors();
  }

  Future<void> loadTodaySummary() async {
    final date = todayDateKey;
    final doctorVisits = await _db.getDcrDoctorVisitsForDate(date);
    final chemistVisits = await _db.getDcrChemistVisitsForDate(date);
    final totalSamples = await _db.getTotalSamplesForDate(date);
    _todaySummary = DcrDaySummary(
      date: date,
      doctorVisits: doctorVisits,
      chemistVisits: chemistVisits,
      totalSamples: totalSamples,
    );
    notifyListeners();
  }

  // ─── Doctor Visits ────────────────────────────────────────────────────────────

  Future<int> saveDoctorVisit(DcrDoctorVisit visit) async {
    int id;
    if (visit.id == null) {
      id = await _db.insertDcrDoctorVisit(visit);
    } else {
      await _db.updateDcrDoctorVisit(visit);
      id = visit.id!;
    }
    await loadTodaySummary();
    return id;
  }

  Future<void> deleteDoctorVisit(int id) async {
    await _db.deleteDcrDoctorVisit(id);
    await loadTodaySummary();
  }

  Future<DcrDoctorVisit?> getDoctorVisitForSession(String sessionId) =>
      _db.getDcrDoctorVisitForSession(sessionId);

  // ─── Visit Employees ──────────────────────────────────────────────────────────

  Future<List<DcrVisitEmployee>> getVisitEmployees(int visitId) =>
      _db.getDcrVisitEmployees(visitId);

  Future<void> setVisitEmployees(
      int visitId, List<DcrEmployee> selected) async {
    await _db.clearDcrVisitEmployees(visitId);
    for (final e in selected) {
      await _db.addDcrVisitEmployee(DcrVisitEmployee(
        visitId: visitId,
        employeeId: e.id,
        employeeCode: e.employeeCode,
        employeeName: e.name,
      ));
    }
  }

  // ─── Sample Items ─────────────────────────────────────────────────────────────

  Future<List<DcrSampleItem>> getSampleItems(int visitId) =>
      _db.getDcrSampleItemsForVisit(visitId);

  Future<void> saveSampleItems(
      int visitId, List<DcrSampleItem> items) async {
    await _db.clearDcrSampleItems(visitId);
    for (final item in items.where((i) => i.quantity > 0)) {
      final toSave = DcrSampleItem(
        visitId: visitId,
        productId: item.productId,
        productName: item.productName,
        quantity: item.quantity,
        allocationLimit: item.allocationLimit,
        stockAvailable: item.stockAvailable,
      );
      await _db.insertDcrSampleItem(toSave);
      // Deduct from product stock
      final product = _products.firstWhere(
        (p) => p.id == item.productId,
        orElse: () => DcrProduct(id: item.productId, name: ''),
      );
      final newStock = (product.stockAvailable - item.quantity).clamp(0, 9999);
      await _db.updateDcrProductStock(item.productId, newStock);
      product.stockAvailable = newStock;
    }
    notifyListeners();
  }

  // ─── Signatures ───────────────────────────────────────────────────────────────

  Future<DcrVisitSignature?> getSignature(int visitId) =>
      _db.getDcrVisitSignature(visitId);

  Future<void> saveSignature(DcrVisitSignature sig) =>
      _db.saveDcrVisitSignature(sig);

  Future<void> deleteSignature(int visitId) =>
      _db.deleteDcrVisitSignature(visitId);

  // ─── Chemist Visits ───────────────────────────────────────────────────────────

  Future<int> saveChemistVisit(DcrChemistVisit visit) async {
    int id;
    if (visit.id == null) {
      id = await _db.insertDcrChemistVisit(visit);
    } else {
      await _db.updateDcrChemistVisit(visit);
      id = visit.id!;
    }
    await loadTodaySummary();
    return id;
  }

  Future<void> deleteChemistVisit(int id) async {
    await _db.deleteDcrChemistVisit(id);
    await loadTodaySummary();
  }

  // ─── Chemist Employees ────────────────────────────────────────────────────────

  Future<List<DcrChemistEmployee>> getChemistEmployees(int chemistVisitId) =>
      _db.getDcrChemistEmployees(chemistVisitId);

  Future<void> setChemistEmployees(
      int chemistVisitId, List<DcrEmployee> selected) async {
    await _db.clearDcrChemistEmployees(chemistVisitId);
    for (final e in selected) {
      await _db.addDcrChemistEmployee(DcrChemistEmployee(
        chemistVisitId: chemistVisitId,
        employeeId: e.id,
        employeeCode: e.employeeCode,
        employeeName: e.name,
      ));
    }
  }

  // ─── RCPA ─────────────────────────────────────────────────────────────────────

  Future<List<DcrRcpaEntry>> getRcpaEntries(int chemistVisitId) =>
      _db.getDcrRcpaEntriesForVisit(chemistVisitId);

  Future<List<DcrRcpaCompetitor>> getRcpaCompetitors(int rcpaEntryId) =>
      _db.getDcrRcpaCompetitorsForEntry(rcpaEntryId);

  Future<void> saveRcpaMatrix({
    required int chemistVisitId,
    required List<RcpaEntryWithCompetitors> entries,
  }) async {
    await _db.clearDcrRcpaEntriesForVisit(chemistVisitId);
    for (final ec in entries) {
      final entryId = await _db.insertDcrRcpaEntry(DcrRcpaEntry(
        chemistVisitId: chemistVisitId,
        doctorId: ec.entry.doctorId,
        doctorName: ec.entry.doctorName,
        brandId: ec.entry.brandId,
        brandName: ec.entry.brandName,
        rxQtyPerWeek: ec.entry.rxQtyPerWeek,
      ));
      for (final comp in ec.competitors) {
        if (comp.competitorName.isNotEmpty) {
          await _db.insertDcrRcpaCompetitor(DcrRcpaCompetitor(
            rcpaEntryId: entryId,
            competitorName: comp.competitorName,
            salesQty: comp.salesQty,
          ));
        }
      }
    }
  }

  // ─── Chemist management ───────────────────────────────────────────────────────

  Future<DcrChemist> addChemist(DcrChemist chemist) async {
    final id = await _db.insertDcrChemist(chemist);
    final added = DcrChemist(
      id: id,
      name: chemist.name,
      area: chemist.area,
      territory: chemist.territory,
      address: chemist.address,
      mobile: chemist.mobile,
    );
    _chemists.add(added);
    _chemists.sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();
    return added;
  }

  Future<List<DcrChemist>> searchChemists(String q) =>
      _db.searchDcrChemists(q);
}

class RcpaEntryWithCompetitors {
  final DcrRcpaEntry entry;
  final List<DcrRcpaCompetitor> competitors;
  const RcpaEntryWithCompetitors(this.entry, this.competitors);
}
