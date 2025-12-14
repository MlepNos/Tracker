import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../auth_state.dart';
import '../widgets/steam_header.dart';
import '../theme/steam_theme.dart';
import '../widgets/steam_sidebar.dart';
import 'collection_detail_page.dart';

class CollectionTile extends StatelessWidget {
  final Map<String, dynamic> c;
  final VoidCallback onTap;

  const CollectionTile({super.key, required this.c, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = (c["name"] ?? "") as String;
    final desc = (c["description"] ?? "") as String;

    return _HoverCard(
  onTap: onTap,
  child: Container(
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
            child: const Center(
              child: Icon(Icons.collections_bookmark, size: 40, color: SteamColors.textMuted),
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
  String type = "games"; // default

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text("New Collection"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: "Name (e.g. Games)"),
            ),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: "Description"),
            ),
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
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Create"),
          ),
        ],
      );
    },
  );

  if (result != true) return;

  try {
    final api = context.read<ApiClient>();

    // TEMP: for now we only send name/description (backend doesn't store type yet)
    await api.createCollection(
      nameCtrl.text.trim(),
      descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
    );

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
                  child: CollectionTile(c: c, onTap: () {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => CollectionDetailPage(collection: c),
    ),
  );
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
