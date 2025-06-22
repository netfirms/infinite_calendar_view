import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:infinite_calendar_view/src/controller/events_controller.dart';
import 'package:infinite_calendar_view/src/events/event.dart';
import 'package:infinite_calendar_view/src/events_months.dart';
import 'package:infinite_calendar_view/src/utils/default_text.dart';
import 'package:infinite_calendar_view/src/utils/event_helder.dart';
import 'package:infinite_calendar_view/src/utils/extension.dart';
import 'package:infinite_calendar_view/src/widgets/month/day.dart';

class Week extends StatefulWidget {
  const Week({
    super.key,
    required this.controller,
    required this.weekParam,
    required this.weekHeight,
    required this.daysParam,
    required this.startOfWeek,
    required this.maxEventsShowed,
  });

  final DateTime startOfWeek;
  final WeekParam weekParam;
  final double weekHeight;
  final DaysParam daysParam;
  final EventsController controller;
  final int maxEventsShowed;

  @override
  State<Week> createState() => _WeekState();
}

class _WeekState extends State<Week> {
  late VoidCallback eventListener;
  List<List<Event>?> weekEvents = [];
  List<List<Event?>> weekShowedEvents = [];

  @override
  void initState() {
    super.initState();
    updateEvents();
    eventListener = () => updateEvents();
    widget.controller.addListener(eventListener);
  }

  @override
  void dispose() {
    super.dispose();
    widget.controller.removeListener(eventListener);
  }

  // update day events when change
  void updateEvents() {
    if (mounted) {
      var weekEvents = getWeekEvents();
      var weekShowedEvents =
          getShowedWeekEvents(weekEvents, widget.maxEventsShowed);
      // no update if no change for current day
      if (listEquals(weekShowedEvents, this.weekShowedEvents) == false) {
        setState(() {
          this.weekEvents = weekEvents;
          this.weekShowedEvents = weekShowedEvents;
        });
      }
    }
  }

  /// find events of week
  List<List<Event>?> getWeekEvents() {
    List<List<Event>?> eventsList = [];
    for (var day = 0; day < 7; day++) {
      eventsList.add(widget.controller.getSortedFilteredDayEvents(
        widget.startOfWeek.add(Duration(days: day)),
      ));
    }
    return eventsList;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: widget.weekParam.weekDecoration ??
          WeekParam.defaultWeekDecoration(context),
      child: Container(
        height: widget.weekHeight,
        child: LayoutBuilder(builder: (context, constraints) {
          var width = constraints.maxWidth;
          var dayWidth = width / 7;

          return DragTarget(
            onAcceptWithDetails: (details) {
              var onDragEnd = details.data as Function(DateTime);
              var renderBox = context.findRenderObject() as RenderBox;
              var relativeOffset = renderBox.globalToLocal(
                  Offset(details.offset.dx + dayWidth / 2, details.offset.dy));
              var dragDay = getPositionDay(relativeOffset, dayWidth);
              onDragEnd.call(dragDay);
            },
            builder: (context, candidateData, rejectedData) {
              return GestureDetector(
                onTapDown: (details) => widget.daysParam.onDayTapDown
                    ?.call(getPositionDay(details.localPosition, dayWidth)),
                onTapUp: (details) => widget.daysParam.onDayTapUp
                    ?.call(getPositionDay(details.localPosition, dayWidth)),
                behavior: HitTestBehavior.translucent,
                child: Column(
                  children: [
                    // days header
                    Container(
                      height: widget.daysParam.headerHeight,
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          for (var dayOfWeek = 0; dayOfWeek < 7; dayOfWeek++)
                            Expanded(child: getHeaderWidget(dayOfWeek)),
                        ],
                      ),
                    ),

                    // week events
                    Container(
                      height: widget.weekHeight - widget.daysParam.headerHeight,
                      child: Stack(
                        children: [
                          for (var dayOfWeek = 0; dayOfWeek < 7; dayOfWeek++)
                            for (var eventIndex = 0;
                                eventIndex < weekShowedEvents[dayOfWeek].length;
                                eventIndex++)
                              if (eventIndex < widget.maxEventsShowed)
                                ...getEventOrMoreEventsWidget(
                                    dayOfWeek, eventIndex, dayWidth),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        }),
      ),
    );
  }

  DateTime getPositionDay(Offset localPosition, double dayWidth) {
    var x = localPosition.dx;
    var dayIndex = (x / dayWidth).toInt();
    var day = widget.startOfWeek.add(Duration(days: dayIndex));
    return day;
  }

  // get header of day
  Container getHeaderWidget(int dayOfWeek) {
    var day = widget.startOfWeek.add(Duration(days: dayOfWeek));
    var isStartOfMonth = day.day == 1;
    var colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: widget.daysParam.headerHeight,
      child: widget.daysParam.dayHeaderBuilder?.call(day) ??
          DefaultMonthDayHeader(
            text: isStartOfMonth
                ? "${defaultMonthAbrText[day.month - 1]} 1"
                : day.day.toString(),
            isToday: DateUtils.isSameDay(day, DateTime.now()),
            textColor:
                isStartOfMonth ? colorScheme.onSurface : colorScheme.outline,
          ),
    );
  }

  /// get Event widget or "More" widget
  List<Widget> getEventOrMoreEventsWidget(
    int dayOfWeek,
    int eventIndex,
    double dayWidth,
  ) {
    var daySpacing = widget.weekParam.daySpacing;
    var eventSpacing = widget.daysParam.eventSpacing;
    var eventHeight = widget.daysParam.eventHeight;
    var left = dayOfWeek * dayWidth + (daySpacing / 2);
    var eventsLength = weekEvents[dayOfWeek]?.length ?? 0;
    var day = widget.startOfWeek.add(Duration(days: dayOfWeek));

    // More widget
    var isLastSlot = eventIndex == widget.maxEventsShowed - 1;
    var notShowedEventsCount = (eventsLength - widget.maxEventsShowed) + 1;
    if (isLastSlot && notShowedEventsCount > 1) {
      return [
        Positioned(
          left: left,
          top: (widget.maxEventsShowed - 1) * (eventHeight + eventSpacing),
          width: dayWidth - daySpacing,
          height: eventHeight,
          child: widget.daysParam.dayMoreEventsBuilder
                  ?.call(notShowedEventsCount, day) ??
              DefaultNotShowedMonthEventsWidget(
                context: context,
                eventHeight: eventHeight,
                text: "$notShowedEventsCount others",
              ),
        )
      ];
    }

    // Event widget
    var event = weekShowedEvents[dayOfWeek][eventIndex];
    // Check if this event has already been rendered in a previous day of this week
    var isMultiDayOtherDay = false;
    if (event != null && event.isMultiDay) {
      // If this is not the first day of the multi-day event (daysIndex > 0),
      // we should always render it regardless of whether it's been rendered in a previous day of this week
      if (event.daysIndex != null && event.daysIndex! > 0) {
        isMultiDayOtherDay = false;
      }
      // For multi-day events that start in this week (daysIndex == 0), check if they've been rendered in a previous day of this week
      else if (dayOfWeek > 0) {
        for (var prevDay = 0; prevDay < dayOfWeek; prevDay++) {
          if (weekShowedEvents[prevDay].any((e) => e?.uniqueId == event.uniqueId)) {
            isMultiDayOtherDay = true;
            break;
          }
        }
      }
    }
    if (event != null && !isMultiDayOtherDay) {
      // multi days events duration
      var duration = 1;
      while (weekShowedEvents
              .getOrNull(dayOfWeek + duration)
              ?.getOrNull(eventIndex)
              ?.uniqueId ==
          event.uniqueId) {
        duration++;
      }
      var eventWidth = (dayWidth * duration) - daySpacing;
      var top = weekShowedEvents[dayOfWeek].indexOf(event) *
          (eventHeight + eventSpacing);
      return [
        Positioned(
            left: left,
            top: top,
            width: eventWidth,
            height: eventHeight,
            child: widget.daysParam.dayEventBuilder?.call(
                  event,
                  eventWidth,
                  eventHeight,
                ) ??
                DefaultMonthDayEvent(event: event))
      ];
    }

    return [];
  }
}
