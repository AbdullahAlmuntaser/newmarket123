import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/core/constants/app_colors.dart';
import 'package:supermarket/core/constants/app_dimensions.dart';
import 'package:supermarket/presentation/features/home/providers/command_center_provider.dart';
import 'package:supermarket/presentation/widgets/navigation/command_palette.dart';

class CommandCenterHeader extends StatefulWidget {
  const CommandCenterHeader({super.key});

  @override
  State<CommandCenterHeader> createState() => _CommandCenterHeaderState();
}

class _CommandCenterHeaderState extends State<CommandCenterHeader> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _showResults = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommandCenterProvider>();
    final isWide = MediaQuery.of(context).size.width > 600;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.md,
            vertical: AppDimensions.sm,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.search, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: AppDimensions.sm),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: 'ماذا تريد أن تفعل؟',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (q) {
                    provider.search(q);
                    setState(() => _showResults = q.isNotEmpty);
                  },
                  onSubmitted: (_) => _openCommandPalette(context),
                ),
              ),
              if (!isWide)
                IconButton(
                  icon: const Icon(Icons.tune, size: 20),
                  onPressed: () => _openCommandPalette(context),
                  tooltip: 'بحث متقدم',
                ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                ),
                child: Text(
                  'Ctrl+K',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_showResults && provider.searchResults.isNotEmpty)
          _buildSearchResults(context, provider),
      ],
    );
  }

  Widget _buildSearchResults(
      BuildContext context, CommandCenterProvider provider) {
    return Container(
      margin: const EdgeInsets.only(top: AppDimensions.xs),
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.sm),
        itemCount: provider.searchResults.length,
        itemBuilder: (context, index) {
          final item = provider.searchResults[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primaryLight.withOpacity(0.1),
              child: Icon(item.icon, size: 18, color: AppColors.primary),
            ),
            title: Text(item.title, style: const TextStyle(fontSize: 14)),
            subtitle: Text(item.category,
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            dense: true,
            onTap: () {
              _controller.clear();
              provider.clearSearch();
              setState(() => _showResults = false);
              context.push(item.route);
            },
          );
        },
      ),
    );
  }

  void _openCommandPalette(BuildContext context) {
    _controller.clear();
    context.read<CommandCenterProvider>().clearSearch();
    setState(() => _showResults = false);
    showDialog(context: context, builder: (_) => const CommandPalette());
  }
}
