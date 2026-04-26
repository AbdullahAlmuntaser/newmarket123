import '../../domain/entities/profit_report.dart';
import 'posting_engine.dart';

class ReportService {
  final PostingEngine postingEngine;

  ReportService(this.postingEngine);

  Future<ProfitReport> getProfitReport(DateTime from, DateTime to) async {
    final sales = await postingEngine.getTotalByAccount(
      'SALES_REVENUE',
      from,
      to,
    );
    final cost = await postingEngine.getTotalByAccount('COGS', from, to);
    return ProfitReport(sales: sales, cost: cost, netProfit: sales - cost);
  }
}
