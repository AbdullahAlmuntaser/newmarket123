class GLEntryDetail {
  final String id;
  final String entryId;
  final String accountId;
  final double debit;
  final double credit;
  final String? memo;

  GLEntryDetail({
    required this.id,
    required this.entryId,
    required this.accountId,
    required this.debit,
    required this.credit,
    this.memo,
  });
}
