import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../auth_state.dart';
import '../widgets/steam_header.dart';
import '../theme/steam_theme.dart';
import '../widgets/steam_sidebar.dart';
import 'collection_detail_page.dart';
import 'package:dio/dio.dart';



class CollectionTile extends StatelessWidget {
  final Map<String, dynamic> c;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  const CollectionTile({
    super.key,
    required this.c,
    required this.onTap,
    required this.onDelete,
    required this.onEdit,
  });
  IconData _iconForType(String t) {
    switch (t) {
      case "movies":
        return Icons.movie;
      case "games":
        return Icons.sports_esports;
      case "anime":
        return Icons.animation; // or Icons.auto_awesome
      default:
        return Icons.collections_bookmark;
    }
  }
  @override
  Widget build(BuildContext context) {
    final name = (c["name"] ?? "") as String;
    final desc = (c["description"] ?? "") as String;
    final type = (c["collection_type"] ?? "custom").toString();
    final icon = _iconForType(type);
    return _HoverCard(
  onTap: onTap,
  child: Stack(
  children: [
    Container(
      decoration: BoxDecoration(
        color: SteamColors.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SteamColors.panel2.withOpacity(0.7)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
  child: Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: SteamColors.panel2,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Center(
      child: (() {
        final iconUrl = (c["icon_url"] ?? "").toString();

        if (iconUrl.isNotEmpty) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              iconUrl,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Icon(icon, size: 40, color: SteamColors.textMuted),
            ),
          );
        }

        return Icon(icon, size: 40, color: SteamColors.textMuted);
      })(),
    ),
  ),
),

          const SizedBox(height: 12),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: SteamColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: SteamColors.textMuted),
          ),
        ],
      ),
    ),
Positioned(
  top: 6,
  right: 44,
  child: IconButton(
    tooltip: "Edit",
    icon: const Icon(Icons.edit, color: SteamColors.textMuted),
    onPressed: onEdit,
  ),
),

    Positioned(
      top: 6,
      right: 6,
      child: IconButton(
        tooltip: "Delete",
        icon: const Icon(Icons.delete_outline, color: SteamColors.textMuted),
        onPressed: onDelete,
      ),
    ),
  ],
),

);

  }
}


class _HoverCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _HoverCard({required this.child, required this.onTap});

  @override
  State<_HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<_HoverCard> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          transform: Matrix4.identity()..translate(0.0, hover ? -2.0 : 0.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            boxShadow: hover
                ? [
                    BoxShadow(
                      color: SteamColors.accent.withOpacity(0.18),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class CollectionsPage extends StatefulWidget {
  const CollectionsPage({super.key});

  @override
  State<CollectionsPage> createState() => _CollectionsPageState();
}

class _CollectionsPageState extends State<CollectionsPage> {
  bool loading = true;
  String? error;
  List<dynamic> collections = [];
  String? selectedCollectionId; // null = all
  final Map<String, List<Map<String, dynamic>>> _templates = {
    "games": [
      {"key": "platform", "label": "Platform", "type": "single_select", "options": ["PC", "PS5", "Xbox", "Switch"]},
      {"key": "status", "label": "Status", "type": "single_select", "options": ["Backlog", "Playing", "Completed", "Dropped"]},
      {"key": "hours", "label": "Hours Played", "type": "number"},
      {"key": "rating", "label": "Rating", "type": "number"},
      {"key": "release_date", "label": "Release Date", "type": "date"},
      {"key": "developer", "label": "Developer", "type": "text"},
    ],
    "movies": [
      {"key": "status", "label": "Status", "type": "single_select", "options": ["Planned", "Watched", "Dropped"]},
      {"key": "rating", "label": "Rating", "type": "number"},
      {"key": "release_date", "label": "Release Date", "type": "date"},
      {"key": "director", "label": "Director", "type": "text"},
      {"key": "runtime_min", "label": "Runtime (min)", "type": "number"},
    ],
    "anime": [
      {"key": "status", "label": "Status", "type": "single_select", "options": ["Planned", "Watching", "Completed", "Dropped"]},
      {"key": "episodes_watched", "label": "Episodes Watched", "type": "number"},
      {"key": "total_episodes", "label": "Total Episodes", "type": "number"},
      {"key": "rating", "label": "Rating", "type": "number"},
      {"key": "release_date", "label": "Start Date", "type": "date"},
      {"key": "studio", "label": "Studio", "type": "text"},
    ],
  };

  Future<void> editCollectionDialog(Map<String, dynamic> c) async {
  final nameCtrl = TextEditingController(text: c["name"]?.toString() ?? "");
  final descCtrl = TextEditingController(text: c["description"]?.toString() ?? "");
  final iconCtrl = TextEditingController(text: c["icon_url"]?.toString() ?? "");

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text("Edit Collection"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Name")),
          TextField(controller: descCtrl, decoration: const InputDecoration(labelText: "Description")),
          TextField(controller: iconCtrl, decoration: const InputDecoration(labelText: "Icon / GIF URL")),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Save")),
      ],
    ),
  );

  if (ok != true) return;

  final api = context.read<ApiClient>();
  await api.updateCollection(
    c["id"].toString(),
    name: nameCtrl.text.trim(),
    description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
    iconUrl: iconCtrl.text.trim().isEmpty ? null : iconCtrl.text.trim(),
  );

  await loadCollections();
}

  Future<void> _seedTemplateFields(String collectionId, String type) async {
  final api = context.read<ApiClient>();
  final template = _templates[type];

  if (template == null) return; // custom or unknown -> no seeding

  for (int i = 0; i < template.length; i++) {
    final f = template[i];
    try {
      await api.createField(
  collectionId,
  fieldKey: f["key"].toString(),
  label: f["label"].toString(),
  dataType: f["type"].toString(),
  sortOrder: i,
  optionsJson: (f["options"] != null)
      ? {"options": List<String>.from(f["options"])}
      : null,
);

    } on DioException catch (e) {
      // If field already exists (409), ignore. Otherwise rethrow.
      if (e.response?.statusCode != 409) rethrow;
    }
  }
}

  Future<void> loadCollections() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final api = context.read<ApiClient>();
      final data = await api.getCollections();
      setState(() => collections = data);
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      setState(() => loading = false);
    }
  }

 Future<void> createCollectionDialog() async {
  final nameCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  String type = "games";

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text("New Collection"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Name")),
          TextField(controller: descCtrl, decoration: const InputDecoration(labelText: "Description")),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: type,
            items: const [
              DropdownMenuItem(value: "games", child: Text("Games")),
              DropdownMenuItem(value: "movies", child: Text("Movies")),
              DropdownMenuItem(value: "anime", child: Text("Anime")),
              DropdownMenuItem(value: "custom", child: Text("Custom")),
            ],
            onChanged: (v) => type = v ?? "games",
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

    final created = await api.createCollection(
      nameCtrl.text.trim(),
      descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
      type,
    );

    final collectionId = created["id"].toString();
    await _seedTemplateFields(collectionId, type);
    await loadCollections();
  } catch (e) {
    setState(() => error = e.toString());
  }
}

  @override
  void initState() {
    super.initState();
    loadCollections();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthState>();

    return Scaffold(
      appBar: SteamHeader(
  active: "COLLECTIONS",
  onTab: (tab) {
    // For now: just keep you on Collections.
    // Next step we’ll wire real navigation.
  },
),

      floatingActionButton: FloatingActionButton(
  onPressed: createCollectionDialog,
  child: const Icon(Icons.add),
),
      body: Padding(
  padding: const EdgeInsets.all(16),
  child: Column(
    children: [
      
      const SizedBox(height: 12),

      Expanded(
  child: LayoutBuilder(
    builder: (context, constraints) {
      final isWide = constraints.maxWidth >= 1000;

      Widget mainContent() {
        if (loading) return const Center(child: CircularProgressIndicator());

        if (error != null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Error: $error", style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: loadCollections, child: const Text("Retry")),
            ],
          );
        }

        final filtered = selectedCollectionId == null
            ? collections
            : collections.where((x) => (x["id"] ?? "").toString() == selectedCollectionId).toList();

        // re-use your existing grid/list UI but using `filtered`
        return LayoutBuilder(
          builder: (context, c2) {
            final gridWide = c2.maxWidth >= 900;

            if (gridWide) {
              return GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 1.15,
                ),
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final c = Map<String, dynamic>.from(filtered[i]);
                 return CollectionTile(
              c: c,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CollectionDetailPage(collection: c),
                  ),
                );
              },
              onEdit: () => editCollectionDialog(c),
  onDelete: () async {
    final api = context.read<ApiClient>();
    final id = c["id"].toString();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete collection?"),
        content: Text("Delete '${c["name"]}' and everything inside it?"),
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

    await api.deleteCollection(id);
    await loadCollections();
  },
);

                },
              );
            }

            return ListView.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final c = Map<String, dynamic>.from(filtered[i]);
                return SizedBox(
                  height: 110,
                  child: CollectionTile(
  c: c,
  onTap: () {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CollectionDetailPage(collection: c),
      ),
    );
  },

onEdit: () => editCollectionDialog(c),
  onDelete: () async {
    final api = context.read<ApiClient>();
    final id = c["id"].toString();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete collection?"),
        content: Text("Delete '${c["name"]}' and everything inside it?"),
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

    await api.deleteCollection(id);
    await loadCollections();
  },
),

                );
              },
            );
          },
        );
      }

      if (!isWide) {
        // Mobile: no sidebar yet
        return mainContent();
      }

      // Web/Desktop: sidebar + content
      return Row(
        children: [
          SteamSidebar(
            collections: collections,
            selectedCollectionId: selectedCollectionId,
            onSelect: (id) => setState(() => selectedCollectionId = id),
            onCreate: createCollectionDialog,
 // for now uses createGames; next we make a real dialog
          ),
          const SizedBox(width: 16),
          Expanded(child: mainContent()),
        ],
      );
    },
  ),
),

    ],
  ),
),

      
    );
  }
}
