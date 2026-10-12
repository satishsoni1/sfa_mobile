import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zforce/features/pod/models/secondary_sales_upload_status_models.dart';
import 'package:zforce/features/pod/services/secondary_sales_upload_status_service.dart';

/// Debounce pause before sending `search` to Laravel (~400–500ms).
const Duration kSecondarySalesUploadStatusSearchDebounce =
    Duration(milliseconds: 450);

class SecondarySalesUploadStatusState extends Equatable {
  const SecondarySalesUploadStatusState({
    required this.month,
    this.level = 'team',
    this.searchQuery = '',
    this.isLoadingFilters = false,
    this.isLoadingReport = false,
    this.isLoadingMore = false,
    this.isLoadingStockistDetail = false,
    this.isSearching = false,
    this.divisions = const [],
    this.zms = const [],
    this.sms = const [],
    this.nsms = const [],
    this.states = const [],
    this.teams = const [],
    this.employees = const [],
    this.stockists = const [],
    this.selectedDivision,
    this.selectedZm,
    this.selectedSm,
    this.selectedNsm,
    this.selectedState,
    this.selectedTeam,
    this.selectedEmployee,
    this.selectedStockist,
    this.report,
    this.rows = const [],
    this.stockistSummary,
    this.errorMessage,
    this.filterErrorMessage,
    this.searchEpoch = 0,
  });

  final DateTime month;
  final String level;
  final String searchQuery;
  final bool isLoadingFilters;
  final bool isLoadingReport;
  final bool isLoadingMore;
  final bool isLoadingStockistDetail;
  final bool isSearching;
  final List<SecondarySalesUploadStatusFilterOption> divisions;
  final List<SecondarySalesUploadStatusFilterOption> zms;
  final List<SecondarySalesUploadStatusFilterOption> sms;
  final List<SecondarySalesUploadStatusFilterOption> nsms;
  final List<SecondarySalesUploadStatusFilterOption> states;
  final List<SecondarySalesUploadStatusFilterOption> teams;
  final List<SecondarySalesUploadStatusFilterOption> employees;
  final List<SecondarySalesUploadStatusFilterOption> stockists;
  final SecondarySalesUploadStatusFilterOption? selectedDivision;
  final SecondarySalesUploadStatusFilterOption? selectedZm;
  final SecondarySalesUploadStatusFilterOption? selectedSm;
  final SecondarySalesUploadStatusFilterOption? selectedNsm;
  final SecondarySalesUploadStatusFilterOption? selectedState;
  final SecondarySalesUploadStatusFilterOption? selectedTeam;
  final SecondarySalesUploadStatusFilterOption? selectedEmployee;
  final SecondarySalesUploadStatusFilterOption? selectedStockist;
  final SecondarySalesUploadStatusResponse? report;
  final List<SecondarySalesUploadStatusRow> rows;
  final SecondarySalesUploadStatusStockistSummary? stockistSummary;
  final String? errorMessage;
  final String? filterErrorMessage;

  /// Bumps when Flutter clears search so the TextField can sync.
  final int searchEpoch;

  String get monthYyyyMm =>
      '${month.year}-${month.month.toString().padLeft(2, '0')}';

  bool get hasMore => report?.pagination.hasMore == true;

  bool get hasActiveSearch => searchQuery.trim().isNotEmpty;

  SecondarySalesUploadStatusState copyWith({
    DateTime? month,
    String? level,
    String? searchQuery,
    bool? isLoadingFilters,
    bool? isLoadingReport,
    bool? isLoadingMore,
    bool? isLoadingStockistDetail,
    bool? isSearching,
    List<SecondarySalesUploadStatusFilterOption>? divisions,
    List<SecondarySalesUploadStatusFilterOption>? zms,
    List<SecondarySalesUploadStatusFilterOption>? sms,
    List<SecondarySalesUploadStatusFilterOption>? nsms,
    List<SecondarySalesUploadStatusFilterOption>? states,
    List<SecondarySalesUploadStatusFilterOption>? teams,
    List<SecondarySalesUploadStatusFilterOption>? employees,
    List<SecondarySalesUploadStatusFilterOption>? stockists,
    SecondarySalesUploadStatusFilterOption? selectedDivision,
    SecondarySalesUploadStatusFilterOption? selectedZm,
    SecondarySalesUploadStatusFilterOption? selectedSm,
    SecondarySalesUploadStatusFilterOption? selectedNsm,
    SecondarySalesUploadStatusFilterOption? selectedState,
    SecondarySalesUploadStatusFilterOption? selectedTeam,
    SecondarySalesUploadStatusFilterOption? selectedEmployee,
    SecondarySalesUploadStatusFilterOption? selectedStockist,
    SecondarySalesUploadStatusResponse? report,
    List<SecondarySalesUploadStatusRow>? rows,
    SecondarySalesUploadStatusStockistSummary? stockistSummary,
    String? errorMessage,
    String? filterErrorMessage,
    int? searchEpoch,
    bool clearDivision = false,
    bool clearZm = false,
    bool clearSm = false,
    bool clearNsm = false,
    bool clearState = false,
    bool clearTeam = false,
    bool clearEmployee = false,
    bool clearStockist = false,
    bool clearError = false,
    bool clearFilterError = false,
    bool clearStockistSummary = false,
    bool clearReport = false,
    bool clearSearch = false,
  }) {
    return SecondarySalesUploadStatusState(
      month: month ?? this.month,
      level: level ?? this.level,
      searchQuery: clearSearch ? '' : (searchQuery ?? this.searchQuery),
      isLoadingFilters: isLoadingFilters ?? this.isLoadingFilters,
      isLoadingReport: isLoadingReport ?? this.isLoadingReport,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isLoadingStockistDetail:
          isLoadingStockistDetail ?? this.isLoadingStockistDetail,
      isSearching: isSearching ?? this.isSearching,
      divisions: divisions ?? this.divisions,
      zms: zms ?? this.zms,
      sms: sms ?? this.sms,
      nsms: nsms ?? this.nsms,
      states: states ?? this.states,
      teams: teams ?? this.teams,
      employees: employees ?? this.employees,
      stockists: stockists ?? this.stockists,
      selectedDivision:
          clearDivision ? null : (selectedDivision ?? this.selectedDivision),
      selectedZm: clearZm ? null : (selectedZm ?? this.selectedZm),
      selectedSm: clearSm ? null : (selectedSm ?? this.selectedSm),
      selectedNsm: clearNsm ? null : (selectedNsm ?? this.selectedNsm),
      selectedState: clearState ? null : (selectedState ?? this.selectedState),
      selectedTeam: clearTeam ? null : (selectedTeam ?? this.selectedTeam),
      selectedEmployee:
          clearEmployee ? null : (selectedEmployee ?? this.selectedEmployee),
      selectedStockist:
          clearStockist ? null : (selectedStockist ?? this.selectedStockist),
      report: clearReport ? null : (report ?? this.report),
      rows: rows ?? this.rows,
      stockistSummary: clearStockistSummary
          ? null
          : (stockistSummary ?? this.stockistSummary),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      filterErrorMessage: clearFilterError
          ? null
          : (filterErrorMessage ?? this.filterErrorMessage),
      searchEpoch: searchEpoch ?? this.searchEpoch,
    );
  }

  @override
  List<Object?> get props => [
        month,
        level,
        searchQuery,
        isLoadingFilters,
        isLoadingReport,
        isLoadingMore,
        isLoadingStockistDetail,
        isSearching,
        divisions,
        zms,
        sms,
        nsms,
        states,
        teams,
        employees,
        stockists,
        selectedDivision,
        selectedZm,
        selectedSm,
        selectedNsm,
        selectedState,
        selectedTeam,
        selectedEmployee,
        selectedStockist,
        report,
        rows,
        stockistSummary,
        errorMessage,
        filterErrorMessage,
        searchEpoch,
      ];
}

class SecondarySalesUploadStatusCubit
    extends Cubit<SecondarySalesUploadStatusState> {
  SecondarySalesUploadStatusCubit({
    SecondarySalesUploadStatusService? service,
    DateTime? initialMonth,
    this.searchDebounce = kSecondarySalesUploadStatusSearchDebounce,
  })  : _service = service ?? SecondarySalesUploadStatusService(),
        super(
          SecondarySalesUploadStatusState(
            month: initialMonth ??
                DateTime(DateTime.now().year, DateTime.now().month),
          ),
        );

  final SecondarySalesUploadStatusService _service;
  final Duration searchDebounce;

  Timer? _searchDebounce;
  int _reportRequestId = 0;

  @override
  Future<void> close() {
    _searchDebounce?.cancel();
    return super.close();
  }

  Future<void> initialize() async {
    await loadFilters();
    await loadReport(reset: true);
  }

  Future<void> loadFilters() async {
    emit(
      state.copyWith(
        isLoadingFilters: true,
        clearFilterError: true,
      ),
    );
    try {
      final parent = _parentQuery();
      final results = await Future.wait([
        _safeFilter('divisions', parent),
        _safeFilter('zms', parent),
        _safeFilter('sms', parent),
        _safeFilter('nsms', parent),
        _safeFilter('states', parent),
        _safeFilter('teams', parent),
        _safeFilter('employees', parent),
        _safeFilter('stockists', parent),
      ]);
      emit(
        state.copyWith(
          isLoadingFilters: false,
          divisions: results[0],
          zms: results[1],
          sms: results[2],
          nsms: results[3],
          states: results[4],
          teams: results[5],
          employees: results[6],
          stockists: results[7],
          clearFilterError: true,
        ),
      );
    } on SecondarySalesUploadStatusException catch (e) {
      emit(
        state.copyWith(
          isLoadingFilters: false,
          filterErrorMessage: e.message,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          isLoadingFilters: false,
          filterErrorMessage:
              'Unable to load filter options. Please try again.',
        ),
      );
    }
  }

  Future<List<SecondarySalesUploadStatusFilterOption>> _safeFilter(
    String key,
    Map<String, String> query,
  ) async {
    try {
      return await _service.fetchFilterOptions(key, query: query);
    } on SecondarySalesUploadStatusException catch (e) {
      if (e.isForbidden) return const [];
      rethrow;
    }
  }

  Map<String, String> _parentQuery() {
    final q = <String, String>{'month': state.monthYyyyMm};
    final division = state.selectedDivision;
    if (division != null) {
      q['division'] = (division.code?.trim().isNotEmpty == true)
          ? division.code!.trim()
          : division.label;
    }
    void putId(String key, SecondarySalesUploadStatusFilterOption? opt) {
      if (opt != null && opt.id > 0) q[key] = opt.id.toString();
    }

    putId('zm_id', state.selectedZm);
    putId('sm_id', state.selectedSm);
    putId('nsm_id', state.selectedNsm);
    putId('state_id', state.selectedState);
    putId('team_id', state.selectedTeam);
    putId('employee_id', state.selectedEmployee);
    return q;
  }

  String? _normalizedSearch([String? override]) {
    final raw = (override ?? state.searchQuery).trim();
    return raw.isEmpty ? null : raw;
  }

  /// Debounced search input from the UI TextField.
  void onSearchChanged(String text) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(searchDebounce, () {
      unawaited(applySearch(text));
    });
  }

  /// Applies search immediately (also used after clear / tests).
  Future<void> applySearch(String text) async {
    _searchDebounce?.cancel();
    final next = text.trim();
    if (next == state.searchQuery) return;
    emit(
      state.copyWith(
        searchQuery: next,
        clearSearch: next.isEmpty,
        isSearching: true,
        clearStockistSummary: true,
      ),
    );
    await loadReport(reset: true);
  }

  Future<void> clearSearch() async {
    _searchDebounce?.cancel();
    final hadSearch = state.searchQuery.isNotEmpty;
    emit(
      state.copyWith(
        clearSearch: true,
        searchEpoch: state.searchEpoch + 1,
        isSearching: hadSearch,
        clearStockistSummary: true,
      ),
    );
    if (hadSearch) {
      await loadReport(reset: true);
    }
  }

  Future<void> loadReport({bool reset = true}) async {
    final requestId = ++_reportRequestId;
    final page = reset ? 1 : ((state.report?.pagination.page ?? 0) + 1);
    final search = _normalizedSearch();
    emit(
      state.copyWith(
        isLoadingReport: reset,
        isLoadingMore: !reset,
        isSearching: reset && search != null,
        clearError: true,
        clearStockistSummary: reset,
      ),
    );
    try {
      final division = state.selectedDivision;
      final report = await _service.fetchReport(
        month: state.monthYyyyMm,
        level: state.level,
        page: page,
        division: division == null
            ? null
            : ((division.code?.trim().isNotEmpty == true)
                ? division.code!.trim()
                : division.label),
        zmId: state.selectedZm?.id,
        smId: state.selectedSm?.id,
        nsmId: state.selectedNsm?.id,
        stateId: state.selectedState?.id,
        teamId: state.selectedTeam?.id,
        employeeId: state.selectedEmployee?.id,
        stockistId: state.selectedStockist?.id,
        search: search,
      );
      if (requestId != _reportRequestId || isClosed) return;
      final rows = reset ? report.rows : [...state.rows, ...report.rows];
      emit(
        state.copyWith(
          isLoadingReport: false,
          isLoadingMore: false,
          isSearching: false,
          report: report,
          rows: rows,
          clearError: true,
        ),
      );
    } on SecondarySalesUploadStatusException catch (e) {
      if (requestId != _reportRequestId || isClosed) return;
      emit(
        state.copyWith(
          isLoadingReport: false,
          isLoadingMore: false,
          isSearching: false,
          errorMessage: e.message,
          clearReport: reset,
          rows: reset ? const [] : null,
        ),
      );
    } catch (_) {
      if (requestId != _reportRequestId || isClosed) return;
      emit(
        state.copyWith(
          isLoadingReport: false,
          isLoadingMore: false,
          isSearching: false,
          errorMessage: 'Unable to load upload status. Please try again.',
          clearReport: reset,
          rows: reset ? const [] : null,
        ),
      );
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.isLoadingReport) return;
    await loadReport(reset: false);
  }

  Future<void> selectMonth(DateTime month) async {
    _searchDebounce?.cancel();
    emit(
      state.copyWith(
        month: DateTime(month.year, month.month),
        clearSearch: true,
        searchEpoch: state.searchEpoch + 1,
        clearStockistSummary: true,
      ),
    );
    await loadFilters();
    await loadReport(reset: true);
  }

  Future<void> selectLevel(String level) async {
    _searchDebounce?.cancel();
    emit(
      state.copyWith(
        level: level,
        clearSearch: true,
        searchEpoch: state.searchEpoch + 1,
        clearStockistSummary: true,
      ),
    );
    await loadReport(reset: true);
  }

  Future<void> selectDivision(
    SecondarySalesUploadStatusFilterOption? option,
  ) async {
    _searchDebounce?.cancel();
    emit(
      state.copyWith(
        selectedDivision: option,
        clearDivision: option == null,
        clearZm: true,
        clearSm: true,
        clearNsm: true,
        clearState: true,
        clearTeam: true,
        clearEmployee: true,
        clearStockist: true,
        clearSearch: true,
        searchEpoch: state.searchEpoch + 1,
        zms: const [],
        sms: const [],
        nsms: const [],
        states: const [],
        teams: const [],
        employees: const [],
        stockists: const [],
      ),
    );
    await loadFilters();
    await loadReport(reset: true);
  }

  Future<void> selectZm(
    SecondarySalesUploadStatusFilterOption? option,
  ) async {
    _searchDebounce?.cancel();
    emit(
      state.copyWith(
        selectedZm: option,
        clearZm: option == null,
        clearSm: true,
        clearNsm: true,
        clearState: true,
        clearTeam: true,
        clearEmployee: true,
        clearStockist: true,
        clearSearch: true,
        searchEpoch: state.searchEpoch + 1,
      ),
    );
    await loadFilters();
    await loadReport(reset: true);
  }

  Future<void> selectSm(
    SecondarySalesUploadStatusFilterOption? option,
  ) async {
    _searchDebounce?.cancel();
    emit(
      state.copyWith(
        selectedSm: option,
        clearSm: option == null,
        clearNsm: true,
        clearState: true,
        clearTeam: true,
        clearEmployee: true,
        clearStockist: true,
        clearSearch: true,
        searchEpoch: state.searchEpoch + 1,
      ),
    );
    await loadFilters();
    await loadReport(reset: true);
  }

  Future<void> selectNsm(
    SecondarySalesUploadStatusFilterOption? option,
  ) async {
    _searchDebounce?.cancel();
    emit(
      state.copyWith(
        selectedNsm: option,
        clearNsm: option == null,
        clearState: true,
        clearTeam: true,
        clearEmployee: true,
        clearStockist: true,
        clearSearch: true,
        searchEpoch: state.searchEpoch + 1,
      ),
    );
    await loadFilters();
    await loadReport(reset: true);
  }

  Future<void> selectState(
    SecondarySalesUploadStatusFilterOption? option,
  ) async {
    _searchDebounce?.cancel();
    emit(
      state.copyWith(
        selectedState: option,
        clearState: option == null,
        clearTeam: true,
        clearEmployee: true,
        clearStockist: true,
        clearSearch: true,
        searchEpoch: state.searchEpoch + 1,
      ),
    );
    await loadFilters();
    await loadReport(reset: true);
  }

  Future<void> selectTeam(
    SecondarySalesUploadStatusFilterOption? option,
  ) async {
    _searchDebounce?.cancel();
    emit(
      state.copyWith(
        selectedTeam: option,
        clearTeam: option == null,
        clearEmployee: true,
        clearStockist: true,
        clearSearch: true,
        searchEpoch: state.searchEpoch + 1,
      ),
    );
    await loadFilters();
    await loadReport(reset: true);
  }

  Future<void> selectEmployee(
    SecondarySalesUploadStatusFilterOption? option,
  ) async {
    _searchDebounce?.cancel();
    emit(
      state.copyWith(
        selectedEmployee: option,
        clearEmployee: option == null,
        clearStockist: true,
        clearSearch: true,
        searchEpoch: state.searchEpoch + 1,
      ),
    );
    await loadFilters();
    await loadReport(reset: true);
  }

  Future<void> selectStockist(
    SecondarySalesUploadStatusFilterOption? option,
  ) async {
    _searchDebounce?.cancel();
    emit(
      state.copyWith(
        selectedStockist: option,
        clearStockist: option == null,
        clearSearch: true,
        searchEpoch: state.searchEpoch + 1,
        clearStockistSummary: true,
      ),
    );
    await loadReport(reset: true);
  }

  Future<void> openStockistSummary(int stockistId) async {
    emit(
      state.copyWith(
        isLoadingStockistDetail: true,
        clearError: true,
        clearStockistSummary: true,
      ),
    );
    try {
      final summary = await _service.fetchStockistSummary(
        stockistId: stockistId,
        month: state.monthYyyyMm,
      );
      emit(
        state.copyWith(
          isLoadingStockistDetail: false,
          stockistSummary: summary,
          clearError: true,
        ),
      );
    } on SecondarySalesUploadStatusException catch (e) {
      emit(
        state.copyWith(
          isLoadingStockistDetail: false,
          errorMessage: e.message,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          isLoadingStockistDetail: false,
          errorMessage: 'Unable to load stockist summary. Please try again.',
        ),
      );
    }
  }

  void clearStockistSummary() {
    emit(state.copyWith(clearStockistSummary: true));
  }
}
