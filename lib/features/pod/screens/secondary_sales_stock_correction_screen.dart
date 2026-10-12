import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zforce/features/pod/bloc/secondary_sales_stock_correction_cubit.dart';
import 'package:zforce/features/pod/models/secondary_sales_stock_correction_models.dart';

/// Manual stock correction screen for a Secondary Sales statement.
class SecondarySalesStockCorrectionScreen extends StatelessWidget {
  const SecondarySalesStockCorrectionScreen({
    super.key,
    required this.statementId,
    this.stockistName,
    this.statementMonth,
  });

  final int statementId;
  final String? stockistName;
  final String? statementMonth;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SecondarySalesStockCorrectionCubit(
        statementId: statementId,
      )..load(),
      child: _CorrectionView(
        fallbackStockistName: stockistName,
        fallbackMonth: statementMonth,
      ),
    );
  }
}

class _CorrectionView extends StatelessWidget {
  const _CorrectionView({
    this.fallbackStockistName,
    this.fallbackMonth,
  });

  final String? fallbackStockistName;
  final String? fallbackMonth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Manual Stock Correction',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: Colors.black87,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () =>
                context.read<SecondarySalesStockCorrectionCubit>().load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: BlocConsumer<SecondarySalesStockCorrectionCubit,
          SecondarySalesStockCorrectionState>(
        listenWhen: (p, c) =>
            p.successMessage != c.successMessage ||
            p.errorMessage != c.errorMessage,
        listener: (context, state) {
          final success = state.successMessage;
          if (success != null && success.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(success),
                backgroundColor: const Color(0xFF2E7D32),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state.isLoading && state.data == null) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF450095)),
            );
          }
          if (state.data == null) {
            return _ErrorBody(
              message: state.errorMessage ??
                  'Unable to load stock corrections.',
              onRetry: () =>
                  context.read<SecondarySalesStockCorrectionCubit>().load(),
            );
          }
          return _LoadedBody(
            state: state,
            fallbackStockistName: fallbackStockistName,
            fallbackMonth: fallbackMonth,
          );
        },
      ),
    );
  }
}

class _LoadedBody extends StatelessWidget {
  const _LoadedBody({
    required this.state,
    this.fallbackStockistName,
    this.fallbackMonth,
  });

  final SecondarySalesStockCorrectionState state;
  final String? fallbackStockistName;
  final String? fallbackMonth;

  @override
  Widget build(BuildContext context) {
    final data = state.data!;
    final stockist =
        data.stockistName?.trim().isNotEmpty == true
            ? data.stockistName!
            : (fallbackStockistName ?? '—');
    final month = data.statementMonth?.trim().isNotEmpty == true
        ? data.statementMonth!
        : (fallbackMonth ?? '—');

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
            children: [
              _HeaderCard(
                stockist: stockist,
                month: month,
                validation: data.stockValidation,
                canEdit: state.canEdit,
              ),
              if (state.errorMessage != null) ...[
                const SizedBox(height: 10),
                _InlineError(message: state.errorMessage!),
              ],
              const SizedBox(height: 12),
              ...data.lines.map((line) {
                final draft = state.drafts[line.lineIndex];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _LineCard(
                    line: line,
                    draft: draft,
                    canEdit: state.canEdit,
                    onOpeningChanged: (v) => context
                        .read<SecondarySalesStockCorrectionCubit>()
                        .updateOpening(line.lineIndex, v),
                    onClosingChanged: (v) => context
                        .read<SecondarySalesStockCorrectionCubit>()
                        .updateClosing(line.lineIndex, v),
                  ),
                );
              }),
              if (data.correctionHistory.isNotEmpty) ...[
                const SizedBox(height: 8),
                _HistorySection(history: data.correctionHistory),
              ],
              if (state.canEdit) ...[
                const SizedBox(height: 12),
                _ReasonField(
                  initialValue: state.reason,
                  onChanged: context
                      .read<SecondarySalesStockCorrectionCubit>()
                      .updateReason,
                ),
              ],
            ],
          ),
        ),
        if (state.canEdit)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: state.isSaving
                      ? null
                      : () => _confirmAndSave(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF450095),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: state.isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Save Corrections',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _confirmAndSave(BuildContext context) async {
    final cubit = context.read<SecondarySalesStockCorrectionCubit>();
    final clientError = cubit.validateBeforeSave();
    if (clientError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(clientError),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Save these stock corrections?'),
        content: const Text(
          'Opening and closing quantities will be updated for validation and reporting.',
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
            child: const Text('Save Corrections'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await cubit.save();
    }
  }
}

class _ReasonField extends StatefulWidget {
  const _ReasonField({
    required this.initialValue,
    required this.onChanged,
  });

  final String initialValue;
  final ValueChanged<String> onChanged;

  @override
  State<_ReasonField> createState() => _ReasonFieldState();
}

class _ReasonFieldState extends State<_ReasonField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant _ReasonField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue.isEmpty && _controller.text.isNotEmpty) {
      _controller.clear();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      minLines: 2,
      maxLines: 4,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        labelText: 'Reason *',
        hintText: 'Verified physical stock against statement',
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.stockist,
    required this.month,
    required this.validation,
    required this.canEdit,
  });

  final String stockist;
  final String month;
  final SecondarySalesStatementValidation validation;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6E8EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _meta('Stockist', stockist),
          const SizedBox(height: 6),
          _meta('Statement Month', month),
          const SizedBox(height: 10),
          Row(
            children: [
              _StatusPill(status: validation.displayStatus),
              const Spacer(),
              Text(
                canEdit ? 'Editing enabled' : 'View only',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: canEdit
                      ? const Color(0xFF2E7D32)
                      : Colors.grey.shade600,
                ),
              ),
            ],
          ),
          if ((validation.message ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              validation.message!,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ],
        ],
      ),
    );
  }

  Widget _meta(String label, String value) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF2C3E50),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({
    required this.line,
    required this.draft,
    required this.canEdit,
    required this.onOpeningChanged,
    required this.onClosingChanged,
  });

  final SecondarySalesCorrectionLine line;
  final SecondarySalesCorrectionDraft? draft;
  final bool canEdit;
  final ValueChanged<String> onOpeningChanged;
  final ValueChanged<String> onClosingChanged;

  @override
  Widget build(BuildContext context) {
    final v = line.stockValidation;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6E8EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            line.productName,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 10),
          _QtySection(
            title: 'Opening',
            extracted: line.extractedOpeningQty,
            corrected: line.openingCorrected,
            canEdit: canEdit,
            initial: draft?.openingQty ?? line.effectiveOpeningQty,
            onChanged: onOpeningChanged,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _ReadonlyChip('Receipt', line.receiptQty),
              _ReadonlyChip('Sales', line.salesQty),
              _ReadonlyChip('Sample', line.sampleQty),
              _ReadonlyChip('Expiry', line.expiryQty),
            ],
          ),
          const SizedBox(height: 10),
          _QtySection(
            title: 'Closing',
            extracted: line.extractedClosingQty,
            corrected: line.closingCorrected,
            canEdit: canEdit,
            initial: draft?.closingQty ?? line.effectiveClosingQty,
            onChanged: onClosingChanged,
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FB),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Expected Closing: ${_fmt(v.expectedClosingQty)}',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  'Actual Closing: ${_fmt(v.actualClosingQty)}',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  'Variance: ${_fmt(v.variance)}',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 6),
                _StatusPill(status: v.displayStatus),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QtySection extends StatefulWidget {
  const _QtySection({
    required this.title,
    required this.extracted,
    required this.corrected,
    required this.canEdit,
    required this.initial,
    required this.onChanged,
  });

  final String title;
  final double? extracted;
  final bool corrected;
  final bool canEdit;
  final double? initial;
  final ValueChanged<String> onChanged;

  @override
  State<_QtySection> createState() => _QtySectionState();
}

class _QtySectionState extends State<_QtySection> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _fmt(widget.initial));
  }

  @override
  void didUpdateWidget(covariant _QtySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _fmt(widget.initial);
    if (_controller.text != next && !widget.canEdit) {
      _controller.text = next;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: Color(0xFF2C3E50),
              ),
            ),
            if (widget.corrected) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4ECFF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Corrected',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF450095),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Extracted: ${_fmt(widget.extracted)}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 6),
        if (widget.canEdit)
          TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            onChanged: widget.onChanged,
            decoration: InputDecoration(
              labelText: 'Effective ${widget.title}',
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          )
        else
          Text(
            'Effective: ${_fmt(widget.initial)}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2C3E50),
            ),
          ),
      ],
    );
  }
}

class _ReadonlyChip extends StatelessWidget {
  const _ReadonlyChip(this.label, this.value);
  final String label;
  final double? value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE6E8EE)),
      ),
      child: Text(
        '$label: ${_fmt(value)}',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _HistorySection extends StatelessWidget {
  const _HistorySection({required this.history});
  final List<SecondarySalesCorrectionHistoryItem> history;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text(
        'Correction History',
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
      ),
      children: history.map((h) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            h.productName ?? 'Product',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          subtitle: Text(
            [
              if ((h.correctedAt ?? '').isNotEmpty) h.correctedAt,
              if ((h.correctedBy ?? '').isNotEmpty) 'By ${h.correctedBy}',
              if ((h.field ?? '').isNotEmpty) h.field,
              '${_fmt(h.previousQty)} → ${_fmt(h.newQty)}',
              if ((h.reason ?? '').isNotEmpty) h.reason,
            ].whereType<String>().join('\n'),
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        );
      }).toList(),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (status.toUpperCase()) {
      case 'VALID':
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF2E7D32);
        break;
      case 'INVALID':
        bg = const Color(0xFFFFEBEE);
        fg = const Color(0xFFC62828);
        break;
      case 'WARNING':
        bg = const Color(0xFFFFF8E1);
        fg = const Color(0xFFE65100);
        break;
      default:
        bg = const Color(0xFFECEFF1);
        fg = const Color(0xFF546E7A);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Text(
        message,
        style: TextStyle(color: Colors.red.shade800, fontSize: 13),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final forbidden = message.toLowerCase().contains('permission') ||
        message.toLowerCase().contains('authorized');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              forbidden ? Icons.lock_outline : Icons.error_outline,
              size: 40,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
            if (!forbidden) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF450095),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _fmt(double? v) {
  if (v == null) return '—';
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(2);
}
