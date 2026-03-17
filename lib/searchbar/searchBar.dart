import 'dart:async';

import 'package:async/async.dart';
import 'package:flutter/material.dart';

class SearchBarStyle {
  final Color backgroundColor;
  final Color surroundingColor;
  final double? searchBarHeight;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;

  const SearchBarStyle({
    this.backgroundColor = const Color.fromRGBO(142, 142, 147, .15),
    this.surroundingColor = const Color(0x00ffffff),
    this.searchBarHeight,
    this.padding = const EdgeInsets.all(5.0),
    this.borderRadius = const BorderRadius.all(Radius.circular(5.0)),
  });
}

mixin _ControllerListener<T> on State<TransitSearchBar<T>> {
  void onListChanged(List<T> items) {}
  void onLoading() {}
  void onClear() {}
  void onError(Error error) {}
}

class SearchBarController<T> {
  final List<T> _list = [];
  final List<T> _filteredList = [];
  final List<T> _sortedList = [];
  TextEditingController? _searchQueryController;
  String? _lastSearchedText;
  Future<List<T>> Function(String text)? _lastSearchFunction;
  _ControllerListener? _controllerListener;
  int Function(T a, T b)? _lastSorting;
  CancelableOperation<List<T>>? _cancelableOperation;
  int minimumChars = 0;

  void setTextController(
      TextEditingController controller, int minimumCharsParam) {
    _searchQueryController = controller;
    minimumChars = minimumCharsParam;
  }

  void setListener(_ControllerListener listener) {
    _controllerListener = listener;
  }

  void clear() {
    _controllerListener?.onClear();
  }

  void _search(
      String text, Future<List<T>> Function(String text) onSearch) async {
    _controllerListener?.onLoading();
    try {
      final existing = _cancelableOperation;
      if (existing != null &&
          !existing.isCompleted &&
          !existing.isCanceled) {
        existing.cancel();
      }
      _cancelableOperation = CancelableOperation.fromFuture(
        onSearch(text),
        onCancel: () {},
      );

      final List<T> items = await _cancelableOperation!.value;
      _lastSearchFunction = onSearch;
      _lastSearchedText = text;
      _list
        ..clear()
        ..addAll(items);
      _filteredList.clear();
      _sortedList.clear();
      _lastSorting = null;
      _controllerListener?.onListChanged(_list);
    } catch (error) {
      _controllerListener?.onError(error as Error);
    }
  }

  void injectSearch(
      String searchText, Future<List<T>> Function(String text) onSearch) {
    if (searchText.length >= minimumChars) {
      _searchQueryController?.text = searchText;
      _search(searchText, onSearch);
    }
  }

  void replayLastSearch() {
    final fn = _lastSearchFunction;
    final text = _lastSearchedText;
    if (fn != null && text != null) {
      _search(text, fn);
    }
  }

  void removeFilter() {
    _filteredList.clear();
    if (_lastSorting == null) {
      _controllerListener?.onListChanged(_list);
    } else {
      _sortedList
        ..clear()
        ..addAll(List<T>.from(_list))
        ..sort(_lastSorting);
      _controllerListener?.onListChanged(_sortedList);
    }
  }

  void removeSort() {
    _sortedList.clear();
    _lastSorting = null;
    _controllerListener
        ?.onListChanged(_filteredList.isEmpty ? _list : _filteredList);
  }

  void sortList(int Function(T a, T b) sorting) {
    _lastSorting = sorting;
    _sortedList
      ..clear()
      ..addAll(List<T>.from(_filteredList.isEmpty ? _list : _filteredList))
      ..sort(sorting);
    _controllerListener?.onListChanged(_sortedList);
  }

  void filterList(bool Function(T item) filter) {
    _filteredList
      ..clear()
      ..addAll((_sortedList.isEmpty ? _list : _sortedList).where(filter));
    _controllerListener?.onListChanged(_filteredList);
  }
}

class TransitSearchBar<T> extends StatefulWidget {
  final Future<List<T>> Function(String text) onSearch;
  final List<T> suggestions;
  final Widget Function(T item, int index)? buildSuggestion;
  final int minimumChars;
  final Widget Function(T item, int index) onItemFound;
  final Widget Function(Error error)? onError;
  final Duration debounceDuration;
  final Widget loader;
  final Widget emptyWidget;
  final bool centerEmptyWidget;
  final Widget? placeHolder;
  final Widget icon;
  final Widget? header;
  final String hintText;
  final TextStyle hintStyle;
  final Color iconActiveColor;
  final TextStyle textStyle;
  final bool useCancellationWidget;
  final Widget cancellationWidget;
  final VoidCallback? onCancelled;
  final SearchBarController<T>? searchBarController;
  final bool searchOnlyOnSubmit;
  final bool enableSuggestions;
  final SearchBarStyle searchBarStyle;
  final bool shrinkWrap;
  final Axis scrollDirection;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final EdgeInsetsGeometry searchBarPadding;
  final EdgeInsetsGeometry headerPadding;
  final EdgeInsetsGeometry listPadding;
  final EdgeInsetsGeometry contentPadding;
  final Widget? leading;
  final Widget? trailing;
  final bool autoFocus;
  final FocusNode? focusNode;
  final TextEditingController? textEditingController;

  const TransitSearchBar({
    super.key,
    required this.onSearch,
    required this.onItemFound,
    this.searchBarController,
    this.minimumChars = 3,
    this.debounceDuration = const Duration(milliseconds: 500),
    this.loader = const Center(child: CircularProgressIndicator()),
    this.onError,
    this.emptyWidget = const SizedBox.shrink(),
    this.centerEmptyWidget = false,
    this.header,
    this.placeHolder,
    this.icon = const Icon(Icons.search),
    this.hintText = '',
    this.hintStyle =
        const TextStyle(color: Color.fromRGBO(142, 142, 147, 1)),
    this.iconActiveColor = Colors.black,
    this.textStyle = const TextStyle(color: Colors.black),
    this.useCancellationWidget = true,
    this.cancellationWidget = const Text('Cancel'),
    this.onCancelled,
    this.suggestions = const [],
    this.buildSuggestion,
    this.searchOnlyOnSubmit = false,
    this.enableSuggestions = true,
    this.searchBarStyle = const SearchBarStyle(),
    this.shrinkWrap = false,
    this.scrollDirection = Axis.vertical,
    this.mainAxisSpacing = 0.0,
    this.crossAxisSpacing = 0.0,
    this.listPadding = const EdgeInsets.all(0),
    this.contentPadding = const EdgeInsets.all(0),
    this.searchBarPadding = const EdgeInsets.all(0),
    this.headerPadding = const EdgeInsets.all(0),
    this.leading,
    this.trailing,
    this.autoFocus = false,
    this.focusNode,
    this.textEditingController,
  });

  @override
  State<TransitSearchBar<T>> createState() => _TransitSearchBarState<T>();
}

class _TransitSearchBarState<T> extends State<TransitSearchBar<T>>
    with TickerProviderStateMixin, _ControllerListener<T> {
  bool _loading = false;
  Widget? _error;
  bool _firstLaunch = true;
  late FocusNode _searchQueryFocusNode;
  late TextEditingController _searchQueryController;
  Timer? _debounce;
  bool _animate = false;
  List<T> _list = [];
  late SearchBarController<T> searchBarController;

  @override
  void initState() {
    super.initState();
    searchBarController =
        widget.searchBarController ?? SearchBarController<T>();
    searchBarController.setListener(this);
    _searchQueryFocusNode = widget.focusNode ?? FocusNode();
    _searchQueryController =
        widget.textEditingController ?? TextEditingController();
    searchBarController.setTextController(
        _searchQueryController, widget.minimumChars);
  }

  @override
  void onListChanged(List<T> items) {
    setState(() {
      _loading = false;
      _list = items;
    });
  }

  @override
  void onLoading() {
    setState(() {
      _loading = true;
      _error = null;
      _animate = true;
    });
  }

  @override
  void onClear() {
    _cancel();
  }

  @override
  void onError(Error error) {
    setState(() {
      _loading = false;
      _error =
          widget.onError != null ? widget.onError!(error) : const Text('error');
    });
  }

  void _onTextChanged(String newText) {
    _debounce?.cancel();
    _debounce = Timer(widget.debounceDuration, () {
      if (newText.length >= widget.minimumChars) {
        searchBarController._search(newText, widget.onSearch);
      } else {
        setState(() {
          _list.clear();
          _error = null;
          _loading = false;
          _animate = false;
        });
      }
    });
  }

  void _cancel() {
    widget.onCancelled?.call();
    setState(() {
      _searchQueryController.clear();
      _list.clear();
      _error = null;
      _loading = false;
      _animate = false;
    });
  }

  Widget _buildListView(
      List<T> items, Widget Function(T item, int index) builder) {
    return Padding(
      padding: widget.listPadding,
      child: ListView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: widget.shrinkWrap,
        scrollDirection: widget.scrollDirection,
        itemCount: items.length,
        itemBuilder: (context, index) => builder(items[index], index),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_error != null) return _error!;
    if (_loading) return widget.loader;

    if (_searchQueryController.text.length < widget.minimumChars) {
      if (widget.placeHolder != null) return widget.placeHolder!;
      return _buildListView(
          widget.suggestions, widget.buildSuggestion ?? widget.onItemFound);
    }

    if (_list.isNotEmpty) return _buildListView(_list, widget.onItemFound);

    return widget.centerEmptyWidget
        ? Center(child: widget.emptyWidget)
        : widget.emptyWidget;
  }

  @override
  Widget build(BuildContext context) {
    if (_firstLaunch && widget.autoFocus) {
      _firstLaunch = false;
      final String currentQuery = _searchQueryController.text;
      if (currentQuery.length >= widget.minimumChars) {
        searchBarController._search(currentQuery, widget.onSearch);
      }
      FocusScope.of(context).requestFocus(_searchQueryFocusNode);
    }

    final double widthMax = MediaQuery.of(context).size.width;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration:
              BoxDecoration(color: widget.searchBarStyle.surroundingColor),
          child: Padding(
            padding: _list.isNotEmpty
                ? const EdgeInsets.fromLTRB(10, 35, 10, 0)
                : widget.searchBarPadding,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Flexible(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: widget.searchBarStyle.searchBarHeight,
                    width: _animate ? widthMax * .8 : widthMax,
                    decoration: BoxDecoration(
                      borderRadius: widget.searchBarStyle.borderRadius,
                      color: widget.searchBarStyle.backgroundColor,
                      border: Border.all(color: Colors.black12, width: 1.0),
                    ),
                    child: Padding(
                      padding: widget.searchBarStyle.padding,
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          primaryColor: widget.iconActiveColor,
                        ),
                        child: TextField(
                          focusNode: _searchQueryFocusNode,
                          controller: _searchQueryController,
                          onChanged: widget.searchOnlyOnSubmit
                              ? null
                              : _onTextChanged,
                          onSubmitted: widget.searchOnlyOnSubmit
                              ? _onTextChanged
                              : null,
                          style: widget.textStyle,
                          autocorrect: widget.enableSuggestions,
                          enableSuggestions: widget.enableSuggestions,
                          textInputAction: TextInputAction.unspecified,
                          decoration: InputDecoration(
                            contentPadding:
                                const EdgeInsets.fromLTRB(0, 5, 0, 0),
                            icon: widget.icon,
                            border: InputBorder.none,
                            hintText: widget.hintText,
                            hintStyle: widget.hintStyle,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _cancel,
                  child: AnimatedOpacity(
                    opacity: _animate ? 1.0 : 0,
                    curve: Curves.easeIn,
                    duration:
                        Duration(milliseconds: _animate ? 1000 : 0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: _animate ? widthMax * .2 : 0,
                      child: Container(
                        color: Colors.transparent,
                        child: Center(child: widget.cancellationWidget),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: widget.headerPadding,
          child: widget.header ?? const SizedBox.shrink(),
        ),
        Expanded(
          child: Padding(
            padding: widget.contentPadding,
            child: _buildContent(context),
          ),
        ),
      ],
    );
  }
}
