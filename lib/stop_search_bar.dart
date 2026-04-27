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
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
    _textController.addListener(() {
      setState(() {
        _isTyping = _textController.text.isNotEmpty;
      });
    });
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
      if (mounted)
        setState(() {
          _results = results;
          _loading = false;
        });
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
    final isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final containerColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final borderColor = isDark ? Colors.white24 : Colors.black12;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ColoredBox(
          color: _active ? bgColor : Colors.transparent,
          child: Padding(
            padding: widget.padding,
            child: Row(
              children: [
                Flexible(
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: containerColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (!_isTyping)
                          Padding(
                            padding: const EdgeInsets.only(left: 16, right: 4),
                            child: Icon(Icons.search, color: isDark ? Colors.white70 : null),
                          ),
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            focusNode: _focusNode,
                            onChanged: _onChanged,
                            style: TextStyle(fontSize: 18, color: isDark ? Colors.white : null),
                            decoration: InputDecoration(
                              hintText: _isTyping ? '' : widget.hintText,
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.fromLTRB(
                                _isTyping ? 16 : 0,
                                0, 0, 0,
                              ),
                              isCollapsed: true,
                              hintStyle: const TextStyle(
                                color: Color.fromRGBO(142, 142, 147, 1),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  child: _active
                      ? GestureDetector(
                          onTap: _cancelTapped,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 10),
                            child: Text(
                              'Cancel',
                              style: TextStyle(color: isDark ? Colors.white : null),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: IgnorePointer(
            ignoring: !_active,
            child: ColoredBox(
              color: _active ? bgColor : Colors.transparent,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isNotEmpty
                      ? Theme(
                          data: Theme.of(context).copyWith(
                            listTileTheme: ListTileThemeData(
                              textColor: isDark ? Colors.white : null,
                              subtitleTextStyle: TextStyle(
                                color: isDark ? Colors.white60 : null,
                              ),
                            ),
                          ),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: _results.length,
                            itemBuilder: (context, index) =>
                                widget.onItemFound(_results[index], index),
                          ),
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
