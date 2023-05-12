/// Algorithm SM-2, (C) Copyright SuperMemo World, 1991.
///   https://www.supermemo.com
///   https://www.supermemo.eu

import 'package:equatable/equatable.dart';

class SM2 extends Equatable {
  const SM2({this.repetitions = 0, this.interval = 0, this.easeFactor = 2.5});

  final int repetitions;
  final int interval;
  final double easeFactor;

  @override
  List<Object?> get props => [repetitions, interval, easeFactor];

  int _computeInterval(int repetitions) {
    switch (repetitions) {
      case 0:
        return 1;
      case 1:
        return 6;
      default:
        return (interval * easeFactor).round();
    }
  }

  SM2 compute(int quality) {
    SM2 sm;

    if (quality >= 3) {
      final ef =
          easeFactor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));

      sm = SM2(
        repetitions: repetitions + 1,
        interval: _computeInterval(repetitions),
        easeFactor: ef.clamp(1.3, double.infinity),
      );
    } else {
      sm = SM2(repetitions: 0, interval: 1, easeFactor: easeFactor);
    }

    assert(sm.interval != 0);

    return sm;
  }
}
