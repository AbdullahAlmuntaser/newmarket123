import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/core/auth/auth_provider.dart';
import 'package:supermarket/core/auth/user_role.dart';
import 'package:supermarket/core/services/fast_access_service.dart';

class CommandPalette extends StatefulWidget {
  const CommandPalette({super.key});

  @override
  State<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette> {
  final TextEditingController _searchController = TextEditingController();
  List<FastAccessItem> _results = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final role =
          UserRole.fromString(authProvider.currentUser?.role ?? 'cashier');
      final fastAccess = Provider.of<FastAccessService>(context, listen: false);
      setState(() {
        _results = fastAccess.getSearchableItems(role);
      });
    });
  }

  void _onSearch(String query) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final role =
        UserRole.fromString(authProvider.currentUser?.role ?? 'cashier');
    final fastAccess = Provider.of<FastAccessService>(context, listen: false);
    setState(() {
      _results = fastAccess.search(query, role);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E26),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 80),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'ابحث عن شاشة أو وظيفة... (مثلاً: مخزن، بيع، كشف)',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF3E3E4A)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF3E3E4A)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.blue),
                ),
              ),
              onChanged: _onSearch,
            ),
          ),
          const Divider(color: Color(0xFF3E3E4A), height: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final item = _results[index];
                return ListTile(
                  leading: Icon(item.icon, color: Colors.blueAccent),
                  title: Text(item.title,
                      style: const TextStyle(color: Colors.white)),
                  subtitle: Text(item.category,
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 12)),
                  trailing: const Icon(Icons.keyboard_arrow_left,
                      color: Colors.white24),
                  onTap: () {
                    context.read<FastAccessService>().addToRecent(item.route);
                    Navigator.pop(context);
                    context.push(item.route);
                  },
                );
              },
            ),
          ),
          if (_results.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Text('لا توجد نتائج مطابقة',
                  style: TextStyle(color: Colors.white38)),
            ),
          const Divider(color: Color(0xFF3E3E4A), height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('اختصارات سريعة',
                    style: TextStyle(color: Colors.white24, fontSize: 11)),
                Row(
                  children: [
                    _buildShortcutHint('ESC', 'إغلاق'),
                    const SizedBox(width: 8),
                    _buildShortcutHint('ENTER', 'فتح'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutHint(String key, String label) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF3E3E4A),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(key,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(color: Colors.white38, fontSize: 10)),
      ],
    );
  }
}
