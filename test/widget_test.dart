import 'package:flutter_test/flutter_test.dart';
import 'package:journal/core/auth/pin_hasher.dart';
import 'package:journal/core/formatters.dart';

void main() {
  test('journal completion requires strategy, emotion, notes and checklist', () {
    expect(
      journalIsComplete(
        strategyId: 's1',
        emotion: 'Calm',
        notes: 'Followed plan',
        checklistStarted: true,
      ),
      isTrue,
    );
    expect(
      journalIsComplete(
        strategyId: null,
        emotion: 'Calm',
        notes: 'Followed plan',
        checklistStarted: true,
      ),
      isFalse,
    );
  });

  test('signed money keeps a visible win/loss label companion', () {
    expect(signedMoney(120.5), contains('+'));
    expect(signedMoney(-45.3), contains('-'));
  });

  test('PIN must be six digits and hashes consistently', () {
    expect(PinHasher.isValid('123456'), isTrue);
    expect(PinHasher.isValid('12345'), isFalse);
    expect(PinHasher.isValid('12345a'), isFalse);
    final salt = PinHasher.createSalt();
    final hash = PinHasher.hash('123456', salt);
    expect(PinHasher.matches(pin: '123456', salt: salt, expectedHash: hash), isTrue);
    expect(PinHasher.matches(pin: '000000', salt: salt, expectedHash: hash), isFalse);
  });
}
