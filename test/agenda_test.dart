import 'package:flutter_test/flutter_test.dart';
import 'package:memorize/agenda.dart';
import 'package:memorize/lexicon.dart';
import 'package:memorize/sm.dart';

void main() {
  test('', () {
    final agenda = Agenda();
    final item1 = LexiconItem(0, sm2: const SM2(repetitions: 0, interval: 1));
    final item2 = LexiconItem(1, sm2: const SM2(repetitions: 1, interval: 1));
    final item3 =
        LexiconItem(2, sm2: const SM2(repetitions: 10, interval: 100));

    agenda.schedule(item1);
    agenda.schedule(item2);
    agenda.schedule(item3);

    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final futureRep = DateTime.now().add(const Duration(days: 100));

    printOnFailure(agenda.toString());
    expect(agenda[tomorrow], equals({item1, item2}));
    expect(agenda[futureRep], equals({item3}));

    agenda.unschedule(item1);

    expect(agenda[tomorrow], equals({item2}));
    expect(agenda.getTime(item1), isNull);
    expect(agenda.getTime(item2), equals(tomorrow.dayOnly));
    expect(agenda.getTime(item3), equals(futureRep.dayOnly));

    agenda.adjustSchedule(DateTime.now().add(const Duration(days: 2)));
    expect(agenda.getTime(item2),
        equals(tomorrow.dayOnly.add(const Duration(days: 1))));
    expect(agenda.getTime(item3), equals(futureRep.dayOnly));
  });
}
