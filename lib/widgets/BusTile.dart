import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:transitapp/models/BothDirectionRouteWithTrips.dart';
import 'package:transitapp/models/Trip.dart';
import 'package:transitapp/util/TransitUtil.dart';

class BusTile extends StatefulWidget {
  final BothDirectionRouteWithTrips route;
  final int carouselIndex;
  final bool isDarkMode;
  final void Function(int) onCarouselChanged;
  final void Function(String routeNo, String pattern, String stopNo) onTap;

  const BusTile({
    super.key,
    required this.route,
    required this.carouselIndex,
    required this.isDarkMode,
    required this.onCarouselChanged,
    required this.onTap,
  });

  @override
  State<BusTile> createState() => _BusTileState();
}

class _BusTileState extends State<BusTile> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Tween<double>? _snapTween;
  VoidCallback? _pendingOnDone;
  double _dragOffset = 0.0;
  double _tileWidth = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _controller.addListener(() {
      final tween = _snapTween;
      if (tween != null) {
        setState(() {
          _dragOffset = tween.evaluate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOut),
          );
        });
      }
    });
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _pendingOnDone?.call();
        _pendingOnDone = null;
        _snapTween = null;
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _snapTo(double target, {VoidCallback? onDone}) {
    _pendingOnDone = onDone;
    _snapTween = Tween(begin: _dragOffset, end: target);
    _controller.stop();
    _controller.reset();
    _controller.forward();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _controller.stop();
    setState(() => _dragOffset += details.delta.dx);
  }

  void _onDragEnd(DragEndDetails details) {
    final v = details.primaryVelocity ?? 0;
    final trips = widget.route.Trips;
    final goNext = (v < -300 || _dragOffset < -_tileWidth / 2) &&
        widget.carouselIndex < trips.length - 1;
    final goPrev = (v > 300 || _dragOffset > _tileWidth / 2) &&
        widget.carouselIndex > 0;

    if (goNext) {
      _snapTo(-_tileWidth, onDone: () {
        setState(() => _dragOffset = 0);
        widget.onCarouselChanged(widget.carouselIndex + 1);
      });
    } else if (goPrev) {
      _snapTo(_tileWidth, onDone: () {
        setState(() => _dragOffset = 0);
        widget.onCarouselChanged(widget.carouselIndex - 1);
      });
    } else {
      _snapTo(0);
    }
  }

  Widget _buildSlide(Trip trip) {
    final String routeNo = removeLeadingZeros(widget.route.RouteNo);
    final timeColor = widget.isDarkMode ? Colors.white70 : colorFromHex('#10295D');
    final countdown = trip.ExpectedCountdown ?? 0;

    Widget countdownWidget;
    if (countdown >= 60) {
      final parts = (trip.ExpectedLeaveTime ?? '').split(' ');
      final timeStr = parts.isNotEmpty ? parts[0] : '';
      final period = parts.length > 1 ? parts[1] : '';
      countdownWidget = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(timeStr,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                  color: timeColor)),
          Text(period,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w300,
                  color: timeColor.withValues(alpha: 0.6))),
        ],
      );
    } else {
      countdownWidget = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$countdown',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: countdown.toString().length < 3 ? 32 : 26,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                  color: timeColor)),
          Text('minutes',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w300,
                  color: timeColor.withValues(alpha: 0.6))),
        ],
      );
    }

    return InkWell(
      onTap: () =>
          widget.onTap(widget.route.RouteNo, trip.Pattern ?? '', trip.StopNo ?? ''),
      child: SizedBox(
        height: 76,
        child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SizedBox(
              width: 70,
              child: Text(routeNo,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: routeNo.length < 3 ? 50 : 35,
                      height: 1.0,
                      fontWeight: FontWeight.w700,
                      color: timeColor)),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AutoSizeText(trip.Destination ?? '',
                        textAlign: TextAlign.left,
                        maxLines: 2,
                        minFontSize: 10,
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                            color: widget.isDarkMode
                                ? Colors.white70
                                : colorFromHex('#024D7E'))),
                    AutoSizeText(trip.nextStop ?? '',
                        textAlign: TextAlign.left,
                        maxLines: 2,
                        minFontSize: 10,
                        style: TextStyle(
                            fontSize: 15,
                            height: 1.2,
                            fontWeight: FontWeight.w400,
                            color: colorFromHex('1bab65'))),
                  ],
                ),
              ),
            ),
            SizedBox(width: 65, child: countdownWidget),
          ],
        ),
      ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trips = widget.route.Trips;
    final idx = widget.carouselIndex;

    return Column(
      children: [
        GestureDetector(
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          child: LayoutBuilder(builder: (context, constraints) {
            _tileWidth = constraints.maxWidth;
            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                // Current slide — not Positioned, so it drives the Stack height.
                Transform.translate(
                  offset: Offset(_dragOffset, 0),
                  child: _buildSlide(trips[idx]),
                ),
                // Previous slide — Positioned so it doesn't affect Stack height.
                if (idx > 0)
                  Positioned(
                    left: 0,
                    top: 0,
                    width: _tileWidth,
                    child: Transform.translate(
                      offset: Offset(-_tileWidth + _dragOffset, 0),
                      child: _buildSlide(trips[idx - 1]),
                    ),
                  ),
                // Next slide — same.
                if (idx < trips.length - 1)
                  Positioned(
                    left: 0,
                    top: 0,
                    width: _tileWidth,
                    child: Transform.translate(
                      offset: Offset(_tileWidth + _dragOffset, 0),
                      child: _buildSlide(trips[idx + 1]),
                    ),
                  ),
              ],
            );
          }),
        ),
        if (trips.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: trips.asMap().entries.map((entry) {
              final bool isActive = idx == entry.key;
              return Container(
                width: 6.0,
                height: 5.0,
                margin: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 2.0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive
                      ? (widget.isDarkMode
                          ? const Color.fromRGBO(255, 255, 255, 0.3)
                          : const Color.fromRGBO(0, 0, 0, 0.3))
                      : (widget.isDarkMode
                          ? const Color.fromRGBO(255, 255, 255, 0.15)
                          : const Color.fromRGBO(0, 0, 0, 0.15)),
                ),
              );
            }).toList(),
          ),
        Divider(color: Theme.of(context).primaryColor),
      ],
    );
  }
}
