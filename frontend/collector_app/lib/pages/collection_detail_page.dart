import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../auth_state.dart';
import '../theme/steam_theme.dart';
import '../widgets/steam_header.dart';

class CollectionDetailPage extends StatefulWidget {
  final Map<String, dynamic> collection;

  const CollectionDetailPage({super.key, required this.collection});

  @override
  State<CollectionDetailPage> createState() => _CollectionDetailPageState();
}

class _CollectionDetailPageState extends State<CollectionDetailPage> {
  int tabIndex = 0; // 0=Items, 1=Fields
  bool loading = true;
  String? error;

  List<dynamic> items = [];
  List<dynamic> fields = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final api = context.read<ApiClient>();
      final id = widget.collection["id"].toString();

      final results = await Future.wait([
        api.getCollectionItems(id),
        api.getCollectionFields(id),
      ]);

      setState(() {
        items = results[0] as List<dynamic>;
        fields = results[1] as List<dynamic>;
      });
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _showCreateItemDialog() async {
  final titleCtrl = TextEditingController();
  final notesCtrl = TextEditingController();

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text("New Item"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: titleCtrl,
            decoration: const InputDecoration(labelText: "Title"),
          ),
          TextField(
            controller: notesCtrl,
            decoration: const InputDecoration(labelText: "Notes (optional)"),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text("Create"),
        ),
      ],
    ),
  );

  if (ok != true) return;

  try {
    final api = context.read<ApiClient>();
    final collectionId = widget.collection["id"].toString();

    await api.createItem(
      collectionId,
      titleCtrl.text.trim(),
      notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
    );

    await _load(); // refresh list
  } catch (e) {
    setState(() => error = e.toString());
  }
}






  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthState>();
    final name = widget.collection["name"]?.toString() ?? "";
    final desc = widget.collection["description"]?.toString() ?? "";

    return Scaffold(
      appBar: SteamHeader(
        active: "COLLECTIONS",
        onTab: (_) {},
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top title area (Steam-ish)
            Row(
  children: [
    IconButton(
      onPressed: () => Navigator.of(context).pop(),
      icon: const Icon(Icons.arrow_back, color: SteamColors.text),
      tooltip: "Back",
    ),
    const SizedBox(width: 8),
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(
              color: SteamColors.text,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(desc, style: const TextStyle(color: SteamColors.textMuted)),
        ],
      ),
    ),
    TextButton.icon(
      onPressed: () => auth.logout(),
      icon: const Icon(Icons.logout),
      label: const Text("Logout"),
    ),
  ],
),


            const SizedBox(height: 16),

            // Tabs
Row(
  children: [
    _TabChip(
      label: "ITEMS",
      active: tabIndex == 0,
      onTap: () => setState(() => tabIndex = 0),
    ),
    const SizedBox(width: 10),
    _TabChip(
      label: "FIELDS",
      active: tabIndex == 1,
      onTap: () => setState(() => tabIndex = 1),
    ),

    const Spacer(),

    // ✅ NEW ITEM BUTTON (only on Items tab)
    if (tabIndex == 0)
      ElevatedButton.icon(
        onPressed: _showCreateItemDialog,
        icon: const Icon(Icons.add),
        label: const Text("New Item"),
      ),

    const SizedBox(width: 10),

    IconButton(
      onPressed: _load,
      icon: const Icon(Icons.refresh, color: SteamColors.textMuted),
    ),
  ],
),


            const SizedBox(height: 12),

            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : error != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Error: $error", style: const TextStyle(color: Colors.red)),
                            const SizedBox(height: 12),
                            ElevatedButton(onPressed: _load, child: const Text("Retry")),
                          ],
                        )
                      : tabIndex == 0
    ? _ItemsList(
        items: items,
        onDelete: (itemId) async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("Delete item?"),
              content: const Text("This will permanently delete the item."),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text("Delete"),
                ),
              ],
            ),
          );

          if (ok != true) return;

          final api = context.read<ApiClient>();
          await api.deleteItem(itemId);
          await _load();
        },
      )
    : _FieldsList(fields: fields),

            ),
          ],
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TabChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? SteamColors.panel2.withOpacity(0.7) : SteamColors.panel,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? SteamColors.accent.withOpacity(0.6) : SteamColors.panel2.withOpacity(0.5),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? SteamColors.text : SteamColors.textMuted,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}

class _ItemsList extends StatelessWidget {
  final List<dynamic> items;
  final Future<void> Function(String itemId) onDelete;

  const _ItemsList({
    required this.items,
    required this.onDelete,
  });


  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Text("No items yet.", style: TextStyle(color: SteamColors.textMuted)),
      );
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final it = Map<String, dynamic>.from(items[i]);
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: SteamColors.panel,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: SteamColors.panel2.withOpacity(0.6)),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: SteamColors.panel2,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.image, color: SteamColors.textMuted),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  it["title"]?.toString() ?? "",
                  style: const TextStyle(color: SteamColors.text, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
  tooltip: "Delete",
  onPressed: () => onDelete(it["id"].toString()),
  icon: const Icon(Icons.delete_outline, color: SteamColors.textMuted),
),

            ],
          ),
        );
      },
    );
  }
}

class _FieldsList extends StatelessWidget {
  final List<dynamic> fields;
  const _FieldsList({required this.fields});

  @override
  Widget build(BuildContext context) {
    if (fields.isEmpty) {
      return const Center(
        child: Text("No fields yet.", style: TextStyle(color: SteamColors.textMuted)),
      );
    }

    return ListView.separated(
      itemCount: fields.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final f = Map<String, dynamic>.from(fields[i]);
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: SteamColors.panel,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: SteamColors.panel2.withOpacity(0.6)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  "${f["label"]}  (${f["field_key"]})",
                  style: const TextStyle(color: SteamColors.text, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                f["data_type"]?.toString() ?? "",
                style: const TextStyle(color: SteamColors.textMuted),
              ),
            ],
          ),
        );
      },
    );
  }
}
