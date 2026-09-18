import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zforce/features/pod/models/secondary_sales_dashboard_models.dart';
import 'package:zforce/features/pod/services/secondary_sales_stockist_list_controller.dart';
import 'package:zforce/features/pod/services/secondary_sales_stockist_service.dart';

const Duration kSecondarySalesStockistSearchDebounce =
    Duration(milliseconds: 400);
const double kSecondarySalesStockistLoadMoreThreshold = 300;
const double kSecondarySalesStockistListHeight = 280;

class SecondarySalesStockistPicker extends StatelessWidget {
  const SecondarySalesStockistPicker({
    super.key,
    required this.controller,
    this.selected,
    this.onSelected,
    this.onClear,
    this.authToken,
  });

  final SecondarySalesStockistListController controller;
  final SecondarySalesStockistInfo? selected;
  final ValueChanged<SecondarySalesStockistInfo>? onSelected;
  final VoidCallback? onClear;
  final String? authToken;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (selected != null)
          _SelectedCard(stockist: selected!, onClear: onClear)
        else
          const SizedBox.shrink(),
        if (selected != null)
          const SizedBox(height: 12)
        else
          const SizedBox.shrink(),
        _StockistSearchField(
          key: const ValueKey('ss-stockist-search'),
          onDebouncedQuery: (query) {
            controller.applySearch(query, authToken: authToken);
          },
        ),
        const SizedBox(height: 12),
        _StockistResultsList(
          key: const ValueKey('ss-stockist-results'),
          controller: controller,
          selected: selected,
          onSelected: onSelected,
          authToken: authToken,
        ),
      ],
    );
  }
}

class _StockistSearchField extends StatefulWidget {
  const _StockistSearchField({super.key, required this.onDebouncedQuery});

  final ValueChanged<String> onDebouncedQuery;

  @override
  State<_StockistSearchField> createState() => _StockistSearchFieldState();
}

class _StockistSearchFieldState extends State<_StockistSearchField> {
  late final TextEditingController _text;
  late final FocusNode _focus;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController();
    _focus = FocusNode(debugLabel: 'ss-stockist-search');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focus.dispose();
    _text.dispose();
    super.dispose();
  }

  void _scheduleSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(kSecondarySalesStockistSearchDebounce, () {
      widget.onDebouncedQuery(value);
    });
  }

  void _clear() {
    _debounce?.cancel();
    _text.clear();
    setState(() {});
    _focus.requestFocus();
    widget.onDebouncedQuery('');
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const ValueKey('ss-stockist-search-field'),
      controller: _text,
      focusNode: _focus,
      enabled: true,
      textInputAction: TextInputAction.search,
      keyboardType: TextInputType.text,
      onChanged: (value) {
        setState(() {});
        _scheduleSearch(value);
      },
      onSubmitted: (value) {
        _debounce?.cancel();
        widget.onDebouncedQuery(value);
      },
      decoration: InputDecoration(
        hintText: 'Search Stockist',
        prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF450095)),
        suffixIcon: _text.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: _clear,
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
    );
  }
}

class _StockistResultsList extends StatefulWidget {
  const _StockistResultsList({
    super.key,
    required this.controller,
    this.selected,
    this.onSelected,
    this.authToken,
  });

  final SecondarySalesStockistListController controller;
  final SecondarySalesStockistInfo? selected;
  final ValueChanged<SecondarySalesStockistInfo>? onSelected;
  final String? authToken;

  @override
  State<_StockistResultsList> createState() => _StockistResultsListState();
}

class _StockistResultsListState extends State<_StockistResultsList> {
  late final ScrollController _scroll;
  ScrollHoldController? _parentHold;

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController();
    _scroll.addListener(_onScroll);
    widget.controller.addListener(_onController);
  }

  @override
  void didUpdateWidget(covariant _StockistResultsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onController);
      widget.controller.addListener(_onController);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onController);
    _unlockParentScroll();
    _scroll.dispose();
    super.dispose();
  }

  void _lockParentScroll() {
    _unlockParentScroll();
    final parent = Scrollable.maybeOf(context);
    if (parent == null) return;
    _parentHold = parent.position.hold(() {
      _parentHold = null;
    });
  }

  void _unlockParentScroll() {
    _parentHold?.cancel();
    _parentHold = null;
  }

  void _onController() {
    if (mounted) setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryLoadMoreFromScroll();
    });
  }

  void _onScroll() {
    _tryLoadMoreFromScroll();
  }

  void _tryLoadMoreFromScroll() {
    if (!mounted) return;
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.maxScrollExtent <= 0) return;
    if (position.pixels >=
        position.maxScrollExtent - kSecondarySalesStockistLoadMoreThreshold) {
      widget.controller.loadMore(authToken: widget.authToken);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final stockists = controller.stockists;
    final selected = widget.selected;

    if (controller.isInitialLoading) {
      return const _LoadingState();
    }
    if (controller.isLoading && stockists.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF450095),
            ),
          ),
        ),
      );
    }
    if (controller.errorMessage != null && stockists.isEmpty) {
      return _MessageState(
        icon: Icons.error_outline_rounded,
        message: controller.errorMessage!,
        actionLabel: 'Retry',
        onAction: () => controller.refresh(authToken: widget.authToken),
      );
    }
    if (stockists.isEmpty) {
      return const _MessageState(
        icon: Icons.store_outlined,
        message: kSecondarySalesStockistEmptyMessage,
      );
    }

    final showFooter =
        controller.isLoadingMore || controller.loadMoreError != null;

    return SizedBox(
      height: kSecondarySalesStockistListHeight,
      child: Listener(
        onPointerDown: (_) => _lockParentScroll(),
        onPointerUp: (_) => _unlockParentScroll(),
        onPointerCancel: (_) => _unlockParentScroll(),
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification.metrics.axis != Axis.vertical) return true;
            if (notification.metrics.maxScrollExtent <= 0) return true;
            if (notification.metrics.pixels >=
                notification.metrics.maxScrollExtent -
                    kSecondarySalesStockistLoadMoreThreshold) {
              widget.controller.loadMore(authToken: widget.authToken);
            }
            return true;
          },
          child: Scrollbar(
            controller: _scroll,
            thumbVisibility: true,
            child: ListView.separated(
              controller: _scroll,
              primary: false,
              physics: const AlwaysScrollableScrollPhysics(
                parent: ClampingScrollPhysics(),
              ),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
              itemCount: stockists.length + (showFooter ? 1 : 0),
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                if (index >= stockists.length) {
                  if (controller.loadMoreError != null) {
                    return _LoadMoreError(
                      message: controller.loadMoreError!,
                      onRetry: () =>
                          controller.retryLoadMore(authToken: widget.authToken),
                    );
                  }
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF450095),
                        ),
                      ),
                    ),
                  );
                }
                final stockist = stockists[index];
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
        ),
      ),
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

class _LoadMoreError extends StatelessWidget {
  const _LoadMoreError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
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
