import 'dart:developer' as dev;

enum OfflineEvent { signOut, updateSettings }

class OfflineLogger {
  OfflineLogger({this.onChange}) : _eventStack = [];
  OfflineLogger.fromJson(Map<String, dynamic> json, {this.onChange})
      : _eventStack = List<OfflineEvent>.from(json['events'].map(
          (e) => OfflineEvent.values[e],
        ));

  final List<OfflineEvent> _eventStack;

  bool get isEmpty => _eventStack.isEmpty;
  bool get isNotEmpty => _eventStack.isNotEmpty;
  int get length => _eventStack.length;
  final dynamic Function(OfflineLogger logger)? onChange;

  Map<String, dynamic> toJson() =>
      {'events': _eventStack.map((e) => e.index).toList()};

  void add(OfflineEvent event) {
    dev.log('Add offline event: ${event.name}', name: 'OfflineLogger.add');

    _eventStack.add(event);
    if (onChange != null) onChange!(this);
  }

  OfflineEvent pop() {
    final ret = _eventStack.removeLast();
    if (onChange != null) onChange!(this);

    dev.log('Pop offline event: ${ret.name}', name: 'OfflineLogger.pop');

    return ret;
  }
}
