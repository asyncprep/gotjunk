import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/field_repo.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import 'camera.dart';
import 'format.dart';

Future<void> openVisit(BuildContext context, String shiftId, {String? visitId, required bool editable}) =>
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: visitId == null,
      builder: (_) => VisitPage(shiftId: shiftId, visitId: visitId, editable: editable),
    ));

/// One stop at a disposal site: site, ticket, ticket photo and the weigh-ins.
class VisitPage extends ConsumerStatefulWidget {
  const VisitPage({super.key, required this.shiftId, this.visitId, required this.editable});
  final String shiftId;
  final String? visitId;
  final bool editable;

  @override
  ConsumerState<VisitPage> createState() => _VisitPageState();
}

class _VisitPageState extends ConsumerState<VisitPage> {
  late String? _visitId = widget.visitId;
  String? _siteId;
  final _ticket = TextEditingController();
  String? _material;
  final _kg = TextEditingController();
  String? _kgError;
  String? _ticketError;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (_visitId != null) {
      ref.read(repoProvider).db.getOptional('SELECT site_id, ticket_number FROM disposal_visit WHERE id = ?', [_visitId]).then((row) {
        if (!mounted || row == null) return;
        setState(() {
          _siteId = row['site_id'] as String?;
          _ticket.text = row['ticket_number'] as String? ?? '';
          _loaded = true;
        });
      });
    } else {
      _loaded = true;
    }
  }

  /// Saves site and ticket; false when the ticket number is already used at this site.
  /// A submitted shift is read-only: nothing is saved (the server would refuse it).
  Future<bool> _saveHeader() async {
    final repo = ref.read(repoProvider);
    if (_siteId == null || !widget.editable) return true;
    if (await repo.ticketTaken(_siteId!, _ticket.text, exceptVisitId: _visitId)) {
      if (mounted) setState(() => _ticketError = L10n.of(context).duplicateTicket);
      return false;
    }
    if (_ticketError != null) setState(() => _ticketError = null);
    if (_visitId == null) {
      final id = await repo.addVisit(widget.shiftId, _siteId!, _ticket.text);
      setState(() => _visitId = id);
    } else {
      await repo.updateVisit(_visitId!, siteId: _siteId!, ticketNumber: _ticket.text);
    }
    return true;
  }

  Future<void> _addLine() async {
    final kg = parseAmount(_kg.text);
    if (_material == null) return;
    if (kg == null || kg <= 0) {
      setState(() => _kgError = L10n.of(context).invalidWeight);
      return;
    }
    await ref.read(repoProvider).addLine(_visitId!, _material!, kg);
    setState(() {
      _kg.clear();
      _kgError = null;
    });
  }

  Future<void> _delete() async {
    await ref.read(repoProvider).deleteVisit(_visitId!);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final repo = ref.watch(repoProvider);
    final en = Localizations.localeOf(context).languageCode == 'en';
    final editable = widget.editable;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.visitTitle),
        actions: [
          if (_visitId != null && editable)
            IconButton(icon: const Icon(Icons.delete_outline), tooltip: t.deleteVisit, onPressed: _delete),
        ],
      ),
      body: SafeArea(
        child: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.all(16), children: [
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: repo.sites(),
                  builder: (context, snap) {
                    final sites = snap.data ?? [];
                    return DropdownButtonFormField<String>(
                      initialValue: sites.any((s) => s['id'] == _siteId) ? _siteId : null,
                      decoration: InputDecoration(labelText: t.site, border: const OutlineInputBorder()),
                      items: [for (final s in sites) DropdownMenuItem(value: s['id'] as String, child: Text('${s['name']}'))],
                      onChanged: editable
                          ? (v) {
                              setState(() => _siteId = v);
                              if (_visitId != null) _saveHeader();
                            }
                          : null,
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _ticket,
                  enabled: editable,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                      labelText: t.ticketNumber, border: const OutlineInputBorder(), errorText: _ticketError),
                  onEditingComplete: () {
                    if (_visitId != null) _saveHeader();
                    FocusScope.of(context).unfocus();
                  },
                ),
                if (_visitId == null) ...[
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _siteId == null || !editable ? null : _saveHeader,
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    child: Text(t.save),
                  ),
                ],
                if (_visitId != null) ...[
                  const SizedBox(height: 16),
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: repo.visits(widget.shiftId),
                    builder: (context, snap) {
                      final visit = (snap.data ?? []).where((v) => v['id'] == _visitId).firstOrNull;
                      final photos = (visit?['photos'] as int?) ?? 0;
                      return OutlinedButton.icon(
                        icon: Icon(photos > 0 ? Icons.check_circle_outline : Icons.photo_camera_outlined),
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                        onPressed: !editable
                            ? null
                            : () async {
                                if (!await _saveHeader() || !context.mounted) return;
                                await capturePhoto(context, ref,
                                    shiftId: widget.shiftId,
                                    kind: 'disposal_ticket',
                                    entityType: 'disposal_visit',
                                    entityId: _visitId!);
                              },
                        label: Text(photos > 0 ? '${t.ticketPhoto} · ${t.photosCount(photos)}' : '${t.takePhoto} — ${t.ticketPhoto}'),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Text(t.material, style: Theme.of(context).textTheme.titleSmall),
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: repo.lines(_visitId!),
                    builder: (context, snap) {
                      final lines = snap.data ?? [];
                      if (lines.isEmpty) {
                        return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(t.noLines));
                      }
                      return Column(children: [
                        for (final l in lines)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('${en ? l['name_en'] : l['name_fr']}'),
                            subtitle: Text('${(l['weight_kg'] as num).toStringAsFixed(0)} kg'),
                            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                              Text(
                                l['amount'] == null
                                    ? t.noRate
                                    : l['confirmed'] == 1
                                        ? money(context, l['amount'] as num)
                                        : '${money(context, l['amount'] as num)} (${t.estimate})',
                              ),
                              if (editable)
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  tooltip: t.delete,
                                  onPressed: () => repo.deleteLine(l['id'] as String),
                                ),
                            ]),
                          ),
                      ]);
                    },
                  ),
                  if (editable && _siteId != null) ...[
                    const SizedBox(height: 8),
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: repo.materialsForSite(_siteId!),
                      builder: (context, snap) {
                        final materials = snap.data ?? [];
                        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<String>(
                              initialValue: materials.any((m) => m['id'] == _material) ? _material : null,
                              isExpanded: true,
                              decoration: InputDecoration(labelText: t.material, border: const OutlineInputBorder()),
                              items: [
                                for (final m in materials)
                                  DropdownMenuItem(value: m['id'] as String, child: Text('${en ? m['name_en'] : m['name_fr']}')),
                              ],
                              onChanged: (v) => setState(() => _material = v),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _kg,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                  labelText: t.weightKg, border: const OutlineInputBorder(), errorText: _kgError),
                            ),
                          ),
                        ]);
                      },
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.add),
                      onPressed: _material == null ? null : _addLine,
                      label: Text(t.addMaterial),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () async {
                      if (await _saveHeader() && context.mounted) Navigator.pop(context);
                    },
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    child: Text(t.done),
                  ),
                ],
              ]),
      ),
    );
  }
}
