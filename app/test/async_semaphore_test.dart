import 'package:app/services/async_semaphore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AsyncSemaphore limits concurrent runs', () async {
    final semaphore = AsyncSemaphore(2);
    var inFlight = 0;
    var maxInFlight = 0;

    Future<void> task() => semaphore.run(() async {
          inFlight++;
          maxInFlight = inFlight > maxInFlight ? inFlight : maxInFlight;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          inFlight--;
        });

    await Future.wait(List.generate(6, (_) => task()));
    expect(maxInFlight, lessThanOrEqualTo(2));
  });
}
