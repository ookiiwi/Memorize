import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:memorize/agenda.dart';
import 'package:memorize/app_constants.dart';
import 'package:memorize/memo_list.dart';
import 'package:memorize/views/explorer.dart';

class AgendaViewer extends StatefulWidget {
  const AgendaViewer({super.key});

  @override
  State<StatefulWidget> createState() => _AgendaViewer();
}

class _AgendaViewer extends State<AgendaViewer> {
  final dateFormat = DateFormat.yMMMMd();
  final date = ValueNotifier(DateTime.now().dayOnly);
  final _pageController = PageController();

  @override
  void initState() {
    super.initState();

    agenda.adjustSchedule();
  }

  @override
  void dispose() {
    _pageController.dispose();

    super.dispose();
  }

  DateTime _computeDate(int page) =>
      DateUtils.addDaysToDate(DateTime.now(), page);

  @override
  Widget build(BuildContext context) {
    print('agenda: $agenda');

    return Scaffold(
      appBar: AppBar(
        title: TextButton(
          onPressed: () {
            showDialog(
                context: context,
                builder: (context) {
                  return Dialog(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: DatePicker(
                        date: date.value,
                        onAction: (date) {
                          if (date != null) {
                            _pageController.jumpToPage(
                              date.dayOnly
                                  .difference(DateTime.now().dayOnly)
                                  .inDays,
                            );
                          }

                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                  );
                });
          },
          child: ValueListenableBuilder<DateTime>(
            valueListenable: date,
            builder: (context, value, child) {
              return Text(
                dateFormat.format(value).toString(),
                style: const TextStyle(fontSize: 20),
              );
            },
          ),
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton(
              position: PopupMenuPosition.under,
              offset: const Offset(0, 15),
              itemBuilder: (context) {
                return [
                  if (kDebugMode)
                    PopupMenuItem(
                      onTap: () {
                        setState(() => agenda.clear());
                        saveAgenda();
                      },
                      child: const Text('Clear'),
                    ),
                  if (kDebugMode)
                    PopupMenuItem(
                      onTap: () {
                        setState(() => agenda.clear());
                        saveAgenda();
                      },
                      child: const Text('Clear (with SM2 data)'),
                    ),
                ];
              })
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (value) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => date.value = _computeDate(value));
        },
        itemBuilder: (context, page) {
          final today = agenda[_computeDate(page)].entries;

          if (today.isEmpty) {
            return const Center(child: Text('>@_@<'));
          }

          return ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.only(
              top: 10,
              bottom: kBottomNavigationBarHeight,
              left: 10,
              right: 10,
            ),
            itemCount: today.length,
            itemBuilder: (context, i) {
              final elt = today.elementAt(i);
              final list = MemoList.open(elt.key);

              return ExplorerItem(
                list: list,
                onTap: () {
                  context.push('/quiz_launcher', extra: {
                    'listpath': elt.key,
                    'items': elt.value.toList(),
                  });
                },
              );
            },
          );
        },
      ),
    );
  }
}

class DatePicker extends StatefulWidget {
  const DatePicker({super.key, this.date, this.onAction});

  final DateTime? date;
  final void Function(DateTime? date)? onAction;

  @override
  State<StatefulWidget> createState() => _DatePicker();
}

class _DatePicker extends State<DatePicker> {
  final dateFormat = DateFormat.yMMMM();
  late DateTime date = widget.date ?? DateTime.now();
  late DateTime navDate = date.copyWith();
  final _showDays = ValueNotifier(true);
  PageController? _daysPageController;
  final _daysPageTransitionDuration = const Duration(milliseconds: 200);
  final _daysPageTransitionCurve = Curves.easeInOut;

  @override
  void dispose() {
    _daysPageController?.dispose();

    super.dispose();
  }

  Widget buildNavBtn(BuildContext context, Widget child) {
    return ValueListenableBuilder<bool>(
        valueListenable: _showDays,
        builder: (context, value, _) {
          if (!value) return const Spacer();

          return child;
        });
  }

  void _addMonthToDate(int monthsToAdd) {
    final newDate = DateUtils.addMonthsToMonthDate(navDate, monthsToAdd);
    final today = DateTime.now();

    if (monthsToAdd.isNegative &&
        newDate.year <= today.year &&
        newDate.month < today.month) return;

    if (monthsToAdd.isNegative) {
      _daysPageController?.previousPage(
        duration: _daysPageTransitionDuration,
        curve: _daysPageTransitionCurve,
      );
    } else {
      _daysPageController?.nextPage(
        duration: _daysPageTransitionDuration,
        curve: _daysPageTransitionCurve,
      );
    }

    setState(() => navDate = newDate);
  }

  Widget buildDayWheel(BuildContext context) {
    final daysInMonth = DateUtils.getDaysInMonth(date.year, date.month);

    return PageView.builder(
      scrollDirection: Axis.vertical,
      controller:
          PageController(initialPage: date.day - 1, viewportFraction: 1 / 3),
      onPageChanged: (value) =>
          setState(() => date = date.copyWith(day: value % daysInMonth + 1)),
      itemBuilder: (context, page) {
        final day = page % daysInMonth + 1;
        final isSelected = date.day == day;

        return Center(
          child: Text(
            '$day${day < 10 ? ' ' : ''}',
            style: TextStyle(
              fontSize: 20,
              color: !isSelected ? Colors.grey : null,
              fontWeight: isSelected ? FontWeight.bold : null,
            ),
          ),
        );
      },
    );
  }

  Widget buildMonthWheel(BuildContext context) {
    final monthFormatAbbr = DateFormat.MMM();
    final monthFormat = DateFormat.MMMM();

    return PageView.builder(
      scrollDirection: Axis.vertical,
      controller:
          PageController(initialPage: date.month - 1, viewportFraction: 1 / 3),
      onPageChanged: (value) =>
          setState(() => date = date.copyWith(month: value % 12 + 1)),
      itemBuilder: (context, page) {
        final month = page % 12 + 1;
        final monthStr = monthFormat.format(date.copyWith(month: month));
        final monthStrAbbr =
            monthFormatAbbr.format(date.copyWith(month: month));
        final isSelected = month == date.month;

        return Center(
          child: Text(
            '$monthStrAbbr${monthStr != monthStrAbbr ? '.' : ''}',
            style: TextStyle(
              fontSize: 20,
              color: !isSelected ? Colors.grey : null,
              fontWeight: isSelected ? FontWeight.bold : null,
            ),
          ),
        );
      },
    );
  }

  Widget buildYearWheel(BuildContext context) {
    final currYear = DateTime.now().year;

    return PageView.builder(
      scrollDirection: Axis.vertical,
      controller: PageController(
          initialPage: date.year - currYear, viewportFraction: 1 / 3),
      onPageChanged: (value) =>
          setState(() => date = date.copyWith(year: currYear + value)),
      itemBuilder: (context, page) {
        final isSelected = (date.year - page) == currYear;

        return Center(
          child: Text(
            '${currYear + page}',
            style: TextStyle(
              fontSize: 20,
              color: !isSelected ? Colors.grey : null,
              fontWeight: isSelected ? FontWeight.bold : null,
            ),
          ),
        );
      },
    );
  }

  Widget buildWheel(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(child: buildDayWheel(context)),
        Expanded(child: buildMonthWheel(context)),
        Expanded(child: buildYearWheel(context)),
      ],
    );
  }

  Widget buildDays(BuildContext context) {
    final dateFormat = DateFormat.E();

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (int i = 0; i < 7; ++i)
              SizedBox(
                height: 20,
                child: Text('${dateFormat.format(DateTime(1, 1, i + 1))}.'),
              ),
          ],
        ),
        Expanded(
          child: PageView.builder(
              controller: _daysPageController,
              onPageChanged: (value) => navDate =
                  DateUtils.addMonthsToMonthDate(DateTime.now(), value),
              itemBuilder: (context, index) {
                final pageDate =
                    DateUtils.addMonthsToMonthDate(DateTime.now(), index);

                var startingDate = pageDate.copyWith(day: 2);

                do {
                  startingDate = DateUtils.addDaysToDate(startingDate, -1);
                } while (dateFormat.format(startingDate) != 'Mon');

                Widget buildDay(int i) {
                  final day = DateUtils.addDaysToDate(startingDate, i);
                  final isSelected = day == date && day.month == pageDate.month;

                  return TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.all(0.0),
                      backgroundColor: isSelected ? Colors.amber : null,
                    ),
                    onPressed: () {
                      navDate = day;
                      date = day;

                      if (day.month < pageDate.month) {
                        _daysPageController?.previousPage(
                          duration: _daysPageTransitionDuration,
                          curve: _daysPageTransitionCurve,
                        );
                      } else if (day.month > pageDate.month) {
                        _daysPageController?.nextPage(
                          duration: _daysPageTransitionDuration,
                          curve: _daysPageTransitionCurve,
                        );
                      } else {
                        setState(() {});
                      }
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox.square(dimension: 5),
                        Text(
                          '${day.day}',
                          style: TextStyle(
                            color: day.month != pageDate.month
                                ? Colors.black.withOpacity(0.5)
                                : null,
                          ),
                        ),
                        Container(
                          height: 5,
                          width: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: agenda[day.dayOnly].isNotEmpty
                                ? Colors.red
                                : null,
                          ),
                        )
                      ],
                    ),
                  );
                }

                return GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 7,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [for (int i = 0; i < 42; ++i) buildDay(i)],
                );
              }),
        ),
      ],
    );
  }

  void _onAction([DateTime? date]) {
    if (widget.onAction != null) {
      widget.onAction!(date);
    }
  }

  Widget buildDateButton(BuildContext context) {
    return TextButton(
      onPressed: () => _showDays.value = !_showDays.value,
      child: Text(
        dateFormat.format(_showDays.value ? navDate : date).toString(),
        style: const TextStyle(fontSize: 20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            buildNavBtn(
              context,
              IconButton(
                onPressed: () => _addMonthToDate(-1),
                icon: const Icon(Icons.arrow_back_ios_rounded),
              ),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: _showDays,
              builder: (context, value, child) {
                _daysPageController?.dispose();
                _daysPageController = null;

                if (value) {
                  _daysPageController ??= PageController(
                    initialPage: DateUtils.monthDelta(DateTime.now(), date),
                  );

                  return AnimatedBuilder(
                    animation: _daysPageController!,
                    builder: (context, child) => buildDateButton(context),
                  );
                }

                return buildDateButton(context);
              },
            ),
            buildNavBtn(
              context,
              IconButton(
                onPressed: () => _addMonthToDate(1),
                icon: const Icon(Icons.arrow_forward_ios_rounded),
              ),
            ),
          ],
        ),
        Container(
          height: 300,
          padding: const EdgeInsets.all(12.0),
          child: ValueListenableBuilder<bool>(
            valueListenable: _showDays,
            builder: (context, value, child) {
              if (value) {
                return buildDays(context);
              }

              return buildWheel(context);
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton(
              onPressed: () => _onAction(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => _onAction(date),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ],
    );
  }
}
