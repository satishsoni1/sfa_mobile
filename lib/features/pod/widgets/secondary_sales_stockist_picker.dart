import 'package:flutter/material.dart';
import 'package:zforce/features/pod/models/secondary_sales_dashboard_models.dart';
import 'package:zforce/features/pod/services/secondary_sales_stockist_service.dart';

class SecondarySalesStockistPicker extends StatefulWidget {
  const SecondarySalesStockistPicker({
    super.key,
    required this.stockists,
    required this.loading,
    this.selected,
    this.errorMessage,
    this.onSelected,
    this.onClear,
    this.onRetry,
  });

  final List<SecondarySalesStockistInfo> stockists;
  final bool loading;
  final SecondarySalesStockistInfo? selected;
  final String? errorMessage;
  final ValueChanged<SecondarySalesStockistInfo>? onSelected;
  final VoidCallback? onClear;
  final VoidCallback? onRetry;

  @override
  State<SecondarySalesStockistPicker> createState() =>
      _SecondarySalesStockistPickerState();
}

class _SecondarySalesStockistPickerState
    extends State<SecondarySalesStockistPicker> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = filterAuthorizedStockists(widget.stockists, _query);
    final selected = widget.selected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (selected != null) _SelectedCard(stockist: selected, onClear: widget.onClear),
        if (selected != null) const SizedBox(height: 12),
        TextField(
          controller: _search,
          enabled: !widget.loading && widget.errorMessage == null,
          onChanged: (value) => setState(() => _query = value),
          decoration: InputDecoration(
            hintText: 'Search Stockist',
            prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF450095)),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () {
                      _search.clear();
                      setState(() => _query = '');
                    },
                  ),
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE6E8EE)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE6E8EE)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF450095)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (widget.loading)
          const _LoadingState()
        else if (widget.errorMessage != null)
          _MessageState(
            icon: Icons.error_outline_rounded,
            message: widget.errorMessage!,
            actionLabel: widget.onRetry == null ? null : 'Retry',
            onAction: widget.onRetry,
          )
        else if (widget.stockists.isEmpty)
          const _MessageState(
            icon: Icons.store_outlined,
            message: kSecondarySalesStockistEmptyMessage,
          )
        else if (filtered.isEmpty)
          const _MessageState(
            icon: Icons.search_off_rounded,
            message: 'No matching stockists.',
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: filtered.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final stockist = filtered[index];
                final isSelected = selected?.id == stockist.id;
                return _StockistCard(
                  stockist: stockist,
                  selected: isSelected,
                  onTap: widget.onSelected == null
                      ? null
                      : () => widget.onSelected!(stockist),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _SelectedCard extends StatelessWidget {
  const _SelectedCard({required this.stockist, this.onClear});

  final SecondarySalesStockistInfo stockist;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4ECFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF450095)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF450095), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stockist.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                if (stockist.id != null)
                  Text(
                    'ID: ${stockist.id}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
              ],
            ),
          ),
          if (onClear != null)
            IconButton(
              tooltip: 'Clear selection',
              onPressed: onClear,
              icon: Icon(Icons.close_rounded, color: Colors.red.shade600),
            ),
        ],
      ),
    );
  }
}

class _StockistCard extends StatelessWidget {
  const _StockistCard({
    required this.stockist,
    required this.selected,
    this.onTap,
  });

  final SecondarySalesStockistInfo stockist;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFF4ECFF) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? const Color(0xFF450095) : const Color(0xFFE8EEF2),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stockist.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: ${stockist.id}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle, color: Color(0xFF450095), size: 20)
              else
                Icon(Icons.chevron_right_rounded, color: Colors.grey.shade500),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: LinearProgressIndicator(
            color: Color(0xFF450095),
            backgroundColor: Color(0xFFE8EEF2),
          ),
        ),
        for (var i = 0; i < 3; i++)
          Container(
            height: 58,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
      ],
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Icon(icon, size: 36, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 10),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
