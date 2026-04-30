import 'package:flutter/material.dart';
import 'package:transitapp/models/Trip.dart';
import 'package:transitapp/util/TransitUtil.dart';

class WaitTimesSheet extends StatefulWidget {
  final String routeNo;
  final bool loading;
  final List<Trip> trips;
  final bool isDarkMode;
  final VoidCallback onDismiss;

  const WaitTimesSheet({
    super.key,
    required this.routeNo,
    required this.loading,
    required this.trips,
    required this.isDarkMode,
    required this.onDismiss,
  });

  @override
  WaitTimesSheetState createState() => WaitTimesSheetState();
}

class WaitTimesSheetState extends State<WaitTimesSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> dismiss() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  static const _acronyms = {'UBC', 'SFU', 'VCC', 'YVR', 'BCIT', 'NW'};

  String _toTitleCase(String s) {
    return s.split(' ').map((word) {
      if (word.isEmpty) return word;
      if (_acronyms.contains(word)) return word;
      return word.split('-').map((part) {
        if (part.isEmpty) return part;
        if (_acronyms.contains(part)) return part;
        return '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}';
      }).join('-');
    }).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDarkMode
        ? colorFromHex('1b2336').withAlpha(252)
        : Colors.white.withAlpha(252);
    final textColor =
        widget.isDarkMode ? Colors.white70 : colorFromHex('#0d2036');
    final dividerColor = widget.isDarkMode
        ? Colors.white.withAlpha(20)
        : Colors.black.withAlpha(18);

    return SlideTransition(
      position: _slide,
      child: DraggableScrollableSheet(
        initialChildSize: 0.4,
        minChildSize: 0.2,
        maxChildSize: 0.8,
        builder: (context, scrollController) {
          return Container(
            color: Colors.transparent,
            child: Stack(clipBehavior: Clip.none, children: [
              Container(
                margin: const EdgeInsets.fromLTRB(0, 50, 0, 0),
                color: bg,
                child: widget.loading
                    ? const Center(child: CircularProgressIndicator())
                    : widget.trips.isEmpty
                        ? Center(
                            child: Text(
                              'No upcoming departures',
                              style:
                                  TextStyle(color: textColor, fontSize: 18),
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: widget.trips.length,
                            separatorBuilder: (_, __) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: dividerColor),
                            ),
                            itemBuilder: (_, index) {
                              final trip = widget.trips[index];
                              final isLive = trip.LastUpdate != null &&
                                  trip.LastUpdate!.isNotEmpty;
                              return ListTile(
                                title: Row(
                                  children: [
                                    SizedBox(
                                      width: 90,
                                      child: Text(
                                        trip.ExpectedLeaveTime ?? '',
                                        style: TextStyle(
                                          color: textColor,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        _toTitleCase(trip.Destination ?? ''),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: textColor,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    if (isLive)
                                      const Icon(Icons.rss_feed,
                                          size: 16, color: Color(0xFF1bab65))
                                    else
                                      const SizedBox.shrink(),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
              Positioned(
                left: 16,
                top: -4,
                child: Text(
                  widget.routeNo,
                  style: TextStyle(
                    color: widget.isDarkMode ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w800,
                    fontSize: 54,
                    height: 1.0,
                  ),
                ),
              ),
              Positioned(
                right: 7,
                top: -7,
                child: SizedBox(
                  height: 50,
                  width: 50,
                  child: FittedBox(
                    child: FloatingActionButton(
                      heroTag: 'closeWaitTimes',
                      shape: const CircleBorder(),
                      elevation: 1,
                      onPressed: dismiss,
                      backgroundColor: widget.isDarkMode
                          ? const Color.fromRGBO(50, 52, 58, 1)
                          : const Color.fromRGBO(255, 255, 255, 0.95),
                      child: Icon(
                        Icons.close,
                        size: 22,
                        color: widget.isDarkMode
                            ? Colors.white70
                            : Colors.black54,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: MediaQuery.of(context).viewPadding.bottom,
                child: GestureDetector(behavior: HitTestBehavior.opaque),
              ),
            ]),
          );
        },
      ),
    );
  }
}
