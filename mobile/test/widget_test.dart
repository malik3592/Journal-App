import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journal/core/auth/pin_hasher.dart';
import 'package:journal/core/formatters.dart';
import 'package:journal/features/providers.dart';
import 'package:journal/features/trades/trade_screens.dart';
import 'package:journal/shared/models/models.dart';

void main() {
  test(
    'journal completion requires strategy, emotion, notes and checklist',
    () {
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
    },
  );

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
    expect(
      PinHasher.matches(pin: '123456', salt: salt, expectedHash: hash),
      isTrue,
    );
    expect(
      PinHasher.matches(pin: '000000', salt: salt, expectedHash: hash),
      isFalse,
    );
  });

  testWidgets('incomplete trade shows only Complete journal', (tester) async {
    await _pumpDetail(tester, journalStatus: 'INCOMPLETE');
    expect(find.text('Complete journal'), findsOneWidget);
    expect(find.text('Update journal'), findsNothing);
    expect(find.text('Analyze trade'), findsNothing);
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('complete trade distinguishes Analyze from Update journal', (
    tester,
  ) async {
    await _pumpDetail(tester, journalStatus: 'COMPLETE');
    expect(find.text('Journal complete'), findsOneWidget);
    expect(find.text('Analyze trade'), findsOneWidget);
    expect(find.text('Update journal'), findsOneWidget);
    expect(find.text('Complete journal'), findsNothing);
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.byType(OutlinedButton), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(FilledButton),
        matching: find.text('Analyze trade'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(OutlinedButton),
        matching: find.text('Update journal'),
      ),
      findsOneWidget,
    );
  });
}

Future<void> _pumpDetail(
  WidgetTester tester, {
  required String journalStatus,
}) async {
  tester.view.physicalSize = const Size(400, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_detailApp(journalStatus: journalStatus));
}

Trade _sampleTrade({required String journalStatus}) {
  return Trade(
    id: 't1',
    accountId: 'a1',
    source: 'MANUAL',
    symbol: 'EURUSD',
    direction: 'BUY',
    volume: '0.10',
    entryPrice: '1.0800',
    netProfit: '12.50',
    openedAt: DateTime(2026, 9, 20),
    closedAt: DateTime(2026, 9, 20, 12),
    exitPrice: '1.0820',
    journalStatus: journalStatus,
    result: 'WIN',
  );
}

Widget _detailApp({required String journalStatus}) {
  final trade = _sampleTrade(journalStatus: journalStatus);
  return ProviderScope(
    overrides: [tradeProvider('t1').overrideWithValue(AsyncData(trade))],
    child: const MaterialApp(home: TradeDetailScreen(tradeId: 't1')),
  );
}
