import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:privault/viewmodels/detail_view_model.dart';

class DetailScreen extends StatefulWidget {
  final int entryId;

  const DetailScreen({super.key, required this.entryId});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DetailViewModel>().initialize(widget.entryId);
    });
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label in die Zwischenablage kopiert')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<DetailViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final result = await Navigator.pushNamed(context, '/edit', arguments: widget.entryId);
              if (result == true) {
                viewModel.initialize(widget.entryId);
              }
            },
          ),
        ],
      ),
      body: viewModel.isBusy
          ? const Center(child: CircularProgressIndicator())
          : viewModel.errorMessage != null
              ? Center(child: Text(viewModel.errorMessage!, style: const TextStyle(color: Colors.red)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Section
                      Center(
                        child: Column(
                          children: [
                            if (viewModel.favicon.isNotEmpty)
                              Image.memory(base64Decode(viewModel.favicon), width: 64, height: 64)
                            else
                              const Icon(Icons.vpn_key_outlined, size: 64, color: Colors.blueGrey),
                            const SizedBox(height: 16),
                            Text(viewModel.title, style: Theme.of(context).textTheme.headlineMedium),
                            Text(viewModel.category, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Username Card
                      ListTile(
                        title: const Text('Benutzername'),
                        subtitle: Text(viewModel.username),
                        trailing: IconButton(
                          icon: const Icon(Icons.copy),
                          onPressed: () => _copyToClipboard(context, viewModel.username, 'Benutzername'),
                        ),
                      ),
                      const Divider(),

                      // Password Card
                      ListTile(
                        title: const Text('Passwort'),
                        subtitle: Text(viewModel.isPasswordHidden ? '••••••••' : viewModel.password),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(viewModel.isPasswordHidden ? Icons.visibility : Icons.visibility_off),
                              onPressed: viewModel.togglePasswordVisibility,
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy),
                              onPressed: () => _copyToClipboard(context, viewModel.password, 'Passwort'),
                            ),
                          ],
                        ),
                      ),
                      const Divider(),

                      // URL Section
                      if (viewModel.url.isNotEmpty) ...[
                        ListTile(
                          title: const Text('URL'),
                          subtitle: Text(viewModel.url),
                          trailing: const Icon(Icons.open_in_new),
                          onTap: () {
                            // URL opening logic
                          },
                        ),
                        const Divider(),
                      ],

                      // Anhänge Section
                      if (viewModel.attachments.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text('Anhänge', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                        ...viewModel.attachments.map((att) {
                          final meta = viewModel.getAttachmentMeta(att.uuid);
                          return ListTile(
                            leading: const Icon(Icons.attach_file),
                            title: Text(meta?.filename ?? 'Unbekannte Datei'),
                            subtitle: Text('\${((meta?.size ?? 0) / 1024).toStringAsFixed(1)} KB'),
                            onTap: () => viewModel.openAttachment(att),
                          );
                        }).toList(),
                        const Divider(),
                      ],

                      // Notes Section
                      if (viewModel.notes.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text('Notizen', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(viewModel.notes),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}
