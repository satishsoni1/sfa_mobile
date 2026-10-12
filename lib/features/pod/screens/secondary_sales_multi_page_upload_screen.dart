import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:zforce/features/pod/bloc/secondary_sales_multi_page_upload_cubit.dart';
import 'package:zforce/features/pod/config/secondary_sales_multi_page_upload.dart';
import 'package:zforce/features/pod/models/secondary_sales_dashboard_models.dart';
import 'package:zforce/features/pod/screens/secondary_sales_kam_stockists_screen.dart';
import 'package:zforce/features/pod/services/secondary_sales_stockist_list_controller.dart';
import 'package:zforce/features/pod/services/secondary_sales_stockist_service.dart';
import 'package:zforce/features/pod/widgets/secondary_sales_leave_upload_dialog.dart';
import 'package:zforce/features/pod/widgets/secondary_sales_on_behalf_section.dart';
import 'package:zforce/features/pod/widgets/secondary_sales_stockist_picker.dart';

/// Multi-page stock statement capture + upload (POST upload-multiple).
class SecondarySalesMultiPageUploadScreen extends StatefulWidget {
  const SecondarySalesMultiPageUploadScreen({
    super.key,
    this.initialMonth,
    this.initialStockist,
    this.stockistService,
  });

  final DateTime? initialMonth;
  final SecondarySalesStockistInfo? initialStockist;
  final SecondarySalesStockistService? stockistService;

  @override
  State<SecondarySalesMultiPageUploadScreen> createState() =>
      _SecondarySalesMultiPageUploadScreenState();
}

class _SecondarySalesMultiPageUploadScreenState
    extends State<SecondarySalesMultiPageUploadScreen> {
  late final SecondarySalesStockistListController _stockistController;
  late final SecondarySalesMultiPageUploadCubit _cubit;

  @override
  void initState() {
    super.initState();
    final service =
        widget.stockistService ?? SecondarySalesStockistService();
    _stockistController = SecondarySalesStockistListController(service: service);
    _cubit = SecondarySalesMultiPageUploadCubit(
      initialMonth: widget.initialMonth,
      initialStockist: widget.initialStockist,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Skip loading the list when a stockist is already selected.
      if (widget.initialStockist == null) {
        _stockistController.refresh();
      }
    });
  }

  @override
  void dispose() {
    _stockistController.dispose();
    _cubit.close();
    super.dispose();
  }

  Future<void> _onUploadPressed() async {
    if (!_cubit.prepareUploadOrShowError()) return;
    final state = _cubit.state;
    final monthLabel = DateFormat('MMMM yyyy').format(state.month!);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Upload Multi-Page Statement?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Stockist:\n${state.stockist!.name}'),
            const SizedBox(height: 10),
            Text('Month:\n$monthLabel'),
            const SizedBox(height: 10),
            Text('Pages:\n${state.pages.length}'),
            const SizedBox(height: 12),
            Text(secondarySalesMultiPageConfirmCount(state.pages.length)),
            const SizedBox(height: 8),
            const Text(
              kSecondarySalesMultiPageConfirmQuestion,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFFE65100),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF450095),
              foregroundColor: Colors.white,
            ),
            child: const Text('Upload Statement'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _cubit.upload();
  }

  Future<void> _confirmLeaveUpload() async {
    // After success, leave without an extra confirm.
    if (_cubit.state.success != null) {
      if (mounted) Navigator.of(context).pop(true);
      return;
    }
    final leave = await showSecondarySalesLeaveUploadDialog(context);
    if (leave && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocConsumer<SecondarySalesMultiPageUploadCubit,
          SecondarySalesMultiPageUploadState>(
        listener: (context, state) {
          if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: Colors.red.shade700,
              ),
            );
            context.read<SecondarySalesMultiPageUploadCubit>().clearError();
          }
          if (state.previewingIndex != null) {
            final index = state.previewingIndex!;
            final file = state.pages[index];
            showDialog<void>(
              context: context,
              builder: (ctx) => Dialog(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppBar(
                      title: Text('Page ${index + 1}'),
                      automaticallyImplyLeading: false,
                      actions: [
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            Navigator.pop(ctx);
                            context
                                .read<SecondarySalesMultiPageUploadCubit>()
                                .clearPreview();
                          },
                        ),
                      ],
                    ),
                    Flexible(
                      child: InteractiveViewer(
                        child: Image.file(file, fit: BoxFit.contain),
                      ),
                    ),
                  ],
                ),
              ),
            ).whenComplete(() {
              if (context.mounted) {
                context.read<SecondarySalesMultiPageUploadCubit>().clearPreview();
              }
            });
          }
        },
        builder: (context, state) {
          if (state.success != null) {
            return _SuccessView(
              state: state,
              onDone: () => Navigator.of(context).pop(true),
            );
          }

          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) async {
              if (didPop) return;
              await _confirmLeaveUpload();
            },
            child: Scaffold(
            backgroundColor: const Color(0xFFF7F8FB),
            appBar: AppBar(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF2C3E50),
              elevation: 0,
              title: const Text(
                'Multi-page Statement',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back',
                onPressed: _confirmLeaveUpload,
              ),
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                _InstructionCard(),
                const SizedBox(height: 16),
                _Card(
                  title: 'Statement Month',
                  child: SecondarySalesMonthBar(
                    selectedMonth: state.month ??
                        DateTime(DateTime.now().year, DateTime.now().month),
                    onMonthChanged: (m) {
                      if (state.isBusy) return;
                      context
                          .read<SecondarySalesMultiPageUploadCubit>()
                          .selectMonth(m);
                    },
                  ),
                ),
                const SizedBox(height: 12),
                _Card(
                  title: 'Upload On Behalf Of',
                  child: SecondarySalesOnBehalfSection(
                    selectedEmployee: state.onBehalfEmployee,
                    selectedStockist: state.onBehalfEmployee == null
                        ? null
                        : state.stockist,
                    enabled: !state.isBusy,
                    onEmployeeChanged: (member) {
                      if (state.isBusy) return;
                      context
                          .read<SecondarySalesMultiPageUploadCubit>()
                          .selectOnBehalfEmployee(member);
                      if (member == null) {
                        _stockistController.refresh();
                      }
                    },
                    onStockistChanged: (stockist) {
                      if (state.isBusy) return;
                      if (stockist == null) {
                        context
                            .read<SecondarySalesMultiPageUploadCubit>()
                            .clearStockist();
                      } else {
                        context
                            .read<SecondarySalesMultiPageUploadCubit>()
                            .selectStockist(stockist);
                      }
                    },
                  ),
                ),
                if (state.onBehalfEmployee == null) ...[
                  const SizedBox(height: 12),
                  _Card(
                    title: 'Stockist',
                    child: SecondarySalesStockistPicker(
                      controller: _stockistController,
                      selected: state.stockist,
                      onSelected: (s) {
                        if (state.isBusy) return;
                        // Keep selected stockist; empty + hide the search list.
                        _stockistController.reset();
                        context
                            .read<SecondarySalesMultiPageUploadCubit>()
                            .selectStockist(s);
                      },
                      onClear: () {
                        if (state.isBusy) return;
                        context
                            .read<SecondarySalesMultiPageUploadCubit>()
                            .clearStockist();
                        _stockistController.refresh();
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _Card(
                  title: 'Pages',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Pages: ${state.pages.length} / $kSecondarySalesMultiPageMaxPages',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (state.isLoadingPages) ...[
                        _PageProgressBar(
                          progress: state.pageLoadProgress,
                          label: state.pageLoadLabel ?? 'Loading pages…',
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (state.pages.isEmpty && !state.isLoadingPages)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3E8FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'No pages yet. Capture at least 2 pages to upload.',
                            style: TextStyle(color: Color(0xFF450095)),
                          ),
                        )
                      else if (state.pages.isNotEmpty)
                        ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: state.pages.length,
                          onReorder: state.isBusy
                              ? (oldIndex, newIndex) {}
                              : context
                                  .read<SecondarySalesMultiPageUploadCubit>()
                                  .reorderPages,
                          itemBuilder: (context, index) {
                            final file = state.pages[index];
                            return _PageTile(
                              key: ValueKey(file.path),
                              index: index,
                              file: file,
                              enabled: !state.isBusy,
                              onPreview: () => context
                                  .read<SecondarySalesMultiPageUploadCubit>()
                                  .previewPage(index),
                              onRetake: () => context
                                  .read<SecondarySalesMultiPageUploadCubit>()
                                  .retakePage(index),
                              onRemove: () => context
                                  .read<SecondarySalesMultiPageUploadCubit>()
                                  .removePage(index),
                            );
                          },
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: state.canAddPage
                                  ? () => context
                                      .read<
                                          SecondarySalesMultiPageUploadCubit>()
                                      .capturePage()
                                  : null,
                              icon: const Icon(Icons.add_a_photo_outlined),
                              label: const Text('Add Page'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF450095),
                                side: const BorderSide(
                                  color: Color(0xFF450095),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: state.canAddPage
                                  ? () => context
                                      .read<
                                          SecondarySalesMultiPageUploadCubit>()
                                      .pickFromGallery()
                                  : null,
                              icon: const Icon(Icons.photo_library_outlined),
                              label: const Text('Gallery'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF450095),
                                side: const BorderSide(
                                  color: Color(0xFF450095),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (state.stockist != null &&
                    state.month != null &&
                    state.pages.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _SummaryCard(state: state),
                ],
                if (state.isUploading) ...[
                  const SizedBox(height: 16),
                  _UploadProgressCard(state: state),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: state.canUpload ? _onUploadPressed : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF450095),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    state.isUploading ? 'Uploading…' : 'Upload Statement',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          );
        },
      ),
    );
  }
}

class _InstructionCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8D5FF)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            kSecondarySalesMultiPageMainInstruction,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF450095),
            ),
          ),
          SizedBox(height: 8),
          Text(
            kSecondarySalesMultiPageDoNotMixWarning,
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w700,
              color: Color(0xFFE65100),
            ),
          ),
          SizedBox(height: 8),
          Text(
            kSecondarySalesMultiPageWarning,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFFE65100),
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Each page is uploaded as a separate image. Pages are processed together as ONE stock statement.',
            style: TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _PageTile extends StatelessWidget {
  const _PageTile({
    super.key,
    required this.index,
    required this.file,
    required this.enabled,
    required this.onPreview,
    required this.onRetake,
    required this.onRemove,
  });

  final int index;
  final File file;
  final bool enabled;
  final VoidCallback onPreview;
  final VoidCallback onRetake;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            file,
            width: 52,
            height: 52,
            fit: BoxFit.cover,
            // Decode at display size to avoid jank with many large photos.
            cacheWidth: 104,
            cacheHeight: 104,
            filterQuality: FilterQuality.low,
          ),
        ),
        title: Text(
          'Page ${index + 1}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: const Text('Drag to reorder'),
        trailing: Wrap(
          spacing: 0,
          children: [
            IconButton(
              tooltip: 'Preview',
              onPressed: enabled ? onPreview : null,
              icon: const Icon(Icons.visibility_outlined, size: 20),
            ),
            IconButton(
              tooltip: 'Retake',
              onPressed: enabled ? onRetake : null,
              icon: const Icon(Icons.cameraswitch_outlined, size: 20),
            ),
            IconButton(
              tooltip: 'Remove',
              onPressed: enabled ? onRemove : null,
              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
            ),
            const Icon(Icons.drag_handle, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.state});
  final SecondarySalesMultiPageUploadState state;

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy').format(state.month!);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E8FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD1B3FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Stockist: ${state.stockist!.name}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          Text('Month: $monthLabel'),
          Text('Pages: ${state.pages.length}'),
          const SizedBox(height: 6),
          Text(
            secondarySalesMultiPageConfirmCount(state.pages.length),
            style: const TextStyle(fontSize: 12, color: Color(0xFF5D4037)),
          ),
        ],
      ),
    );
  }
}

class _PageProgressBar extends StatelessWidget {
  const _PageProgressBar({
    required this.progress,
    required this.label,
  });

  final double progress;
  final String label;

  @override
  Widget build(BuildContext context) {
    final value = progress.isNaN ? 0.0 : progress.clamp(0.0, 1.0);
    final pct = (value * 100).round();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: value <= 0 ? null : value,
              minHeight: 8,
              color: const Color(0xFF450095),
              backgroundColor: const Color(0xFFE8D5FF),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$pct%',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}

class _UploadProgressCard extends StatelessWidget {
  const _UploadProgressCard({required this.state});
  final SecondarySalesMultiPageUploadState state;

  @override
  Widget build(BuildContext context) {
    final pct = (state.uploadProgress * 100).round();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Uploading statement...',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(state.uploadProgressLabel),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: state.uploadProgress.clamp(0.0, 1.0),
            color: const Color(0xFF450095),
            backgroundColor: const Color(0xFFE8D5FF),
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: 6),
          Text('Overall progress: $pct%'),
        ],
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.state, required this.onDone});
  final SecondarySalesMultiPageUploadState state;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final success = state.success!;
    final monthLabel = success.month != null &&
            RegExp(r'^\d{4}-\d{2}$').hasMatch(success.month!)
        ? DateFormat('MMMM yyyy').format(
            DateTime(
              int.parse(success.month!.substring(0, 4)),
              int.parse(success.month!.substring(5, 7)),
            ),
          )
        : (success.month ?? '—');

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FB),
      appBar: AppBar(
        title: const Text('Upload complete'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2C3E50),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 64),
            const SizedBox(height: 12),
            const Text(
              'Statement uploaded successfully.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              secondarySalesMultiPageUploadedTogether(success.totalPages),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Processing will continue in the background. You can leave this screen.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Stockist: ${state.stockist?.name ?? success.stockistId}'),
                  Text('Month: $monthLabel'),
                  Text('Pages: ${success.totalPages}'),
                  Text('Status: ${success.status}'),
                  if (success.batchId != null)
                    Text('Batch #${success.batchId}'),
                ],
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: onDone,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF450095),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}
