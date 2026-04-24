import 'dart:async';
import 'package:flutter/material.dart';
import 'models/Stop.dart';

class StopSearchBarController {
  StopSearchBarState? _state;

  void clear() {
    final s = _state;
    if (s != null && s.mounted) s._clearState();
  }
}

class StopSearchBar extends StatefulWidget {
  final Future<List<Stop>> Function(String) onSearch;
  final Widget Function(Stop, int) onItemFound;
  final Widget emptyWidget;
  final VoidCallback? onCancelled;
  final String hintText;
  final EdgeInsetsGeometry padding;
  final StopSearchBarController? controller;

  const StopSearchBar({
    super.key,
    required this.onSearch,
    required this.onItemFound,
    this.emptyWidget = const SizedBox.shrink(),
    this.onCancelled,
    this.hintText = '',
    this.padding = const EdgeInsets.fromLTRB(10, 20, 10, 0),
    this.controller,
  });

  @override
  State<StopSearchBar> createState() => StopSearchBarState();
}

class StopSearchBarState extends State<StopSearchBar> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  List<Stop> _results = [];
  bool _loading = false;
  bool _active = false;

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
  }

  // Called by the cancel button — also dismisses the keyboard.
  void _cancelTapped() {
    _focusNode.unfocus();
    _clearState();
    widget.onCancelled?.call();
  }

  // Called externally via controller — safe to call from any context.
  void _clearState() {
    _debounce?.cancel();
    _textController.clear();
    if (mounted) {
      setState(() {
        _results = [];
        _active = false;
        _loading = false;
      });
    }
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    if (text.isEmpty) {
      setState(() {
        _results = [];
        _active = false;
        _loading = false;
      });
      return;
    }
    setState(() {
      _active = true;
      _loading = true;
    });
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final results = await widget.onSearch(text);
      if (mounted) setState(() { _results = results; _loading = false; });
    });
  }

  @override
  void dispose() {
    widget.controller?._state = null;
    _debounce?.cancel();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: widget.padding,
          child: Row(
            children: [
              Flexible(
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.black12),
                  ),
                  padding: const EdgeInsets.fromLTRB(10, 0, 0, 0),
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    onChanged: _onChanged,
                    style: const TextStyle(fontSize: 18),
                    decoration: InputDecoration(
                      icon: const Icon(Icons.search),
                      border: InputBorder.none,
                      hintText: widget.hintText,
                      hintStyle: const TextStyle(
                        color: Color.fromRGBO(142, 142, 147, 1),
                      ),
                      contentPadding: const EdgeInsets.fromLTRB(0, 5, 0, 0),
                    ),
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: _active
                    ? GestureDetector(
                        onTap: _cancelTapped,
                        child: const Padding(
                          padding: EdgeInsets.only(left: 10),
                          child: Text('Cancel'),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
        Expanded(
          child: IgnorePointer(
            ignoring: !_active,
            child: ColoredBox(
              color: _active ? Colors.white : Colors.transparent,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isNotEmpty
                      ? ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: _results.length,
                          itemBuilder: (context, index) =>
                              widget.onItemFound(_results[index], index),
                        )
                      : _active
                          ? Center(child: widget.emptyWidget)
                          : const SizedBox.shrink(),
            ),
          ),
        ),
      ],
    );
  }
}
