import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket/core/services/posting_engine.dart';

void main() {
  group('PostingEngine.validatePostingLines', () {
    test('accepts balanced debit and credit lines', () {
      expect(
        () => PostingEngine.validatePostingLines([
          PostingLine(account: 'cash', debit: 100, credit: 0),
          PostingLine(account: 'sales', debit: 0, credit: 100),
        ]),
        returnsNormally,
      );
    });

    test('rejects unbalanced lines', () {
      expect(
        () => PostingEngine.validatePostingLines([
          PostingLine(account: 'cash', debit: 100, credit: 0),
          PostingLine(account: 'sales', debit: 0, credit: 90),
        ]),
        throwsException,
      );
    });

    test('rejects zero-value lines', () {
      expect(
        () => PostingEngine.validatePostingLines([
          PostingLine(account: 'cash', debit: 0, credit: 0),
        ]),
        throwsException,
      );
    });

    test('rejects lines with debit and credit on the same line', () {
      expect(
        () => PostingEngine.validatePostingLines([
          PostingLine(account: 'cash', debit: 100, credit: 100),
        ]),
        throwsException,
      );
    });
  });
}
