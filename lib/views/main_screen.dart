import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:privault/viewmodels/main_view_model.dart';
import 'package:privault/services/sync_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MainViewModel>().loadEntries();
    });
  }

  Future<void> _handleSync(BuildContext context, MainViewModel viewModel) async {
    final stats = await viewModel.sync();
    if (!context.mounted) return;
    if (stats != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(stats.hasChanges ? stats.toString() : 'Daten sind bereits auf dem neuesten Stand.'),
          backgroundColor: Colors.green.shade800,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MainViewModel>();
    final grouped = viewModel.groupedEntries;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          viewModel.vaultName, 
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.add),
          tooltip: 'Neuer Eintrag',
          onPressed: () async {
            final result = await Navigator.pushNamed(context, '/edit');
            if (result == true) viewModel.loadEntries();
          },
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'sync': _handleSync(context, viewModel); break;
                case 'settings': Navigator.pushNamed(context, '/settings'); break;
                case 'logout': 
                  viewModel.logout();
                  Navigator.pushReplacementNamed(context, '/');
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'sync', child: ListTile(leading: Icon(Icons.sync), title: Text('Synchronisieren'))),
              const PopupMenuItem(value: 'settings', child: ListTile(leading: Icon(Icons.settings), title: Text('Einstellungen'))),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'logout', child: ListTile(leading: Icon(Icons.logout, color: Colors.red), title: Text('Abmelden', style: TextStyle(color: Colors.red)))),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            color: Theme.of(context).appBarTheme.backgroundColor,
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Suchen...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                  ),
                  onChanged: (val) => viewModel.searchQuery = val,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Nur meine Einträge anzeigen', style: TextStyle(fontSize: 13)),
                    Switch(
                      value: viewModel.onlyMyEntries,
                      onChanged: (val) => viewModel.onlyMyEntries = val,
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          Expanded(
            child: viewModel.isBusy && grouped.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : grouped.isEmpty
                    ? const Center(child: Text('Keine Einträge gefunden.'))
                    : ListView.builder(
                        itemCount: grouped.length,
                        itemBuilder: (context, index) {
                          final category = grouped.keys.elementAt(index);
                          final items = grouped[category]!;
                          final isCollapsed = viewModel.isCategoryCollapsed(category);

                          return Column(
                            children: [
                              // Korrektur: ListTile hat keine backgroundColor Eigenschaft
                              Material(
                                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                                child: ListTile(
                                  title: Text(category, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  trailing: Icon(isCollapsed ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up),
                                  dense: true,
                                  onTap: () => viewModel.toggleCategory(category),
                                ),
                              ),
                              if (!isCollapsed)
                                ...items.map((entry) => _buildEntryCard(context, viewModel, entry)).toList(),
                            ],
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryCard(BuildContext context, MainViewModel viewModel, dynamic entry) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: _buildFavicon(entry.favicon),
          title: Text(entry.title.isNotEmpty ? entry.title : 'Unbenannter Eintrag', style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text(entry.url, maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () async {
            await Navigator.pushNamed(context, '/detail', arguments: entry.id);
            viewModel.loadEntries();
          },
        ),
      ),
    );
  }

  Widget _buildFavicon(String base64) {
    if (base64.isEmpty) return const Icon(Icons.vpn_key_outlined, color: Colors.blueGrey);
    try {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.memory(base64Decode(base64), width: 32, height: 32, errorBuilder: (_, __, ___) => const Icon(Icons.vpn_key_outlined)),
      );
    } catch (_) {
      return const Icon(Icons.vpn_key_outlined);
    }
  }
}
