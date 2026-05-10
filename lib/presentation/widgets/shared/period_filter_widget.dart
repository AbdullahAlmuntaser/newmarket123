import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PeriodFilterWidget extends StatefulWidget {
  final Function(DateTime start, DateTime end) onFilter;

  const PeriodFilterWidget({super.key, required this.onFilter});

  @override
  State<PeriodFilterWidget> createState() => _PeriodFilterWidgetState();
}

class _PeriodFilterWidgetState extends State<PeriodFilterWidget> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      widget.onFilter(_startDate, _endDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy-MM-dd');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Text('من: ${df.format(_startDate)}'),
            Text('إلى: ${df.format(_endDate)}'),
            ElevatedButton.icon(
              onPressed: () => _selectDateRange(context),
              icon: const Icon(Icons.date_range),
              label: const Text('تغيير الفترة'),
            ),
          ],
        ),
      ),
    );
  }
}
