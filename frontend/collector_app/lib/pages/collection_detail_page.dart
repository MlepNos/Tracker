import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../auth_state.dart';
import '../theme/steam_theme.dart';
import '../widgets/steam_header.dart';
import 'item_detail_page.dart';

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
Future<void> _showCreateFieldDialog() async {
  final keyCtrl = TextEditingController();
  final labelCtrl = TextEditingController();
  String type = "text";

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text("New Field"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: labelCtrl,
            decoration: const InputDecoration(labelText: "Label (e.g. Platform)"),
          ),
          TextField(
            controller: keyCtrl,
            decoration: const InputDecoration(labelText: "Key (e.g. platform)"),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: type,
            items: const [
              DropdownMenuItem(value: "text", child: Text("Text")),
              DropdownMenuItem(value: "number", child: Text("Number")),
              DropdownMenuItem(value: "boolean", child: Text("Boolean")),
              DropdownMenuItem(value: "date", child: Text("Date")),
              DropdownMenuItem(value: "single_select", child: Text("Single Select")),
            ],
            onChanged: (v) => type = v ?? "text",
            decoration: const InputDecoration(labelText: "Type"),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Create")),
      ],
    ),
  );

  if (ok != true) return;

  try {
    final api = context.read<ApiClient>();
    final collectionId = widget.collection["id"].toString();

    await api.createField(
      collectionId,
      fieldKey: keyCtrl.text.trim(),
      label: labelCtrl.text.trim(),
      dataType: type,
    );

    await _load(); // refresh fields + items
  } catch (e) {
    setState(() => error = e.toString());
  }
}

  Future<void> _showCreateItemDialog() async {
  final titleCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  
  final type = (widget.collection["collection_type"] ?? "custom").toString();
  final isMovies = type == "movies";
  final isAnime = type == "anime";
  String? pickedCoverUrl;

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text("New Item"),

      // ✅ content is ONLY widgets, actions stay on AlertDialog
      content: StatefulBuilder(
        builder: (ctx, setLocal) => SingleChildScrollView(
          child: Column(
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
              const SizedBox(height: 12),

              // Preview frame
              Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: SteamColors.panel2,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: SteamColors.panel2.withOpacity(0.6)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: (pickedCoverUrl != null && pickedCoverUrl!.isNotEmpty)
                      ? Image.network(
                          pickedCoverUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.image,
                                color: SteamColors.textMuted, size: 40),
                          ),
                        )
                      : const Center(
                          child: Icon(Icons.image,
                              color: SteamColors.textMuted, size: 40),
                        ),
                ),
              ),

              const SizedBox(height: 12),

              ElevatedButton.icon(
                onPressed: () async {
                  final q = titleCtrl.text.trim();
                  if (q.isEmpty) return;

                  final api = context.read<ApiClient>();
                  final results = (type == "movies")
                      ? await api.searchMovies(q)
                      : (type == "anime")
                          ? await api.searchAnime(q)
                          : await api.searchGames(q);


                  final picked = await showDialog<Map<String, dynamic>>(
                    context: ctx,
                    builder: (pickCtx) => AlertDialog(
                      title: Text(isMovies ? "Pick a movie" : (isAnime ? "Pick an anime" : "Pick a game"),
),
                      content: SizedBox(
                        width: 520,
                        height: 420,
                        child: ListView.builder(
                          itemCount: results.length,
                          itemBuilder: (_, i) {
                            final r = Map<String, dynamic>.from(results[i]);
                            return ListTile(
                              leading: (r["cover_url"] != null)
                                  ? Image.network(
                                      r["cover_url"],
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const Icon(Icons.image),
                                    )
                                  : const Icon(Icons.image),
                              title: Text(r["title"]?.toString() ?? ""),
                              subtitle: Text(r["released"]?.toString() ?? ""),
                              onTap: () => Navigator.pop(pickCtx, r),
                            );
                          },
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(pickCtx, null),
                          child: const Text("Close"),
                        ),
                      ],
                    ),
                  );

                  if (picked == null) return;

                  setLocal(() {
                    titleCtrl.text =
                        picked["title"]?.toString() ?? titleCtrl.text;
                    pickedCoverUrl = picked["cover_url"]?.toString();
                  });
                },
                icon: const Icon(Icons.search),
                label: Text(isMovies ? "Search TMDB" : (isAnime ? "Search AniList" : "Search RAWG"),
                ),

              ),
            ],
          ),
        ),
      ),

      // ✅ actions belong HERE (AlertDialog)
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
      coverImageUrl: pickedCoverUrl,
    );

    await _load();
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
    if (tabIndex == 1)
      ElevatedButton.icon(
        onPressed: _showCreateFieldDialog,
        icon: const Icon(Icons.add),
        label: const Text("New Field"),
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
    onOpen: (it) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ItemDetailPage(
            collectionId: widget.collection["id"].toString(),
            item: it,
          ),
        ),
      );
    },
    onDelete: (itemId) async {
      // keep your delete logic here (what you already did in C)
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Delete item?"),
          content: const Text("This will permanently delete the item."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete")),
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
  final void Function(Map<String, dynamic> item) onOpen;
  final Future<void> Function(String itemId) onDelete;

  const _ItemsList({
    required this.items,
    required this.onOpen,
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
        return InkWell(
  onTap: () => onOpen(it),
  borderRadius: BorderRadius.circular(10),
  child: Container(
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
          child: (it["cover_image_url"] != null &&
        it["cover_image_url"].toString().isNotEmpty)
    ? ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          it["cover_image_url"],
          width: 56,            // ✅ add
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.image, color: SteamColors.textMuted),
        ),
      )
    : const Icon(Icons.image, color: SteamColors.textMuted),

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
