import 'package:flutter/material.dart';
import '../theme/steam_theme.dart';

class SteamSidebar extends StatelessWidget {
  final List<dynamic> collections;
  final String? selectedCollectionId;
  final void Function(String? id) onSelect;
  final VoidCallback onCreate;

  const SteamSidebar({
    super.key,
    required this.collections,
    required this.selectedCollectionId,
    required this.onSelect,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      color: SteamColors.panel,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "COLLECTIONS",
            style: TextStyle(
              color: SteamColors.textMuted,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),

          // New collection
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: SteamColors.panel2,
                foregroundColor: SteamColors.text,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text("New Collection"),
            ),
          ),

          const SizedBox(height: 12),

          // List
          Expanded(
            child: ListView.builder(
              itemCount: collections.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  // "All"
                  final active = selectedCollectionId == null;
                  return _SidebarItem(
                    label: "All Collections",
                    active: active,
                    onTap: () => onSelect(null),
                  );
                }

                final c = Map<String, dynamic>.from(collections[index - 1]);
                final id = (c["id"] ?? "").toString();
                final name = (c["name"] ?? "").toString();
                final active = selectedCollectionId == id;

                return _SidebarItem(
                  label: name,
                  active: active,
                  onTap: () => onSelect(id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: active ? SteamColors.panel2.withOpacity(0.7) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: active ? Border.all(color: SteamColors.accent.withOpacity(0.6)) : null,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: active ? SteamColors.text : SteamColors.textMuted,
            fontWeight: active ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
