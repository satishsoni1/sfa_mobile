import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zforce/features/pod/models/secondary_sales_stock_correction_models.dart';
import 'package:zforce/features/pod/services/secondary_sales_stock_correction_service.dart';

class SecondarySalesStockCorrectionState extends Equatable {
  const SecondarySalesStockCorrectionState({
    this.isLoading = false,
    this.isSaving = false,
    this.data,
    this.drafts = const {},
    this.reason = '',
    this.errorMessage,
    this.successMessage,
  });

  final bool isLoading;
  final bool isSaving;
  final SecondarySalesCorrectionResponse? data;
  final Map<int, SecondarySalesCorrectionDraft> drafts;
  final String reason;
  final String? errorMessage;
  final String? successMessage;

  bool get canEdit => data?.canCorrectStock == true;

  bool get hasChanges {
    final lines = data?.lines ?? const [];
    for (final line in lines) {
      final draft = drafts[line.lineIndex];
      if (draft == null) continue;
      if (draft.openingQty != null &&
          !_eq(draft.openingQty, line.effectiveOpeningQty)) {
        return true;
      }
      if (draft.closingQty != null &&
          !_eq(draft.closingQty, line.effectiveClosingQty)) {
        return true;
      }
    }
    return false;
  }

  SecondarySalesStockCorrectionState copyWith({
    bool? isLoading,
    bool? isSaving,
    SecondarySalesCorrectionResponse? data,
    Map<int, SecondarySalesCorrectionDraft>? drafts,
    String? reason,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return SecondarySalesStockCorrectionState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      data: data ?? this.data,
      drafts: drafts ?? this.drafts,
      reason: reason ?? this.reason,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        isSaving,
        data,
        drafts,
        reason,
        errorMessage,
        successMessage,
      ];
}

bool _eq(double? a, double? b) {
  if (a == null && b == null) return true;
  if (a == null || b == null) return false;
  return (a - b).abs() < 0.000001;
}

class SecondarySalesStockCorrectionCubit
    extends Cubit<SecondarySalesStockCorrectionState> {
  SecondarySalesStockCorrectionCubit({
    required this.statementId,
    SecondarySalesStockCorrectionService? service,
  })  : _service = service ?? SecondarySalesStockCorrectionService(),
        super(const SecondarySalesStockCorrectionState());

  final int statementId;
  final SecondarySalesStockCorrectionService _service;

  Future<void> load() async {
    emit(
      state.copyWith(
        isLoading: true,
        clearError: true,
        clearSuccess: true,
      ),
    );
    try {
      final data = await _service.fetchCorrections(statementId);
      final drafts = <int, SecondarySalesCorrectionDraft>{};
      for (final line in data.lines) {
        drafts[line.lineIndex] = SecondarySalesCorrectionDraft(
          lineIndex: line.lineIndex,
          openingQty: line.effectiveOpeningQty,
          closingQty: line.effectiveClosingQty,
        );
      }
      emit(
        state.copyWith(
          isLoading: false,
          data: data,
          drafts: drafts,
          clearError: true,
        ),
      );
    } on SecondarySalesStockCorrectionException catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: e.message,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage:
              'Unable to load stock corrections. Please try again.',
        ),
      );
    }
  }

  void updateReason(String value) {
    emit(state.copyWith(reason: value, clearError: true, clearSuccess: true));
  }

  void updateOpening(int lineIndex, String raw) {
    _updateDraft(lineIndex, openingRaw: raw);
  }

  void updateClosing(int lineIndex, String raw) {
    _updateDraft(lineIndex, closingRaw: raw);
  }

  void _updateDraft(
    int lineIndex, {
    String? openingRaw,
    String? closingRaw,
  }) {
    if (!state.canEdit) return;
    final current = Map<int, SecondarySalesCorrectionDraft>.from(state.drafts);
    final existing = current[lineIndex] ??
        SecondarySalesCorrectionDraft(lineIndex: lineIndex);
    if (openingRaw != null) {
      final trimmed = openingRaw.trim();
      existing.openingQty =
          trimmed.isEmpty ? null : double.tryParse(trimmed);
    }
    if (closingRaw != null) {
      final trimmed = closingRaw.trim();
      existing.closingQty =
          trimmed.isEmpty ? null : double.tryParse(trimmed);
    }
    current[lineIndex] = existing;
    emit(state.copyWith(drafts: current, clearError: true, clearSuccess: true));
  }

  String? validateBeforeSave() {
    if (!state.canEdit) {
      return 'You do not have permission to modify stock quantities.';
    }
    if (state.reason.trim().length < 5) {
      return 'Please enter a reason (at least 5 characters).';
    }
    for (final draft in state.drafts.values) {
      if (draft.openingQty != null && draft.openingQty! < 0) {
        return 'Opening quantity cannot be negative.';
      }
      if (draft.closingQty != null && draft.closingQty! < 0) {
        return 'Closing quantity cannot be negative.';
      }
    }
    if (!state.hasChanges) return 'No quantity changes to save.';
    return null;
  }

  Future<bool> save() async {
    final validationError = validateBeforeSave();
    if (validationError != null) {
      emit(state.copyWith(errorMessage: validationError, clearSuccess: true));
      return false;
    }
    final data = state.data;
    if (data == null) return false;

    emit(
      state.copyWith(
        isSaving: true,
        clearError: true,
        clearSuccess: true,
      ),
    );
    try {
      final refreshed = await _service.saveCorrections(
        statementId: statementId,
        reason: state.reason,
        originalLines: data.lines,
        drafts: state.drafts,
      );
      final drafts = <int, SecondarySalesCorrectionDraft>{};
      for (final line in refreshed.lines) {
        drafts[line.lineIndex] = SecondarySalesCorrectionDraft(
          lineIndex: line.lineIndex,
          openingQty: line.effectiveOpeningQty,
          closingQty: line.effectiveClosingQty,
        );
      }
      emit(
        state.copyWith(
          isSaving: false,
          data: refreshed,
          drafts: drafts,
          reason: '',
          successMessage: 'Stock corrections saved successfully.',
          clearError: true,
        ),
      );
      return true;
    } on SecondarySalesStockCorrectionException catch (e) {
      emit(
        state.copyWith(
          isSaving: false,
          errorMessage: e.message,
          clearSuccess: true,
        ),
      );
      return false;
    } catch (_) {
      emit(
        state.copyWith(
          isSaving: false,
          errorMessage:
              'Unable to save stock corrections. Please try again.',
          clearSuccess: true,
        ),
      );
      return false;
    }
  }
}
