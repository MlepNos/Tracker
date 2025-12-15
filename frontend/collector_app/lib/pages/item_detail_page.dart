import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../theme/steam_theme.dart';
import '../widgets/steam_header.dart';

class ItemDetailPage extends StatefulWidget {
  final String collectionId;
  final Map<String, dynamic> item;

  const ItemDetailPage({super.key, required this.collectionId, required this.item});

  @override
  State<ItemDetailPage> createState() => _ItemDetailPageState();
}

class _ItemDetailPageState extends State<ItemDetailPage> {
  bool loading = true;
  String? error;

  List<dynamic> fields = [];
  Map<String, dynamic> valuesByKey = {}; // field_key -> value

  // local draft values user edits before saving
  final Map<String, dynamic> draft = {};

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

      final results = await Future.wait([
        api.getCollectionFields(widget.collectionId),
        api.getItemValues(widget.item["id"].toString()),
      ]);

      final f = results[0] as List<dynamic>;
      final v = results[1] as List<dynamic>;

      final map = <String, dynamic>{};
      for (final row in v) {
        final m = Map<String, dynamic>.from(row);
        map[m["field_key"].toString()] = (m["value"] ?? m["value_json"]?["value"]);
        // depending on how your schema returns it; we handle both
        if (m["value_json"] is Map && (m["value_json"] as Map).containsKey("value")) {
          map[m["field_key"].toString()] = (m["value_json"] as Map)["value"];
        }
      }

      setState(() {
        fields = f;
        valuesByKey = map;
        draft
          ..clear()
          ..addAll(map);
      });
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _save() async {
    try {
      final api = context.read<ApiClient>();
      final itemId = widget.item["id"].toString();

      final payload = <Map<String, dynamic>>[];
      for (final f in fields) {
        final fm = Map<String, dynamic>.from(f);
        final key = fm["field_key"].toString();

        // only send keys user has edited OR that already exist
        if (!draft.containsKey(key)) continue;

        payload.add({
          "field_key": key,
          "value": draft[key],
        });
      }

      await api.upsertItemValues(itemId, payload);
      await _load();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Saved")),
        );
      }
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.item["title"]?.toString() ?? "";

    return Scaffold(
      appBar: SteamHeader(active: "ITEM", onTab: (_) {}),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Error: $error", style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                      _CoverFrame(imageUrl: widget.item["cover_image_url"]?.toString()),
                      ElevatedButton(onPressed: _load, child: const Text("Retry")),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.arrow_back, color: SteamColors.text),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                color: SteamColors.text,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _save,
                            icon: const Icon(Icons.save),
                            label: const Text("Save"),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _CoverFrame(imageUrl: widget.item["cover_image_url"]?.toString()),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.separated(
                          itemCount: fields.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final f = Map<String, dynamic>.from(fields[i]);
                            final key = f["field_key"].toString();
                            final label = (f["label"] ?? key).toString();
                            final type = (f["data_type"] ?? "text").toString();

                            return _FieldEditorCard(
                              label: label,
                              fieldKey: key,
                              dataType: type,
                              value: draft[key],
                              optionsJson: (f["options_json"] is Map) ? Map<String, dynamic>.from(f["options_json"]) : null,
                              onChanged: (val) => setState(() => draft[key] = val),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
      ),
      ),),);
  }
}

class _FieldEditorCard extends StatelessWidget {
  final String label;
  final String fieldKey;
  final String dataType;
  final dynamic value;
  final Map<String, dynamic>? optionsJson;
  final ValueChanged<dynamic> onChanged;

  const _FieldEditorCard({
    required this.label,
    required this.fieldKey,
    required this.dataType,
    required this.value,
    required this.optionsJson,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Widget editor;

    if (dataType == "boolean") {
      final v = value == true;
      editor = Switch(
        value: v,
        onChanged: (x) => onChanged(x),
      );
   } else if (dataType == "number") {
  editor = TextFormField(
    initialValue: value?.toString() ?? "",
    keyboardType: TextInputType.number,
    decoration: const InputDecoration(border: OutlineInputBorder()),
    onChanged: (t) => onChanged(t.isEmpty ? null : num.tryParse(t)),
  );
}


 else if (dataType == "date") {
      editor = Row(
        children: [
          Expanded(
            child: Text(
              value?.toString() ?? "No date",
              style: const TextStyle(color: SteamColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                firstDate: DateTime(1970),
                lastDate: DateTime(now.year + 10),
                initialDate: now,
              );
              if (picked != null) {
                onChanged(picked.toIso8601String().substring(0, 10)); // YYYY-MM-DD
              }
            },
            child: const Text("Pick"),
          ),
          if (value != null)
            TextButton(
              onPressed: () => onChanged(null),
              child: const Text("Clear"),
            ),
        ],
      );
    } else if (dataType == "single_select") {
      final opts = (optionsJson?["options"] is List) ? List<String>.from(optionsJson!["options"]) : <String>[];
      editor = DropdownButtonFormField<String>(
        value: (value is String && value.isNotEmpty) ? value : null,
        items: opts.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
        onChanged: (v) => onChanged(v),
        decoration: const InputDecoration(border: OutlineInputBorder()),
      );
    } else {
  editor = TextFormField(
    initialValue: value?.toString() ?? "",
    decoration: const InputDecoration(border: OutlineInputBorder()),
    onChanged: (t) => onChanged(t.isEmpty ? null : t),
  );
}


    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SteamColors.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SteamColors.panel2.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: SteamColors.text, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          editor,
        ],
      ),
    );
    
  }

}
class _CoverFrame extends StatelessWidget {
  final String? imageUrl;
  const _CoverFrame({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final hasUrl = imageUrl != null && imageUrl!.trim().isNotEmpty;

    return LayoutBuilder(
      builder: (context, c) {
        const aspect = 3 / 1;
        final w = c.maxWidth;
        final h = (w / aspect).clamp(160.0, 260.0); // still safe

        return SizedBox(
          height: h,
          width: double.infinity,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: SteamColors.panel,
                border: Border.all(color: SteamColors.panel2.withOpacity(0.6)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: hasUrl
                  ? Image.network(
                      imageUrl!,
                      fit: BoxFit.contain, // fills nicely
                      alignment: Alignment.topCenter,
                      errorBuilder: (_, __, ___) => _empty(),
                    )
                  : _empty(),
            ),
          ),
        );
      },
    );
  }

  Widget _empty() => Container(
        color: SteamColors.panel2,
        child: const Center(
          child: Icon(Icons.image, size: 48, color: SteamColors.textMuted),
        ),
      );
}
