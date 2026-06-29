import 'package:flutter_test/flutter_test.dart';
import 'package:decimal/decimal.dart';
import 'package:supermarket/core/services/posting_engine.dart';

void main() {
  group('PostingEngine.validatePostingLines', () {
    test('accepts balanced debit and credit lines', () {
      expect(
        () => PostingEngine.validatePostingLines([
          PostingLine(
              account: 'cash',
              debit: Decimal.fromInt(100),
              credit: Decimal.zero),
          PostingLine(
              account: 'sales',
              debit: Decimal.zero,
              credit: Decimal.fromInt(100)),
        ]),
        returnsNormally,
      );
    });

    test('rejects unbalanced lines', () {
      expect(
        () => PostingEngine.validatePostingLines([
          PostingLine(
              account: 'cash',
              debit: Decimal.fromInt(100),
              credit: Decimal.zero),
          PostingLine(
              account: 'sales',
              debit: Decimal.zero,
              credit: Decimal.fromInt(90)),
        ]),
        throwsException,
      );
    });

    test('rejects zero-value lines', () {
      expect(
        () => PostingEngine.validatePostingLines([
          PostingLine(
              account: 'cash', debit: Decimal.zero, credit: Decimal.zero),
        ]),
        throwsException,
      );
    });

    test('rejects lines with debit and credit on the same line', () {
      expect(
        () => PostingEngine.validatePostingLines([
          PostingLine(
              account: 'cash',
              debit: Decimal.fromInt(100),
              credit: Decimal.fromInt(100)),
        ]),
        throwsException,
      );
    });
  });
}
