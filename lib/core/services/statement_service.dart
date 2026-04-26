import 'posting_engine.dart';

class StatementService {
  final PostingEngine postingEngine;

  StatementService(this.postingEngine);

  Future<List<PostingLine>> getPartnerStatement(
    String partnerId,
    DateTime from,
    DateTime to,
  ) async {
    return await postingEngine.getEntriesByAccount(partnerId, from, to);
  }

  Future<double> getCurrentBalance(String partnerId) async {
    return await postingEngine.getBalanceForAccount(partnerId);
  }
}
