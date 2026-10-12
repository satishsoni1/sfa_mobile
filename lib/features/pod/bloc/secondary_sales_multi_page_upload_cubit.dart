import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:zforce/features/pod/config/pod_config.dart';
import 'package:zforce/features/pod/config/secondary_sales_multi_page_upload.dart';
import 'package:zforce/features/pod/models/secondary_sales_dashboard_models.dart';
import 'package:zforce/features/pod/models/secondary_sales_multi_page_upload_models.dart';
import 'package:zforce/features/pod/models/secondary_sales_upload_on_behalf_models.dart';
import 'package:zforce/features/pod/models/upload_record.dart';
import 'package:zforce/features/pod/services/secondary_sales_background_monitor.dart';
import 'package:zforce/features/pod/services/secondary_sales_data_refresh.dart';
import 'package:zforce/features/pod/services/secondary_sales_multi_page_upload_service.dart';
import 'package:zforce/features/pod/services/upload_record_store.dart';

class SecondarySalesMultiPageUploadState extends Equatable {
  const SecondarySalesMultiPageUploadState({
    this.stockist,
    this.onBehalfEmployee,
    this.month,
    this.pages = const [],
    this.clientUploadId,
    this.isLoadingPages = false,
    this.isUploading = false,
    this.uploadProgress = 0,
    this.uploadCurrentPage = 0,
    this.uploadTotalPages = 0,
    this.pageLoadProgress = 0,
    this.pageLoadLabel,
    this.errorMessage,
    this.success,
    this.previewingIndex,
  });

  final SecondarySalesStockistInfo? stockist;
  final SecondarySalesUploadTeamMember? onBehalfEmployee;
  final DateTime? month;
  final List<File> pages;
  /// Generated once per capture session; reused on retry (Laravel idempotency).
  final String? clientUploadId;
  final bool isLoadingPages;
  final bool isUploading;
  final double uploadProgress;
  final int uploadCurrentPage;
  final int uploadTotalPages;
  final double pageLoadProgress;
  final String? pageLoadLabel;
  final String? errorMessage;
  final SecondarySalesMultiPageUploadResponse? success;
  final int? previewingIndex;

  String? get monthYyyyMm {
    final m = month;
    if (m == null) return null;
    return '${m.year}-${m.month.toString().padLeft(2, '0')}';
  }

  bool get isBusy => isLoadingPages || isUploading;

  bool get canAddPage =>
      !isBusy && pages.length < kSecondarySalesMultiPageMaxPages;

  bool get canUpload =>
      !isBusy &&
      success == null &&
      stockist?.id != null &&
      month != null &&
      pages.length >= kSecondarySalesMultiPageMinPages &&
      pages.length <= kSecondarySalesMultiPageMaxPages;

  String get uploadProgressLabel {
    if (!isUploading) return '';
    if (uploadTotalPages <= 0) return 'Uploading statement...';
    if (uploadProgress >= 1) {
      return 'All $uploadTotalPages pages uploaded.';
    }
    final current = uploadCurrentPage.clamp(1, uploadTotalPages);
    return 'Uploading page $current of $uploadTotalPages';
  }

  SecondarySalesMultiPageUploadState copyWith({
    SecondarySalesStockistInfo? stockist,
    SecondarySalesUploadTeamMember? onBehalfEmployee,
    DateTime? month,
    List<File>? pages,
    String? clientUploadId,
    bool? isLoadingPages,
    bool? isUploading,
    double? uploadProgress,
    int? uploadCurrentPage,
    int? uploadTotalPages,
    double? pageLoadProgress,
    String? pageLoadLabel,
    String? errorMessage,
    SecondarySalesMultiPageUploadResponse? success,
    int? previewingIndex,
    bool clearStockist = false,
    bool clearOnBehalf = false,
    bool clearError = false,
    bool clearSuccess = false,
    bool clearPreview = false,
    bool clearPageLoadLabel = false,
  }) {
    return SecondarySalesMultiPageUploadState(
      stockist: clearStockist ? null : (stockist ?? this.stockist),
      onBehalfEmployee: clearOnBehalf
          ? null
          : (onBehalfEmployee ?? this.onBehalfEmployee),
      month: month ?? this.month,
      pages: pages ?? this.pages,
      clientUploadId: clientUploadId ?? this.clientUploadId,
      isLoadingPages: isLoadingPages ?? this.isLoadingPages,
      isUploading: isUploading ?? this.isUploading,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      uploadCurrentPage: uploadCurrentPage ?? this.uploadCurrentPage,
      uploadTotalPages: uploadTotalPages ?? this.uploadTotalPages,
      pageLoadProgress: pageLoadProgress ?? this.pageLoadProgress,
      pageLoadLabel: clearPageLoadLabel
          ? null
          : (pageLoadLabel ?? this.pageLoadLabel),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      success: clearSuccess ? null : (success ?? this.success),
      previewingIndex:
          clearPreview ? null : (previewingIndex ?? this.previewingIndex),
    );
  }

  @override
  List<Object?> get props => [
        stockist?.id,
        onBehalfEmployee?.id,
        month,
        pages.map((f) => f.path).toList(),
        clientUploadId,
        isLoadingPages,
        isUploading,
        uploadProgress,
        uploadCurrentPage,
        uploadTotalPages,
        pageLoadProgress,
        pageLoadLabel,
        errorMessage,
        success?.batchId,
        previewingIndex,
      ];
}

class SecondarySalesMultiPageUploadCubit
    extends Cubit<SecondarySalesMultiPageUploadState> {
  SecondarySalesMultiPageUploadCubit({
    SecondarySalesMultiPageUploadService? uploadService,
    ImagePicker? imagePicker,
    UploadRecordStore? recordStore,
    DateTime? initialMonth,
    SecondarySalesStockistInfo? initialStockist,
    String? clientUploadId,
  }) : this._(
          uploadService: uploadService ?? SecondarySalesMultiPageUploadService(),
          imagePicker: imagePicker ?? ImagePicker(),
          recordStore: recordStore ?? UploadRecordStore.instance,
          initialMonth: initialMonth,
          initialStockist: initialStockist,
          clientUploadId: clientUploadId,
        );

  SecondarySalesMultiPageUploadCubit._({
    required SecondarySalesMultiPageUploadService uploadService,
    required ImagePicker imagePicker,
    required UploadRecordStore recordStore,
    DateTime? initialMonth,
    SecondarySalesStockistInfo? initialStockist,
    String? clientUploadId,
  })  : _uploadService = uploadService,
        _imagePicker = imagePicker,
        _recordStore = recordStore,
        super(
          SecondarySalesMultiPageUploadState(
            month: initialMonth ??
                DateTime(DateTime.now().year, DateTime.now().month),
            stockist: initialStockist,
            clientUploadId:
                clientUploadId ?? uploadService.newClientUploadId(),
          ),
        );

  final SecondarySalesMultiPageUploadService _uploadService;
  final ImagePicker _imagePicker;
  final UploadRecordStore _recordStore;

  void selectStockist(SecondarySalesStockistInfo? stockist) {
    emit(
      state.copyWith(
        stockist: stockist,
        clearError: true,
        clearSuccess: true,
      ),
    );
  }

  void clearStockist() {
    emit(
      state.copyWith(
        clearStockist: true,
        clearError: true,
      ),
    );
  }

  void selectOnBehalfEmployee(SecondarySalesUploadTeamMember? employee) {
    emit(
      state.copyWith(
        onBehalfEmployee: employee,
        clearOnBehalf: employee == null,
        clearStockist: true,
        clearError: true,
        clearSuccess: true,
      ),
    );
  }

  void clearOnBehalfEmployee() {
    emit(
      state.copyWith(
        clearOnBehalf: true,
        clearStockist: true,
        clearError: true,
      ),
    );
  }

  void selectMonth(DateTime month) {
    emit(
      state.copyWith(
        month: DateTime(month.year, month.month),
        clearError: true,
        clearSuccess: true,
      ),
    );
  }

  String? _requireStockistAndMonth() {
    if (state.stockist == null) {
      return kSecondarySalesMultiPageMissingStockistMessage;
    }
    if (state.month == null) {
      return kSecondarySalesMultiPageMissingMonthMessage;
    }
    return null;
  }

  Future<void> capturePage() async {
    if (!state.canAddPage) {
      emit(
        state.copyWith(
          errorMessage: state.pages.length >= kSecondarySalesMultiPageMaxPages
              ? kSecondarySalesMultiPageMaxPagesMessage
              : null,
        ),
      );
      return;
    }
    final prerequisite = _requireStockistAndMonth();
    if (prerequisite != null) {
      emit(state.copyWith(errorMessage: prerequisite));
      return;
    }

    try {
      final photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 95,
      );
      if (photo == null) return;
      final next = List<File>.from(state.pages)..add(File(photo.path));
      emit(
        state.copyWith(
          pages: next,
          clearError: true,
          clearSuccess: true,
        ),
      );
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Camera error: $e'));
    }
  }

  /// Pick one or more images from gallery for the same multi-page statement.
  Future<void> pickFromGallery() async {
    if (!state.canAddPage) {
      emit(
        state.copyWith(
          errorMessage: kSecondarySalesMultiPageMaxPagesMessage,
        ),
      );
      return;
    }
    final prerequisite = _requireStockistAndMonth();
    if (prerequisite != null) {
      emit(state.copyWith(errorMessage: prerequisite));
      return;
    }

    try {
      final remaining =
          kSecondarySalesMultiPageMaxPages - state.pages.length;
      final picked = await _imagePicker.pickMultiImage(imageQuality: 95);
      if (picked.isEmpty) return;

      final accepted = picked.take(remaining).toList();
      if (accepted.isEmpty) {
        emit(
          state.copyWith(errorMessage: kSecondarySalesMultiPageMaxPagesMessage),
        );
        return;
      }

      emit(
        state.copyWith(
          isLoadingPages: true,
          pageLoadProgress: 0,
          pageLoadLabel: 'Loading pages…',
          clearError: true,
          clearSuccess: true,
        ),
      );

      final next = List<File>.from(state.pages);
      for (var i = 0; i < accepted.length; i++) {
        next.add(File(accepted[i].path));
        emit(
          state.copyWith(
            isLoadingPages: true,
            pages: List<File>.from(next),
            pageLoadProgress: (i + 1) / accepted.length,
            pageLoadLabel: 'Loading page ${i + 1} of ${accepted.length}…',
          ),
        );
        await Future<void>.delayed(Duration.zero);
      }

      final truncated = picked.length > remaining;
      emit(
        state.copyWith(
          isLoadingPages: false,
          pages: next,
          pageLoadProgress: 1,
          clearPageLoadLabel: true,
          clearError: !truncated,
          errorMessage:
              truncated ? kSecondarySalesMultiPageMaxPagesMessage : null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isLoadingPages: false,
          clearPageLoadLabel: true,
          errorMessage: 'Gallery error: $e',
        ),
      );
    }
  }

  Future<void> retakePage(int index) async {
    if (index < 0 || index >= state.pages.length || state.isBusy) return;
    try {
      final photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 95,
      );
      if (photo == null) return;
      final next = List<File>.from(state.pages);
      next[index] = File(photo.path);
      emit(
        state.copyWith(
          pages: next,
          clearError: true,
        ),
      );
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Camera error: $e'));
    }
  }

  void removePage(int index) {
    if (index < 0 || index >= state.pages.length || state.isBusy) return;
    final next = List<File>.from(state.pages)..removeAt(index);
    emit(
      state.copyWith(
        pages: next,
        clearError: true,
      ),
    );
  }

  void reorderPages(int oldIndex, int newIndex) {
    if (state.isBusy) return;
    if (oldIndex < 0 || oldIndex >= state.pages.length) return;
    var target = newIndex;
    if (target > oldIndex) target -= 1;
    if (target < 0 || target >= state.pages.length) return;
    final next = List<File>.from(state.pages);
    final item = next.removeAt(oldIndex);
    next.insert(target, item);
    emit(state.copyWith(pages: next));
  }

  void previewPage(int index) {
    if (index < 0 || index >= state.pages.length) return;
    emit(state.copyWith(previewingIndex: index));
  }

  void clearPreview() => emit(state.copyWith(clearPreview: true));

  void clearError() => emit(state.copyWith(clearError: true));

  String? validationMessage() {
    return _uploadService.validateBeforeUpload(
      stockistId: state.stockist?.id,
      month: state.monthYyyyMm,
      files: state.pages,
    );
  }

  bool prepareUploadOrShowError() {
    final error = validationMessage();
    if (error != null) {
      emit(state.copyWith(errorMessage: error));
      return false;
    }
    return true;
  }

  /// Uploads individual page images via POST /secondary-sales/upload-multiple.
  Future<bool> upload() async {
    if (state.isUploading) return false;
    if (!prepareUploadOrShowError()) return false;

    final clientUploadId =
        state.clientUploadId ?? _uploadService.newClientUploadId();
    final totalPages = state.pages.length;

    emit(
      state.copyWith(
        clientUploadId: clientUploadId,
        isUploading: true,
        uploadProgress: 0,
        uploadCurrentPage: 1,
        uploadTotalPages: totalPages,
        clearError: true,
        clearSuccess: true,
      ),
    );

    try {
      final response = await _uploadService.uploadMultipleStockStatement(
        stockistId: state.stockist!.id!,
        month: state.monthYyyyMm!,
        files: state.pages,
        clientUploadId: clientUploadId,
        onBehalfOfEmployeeId: state.onBehalfEmployee?.id,
        onProgress: ({
          required double overallProgress,
          required int currentPage,
          required int totalPages,
        }) {
          emit(
            state.copyWith(
              isUploading: true,
              uploadProgress: overallProgress,
              uploadCurrentPage: currentPage,
              uploadTotalPages: totalPages,
            ),
          );
        },
      );

      final filenames =
          SecondarySalesMultiPageUploadService.orderedPageFilenames(
        state.pages,
      );
      final record = UploadRecord(
        batchId: response.batchId!.toString(),
        batchDbId: response.batchId,
        uploadType: POD_CLIENT_UPLOAD_TYPE,
        fileNames: filenames,
        documentIds: const [],
        status: response.status,
        createdAt: DateTime.now(),
        totalFiles: totalPages,
      );
      await _recordStore.upsert(record);
      SecondarySalesBackgroundMonitor.instance.ensureStarted();
      SecondarySalesDataRefresh.notify();

      emit(
        state.copyWith(
          isUploading: false,
          uploadProgress: 1,
          uploadCurrentPage: totalPages,
          uploadTotalPages: totalPages,
          success: response,
          pages: const [],
        ),
      );
      return true;
    } on SecondarySalesMultiPageUploadException catch (e) {
      emit(
        state.copyWith(
          isUploading: false,
          // Keep the same client_upload_id for retry.
          clientUploadId: clientUploadId,
          errorMessage: e.message,
        ),
      );
      return false;
    } catch (_) {
      emit(
        state.copyWith(
          isUploading: false,
          clientUploadId: clientUploadId,
          errorMessage: kSecondarySalesMultiPageUploadInterruptedMessage,
        ),
      );
      return false;
    }
  }
}
