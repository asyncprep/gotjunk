import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:powersync/powersync.dart' show SyncStatus;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_config.dart';
import '../data/repo.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import 'format.dart';
import 'job_form.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key, required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = L10n.of(context);
    final repo = ref.watch(repoProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.todayShift),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'fr' || v == 'en') ref.read(localeProvider.notifier).set(Locale(v));
              if (v == 'signout') await Supabase.instance.client.auth.signOut();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'fr', child: Text('Français')),
              const PopupMenuItem(value: 'en', child: Text('English')),
              PopupMenuItem(value: 'signout', child: Text(t.signOut)),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            SyncBar(repo: repo),
            Expanded(
              child: StreamBuilder<String?>(
                stream: repo.myEmployeeId(userId),
                builder: (context, snap) {
                  if (!snap.hasData && snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final employeeId = snap.data;
                  if (employeeId == null) return _Message(t.notCrew);
                  return ShiftView(repo: repo, employeeId: employeeId);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Connection state and anything still waiting to upload.
class SyncBar extends StatelessWidget {
  const SyncBar({super.key, required this.repo});
  final Repo repo;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<SyncStatus>(
      stream: repo.db.statusStream,
      initialData: repo.db.currentStatus,
      builder: (context, statusSnap) => StreamBuilder<int>(
        stream: repo.pendingUploads(),
        builder: (context, pendingSnap) {
          final status = statusSnap.data;
          final pending = pendingSnap.data ?? 0;
          final online = AppConfig.powersyncUrl.isNotEmpty && (status?.connected ?? false);
          final busy = (status?.uploading ?? false) || (status?.downloading ?? false);
          final text = !online
              ? t.offline
              : busy
                  ? t.syncing
                  : pending > 0
                      ? t.pendingUploads(pending)
                      : t.synced;
          return Container(
            width: double.infinity,
            color: online ? scheme.secondaryContainer : scheme.tertiaryContainer,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(children: [
              Icon(online ? Icons.cloud_done_outlined : Icons.cloud_off_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
              if (online && pending > 0) Text('$pending', style: Theme.of(context).textTheme.labelSmall),
            ]),
          );
        },
      ),
    );
  }
}

class ShiftView extends StatelessWidget {
  const ShiftView({super.key, required this.repo, required this.employeeId});
  final Repo repo;
  final String employeeId;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return StreamBuilder<Map<String, dynamic>?>(
      stream: repo.currentShift(employeeId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final shift = snap.data;
        if (shift == null) return _Message(t.noShift);
        final shiftId = shift['id'] as String;
        final status = shift['status'] as String?;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            _Rejections(repo: repo),
            _ShiftHeader(repo: repo, shift: shift),
            if (status == 'open') _StartShift(repo: repo, shiftId: shiftId, current: shift['hours_type'] as String?),
            if (status != 'open') ...[
              const SizedBox(height: 12),
              _ScoreboardCard(repo: repo, shiftId: shiftId, employeeId: employeeId),
              const SizedBox(height: 12),
              _JobsCard(repo: repo, shiftId: shiftId, editable: crewJobStatuses.contains(status)),
              if (crewJobStatuses.contains(status)) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  icon: const Icon(Icons.flag_outlined),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  onPressed: () => _confirmSubmit(context, shiftId),
                  label: Text(t.submitShift),
                ),
              ],
            ],
          ],
        );
      },
    );
  }

  Future<void> _confirmSubmit(BuildContext context, String shiftId) async {
    final t = L10n.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.submitShift),
        content: Text(t.submitConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(t.submitShift)),
        ],
      ),
    );
    if (ok == true) await repo.submitShift(shiftId);
  }
}

class _ShiftHeader extends StatelessWidget {
  const _ShiftHeader({required this.repo, required this.shift});
  final Repo repo;
  final Map<String, dynamic> shift;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final status = shift['status'] as String?;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text('${t.truck} ${shift['truck'] ?? '—'} · ${t.phone} ${shift['phone'] ?? '—'}', style: text.titleMedium)),
              Chip(label: Text(statusLabel(t, status))),
            ]),
            if (status == 'returned' && shift['return_reason'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(t.returnedBecause('${shift['return_reason']}'),
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            const SizedBox(height: 8),
            Text('${t.hoursType}: ${hoursLabel(t, shift['hours_type'] as String?)}'),
            Text('${t.startTime} ${clock(context, shift['start_time'] as String?)} · ${t.finishTime} ${clock(context, shift['finish_time'] as String?)}'),
            const SizedBox(height: 8),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: repo.crew(shift['id'] as String),
              builder: (context, snap) => Text(
                '${t.crew}: ${(snap.data ?? []).where((m) => m['left_at'] == null).map((m) => m['full_name'] ?? '…').join(', ')}',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StartShift extends StatefulWidget {
  const _StartShift({required this.repo, required this.shiftId, this.current});
  final Repo repo;
  final String shiftId;
  final String? current;

  @override
  State<_StartShift> createState() => _StartShiftState();
}

class _StartShiftState extends State<_StartShift> {
  late String? _hours = widget.current;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t.hoursType, style: Theme.of(context).textTheme.titleSmall),
            RadioGroup<String>(
              groupValue: _hours,
              onChanged: (v) => setState(() => _hours = v),
              child: Column(children: [
                for (final h in const ['regular_junk', 'warehouse', 'non_junk'])
                  RadioListTile<String>(value: h, title: Text(hoursLabel(t, h)), contentPadding: EdgeInsets.zero),
              ]),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              icon: const Icon(Icons.play_arrow),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: _hours == null ? null : () => widget.repo.startShift(widget.shiftId, _hours!),
              label: Text(t.startShift),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreboardCard extends StatelessWidget {
  const _ScoreboardCard({required this.repo, required this.shiftId, required this.employeeId});
  final Repo repo;
  final String shiftId;
  final String employeeId;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return StreamBuilder<Scoreboard>(
      stream: repo.scoreboard(shiftId, employeeId),
      builder: (context, snap) {
        final s = snap.data ?? const Scoreboard(jobs: 0, revenue: 0, tips: 0, myTips: 0);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.scoreboard, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 12),
              Wrap(spacing: 12, runSpacing: 12, children: [
                _Tile(value: money(context, s.revenue), label: t.revenue, big: true),
                _Tile(value: '${s.jobs}', label: t.jobsDone),
                _Tile(value: money(context, s.tips), label: t.tips),
                _Tile(value: money(context, s.myTips), label: t.myTips),
              ]),
            ]),
          ),
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.value, required this.label, this.big = false});
  final String value;
  final String label;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SizedBox(
      width: big ? double.infinity : 140,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: (big ? text.headlineMedium : text.titleLarge)?.copyWith(fontWeight: FontWeight.w600)),
        Text(label, style: text.bodySmall),
      ]),
    );
  }
}

class _JobsCard extends StatelessWidget {
  const _JobsCard({required this.repo, required this.shiftId, required this.editable});
  final Repo repo;
  final String shiftId;
  final bool editable;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: repo.jobs(shiftId),
          builder: (context, snap) {
            final jobs = snap.data ?? [];
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(child: Text(t.jobs, style: Theme.of(context).textTheme.titleSmall)),
                if (editable)
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.add),
                    onPressed: () => openJobForm(context, repo, shiftId, null),
                    label: Text(t.addJob),
                  ),
              ]),
              if (jobs.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(t.noJobs)),
              for (final j in jobs)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${j['opportunity_id']}'),
                  subtitle: Text(outcomeLabel(t, j['outcome'] as String?)),
                  trailing: j['outcome'] == 'completed'
                      ? Text(money(context, j['revenue_pre_tax'] as num?), style: Theme.of(context).textTheme.titleMedium)
                      : null,
                  onTap: editable && j['outcome'] != 'cancelled_confirmed' ? () => openJobForm(context, repo, shiftId, j) : null,
                ),
            ]);
          },
        ),
      ),
    );
  }
}

class _Rejections extends StatelessWidget {
  const _Rejections({required this.repo});
  final Repo repo;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: repo.rejections(),
      builder: (context, snap) => Column(children: [
        for (final r in snap.data ?? [])
          Card(
            color: scheme.errorContainer,
            child: ListTile(
              leading: Icon(Icons.error_outline, color: scheme.onErrorContainer),
              title: Text(t.rejected, style: TextStyle(color: scheme.onErrorContainer)),
              subtitle: Text(explainRejection(t, '${r['message']}'), style: TextStyle(color: scheme.onErrorContainer)),
              trailing: TextButton(onPressed: () => repo.dismissRejection(r['id'] as String), child: Text(t.dismiss)),
            ),
          ),
      ]),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);
  final String text;

  @override
  Widget build(BuildContext context) =>
      Center(child: Padding(padding: const EdgeInsets.all(32), child: Text(text, textAlign: TextAlign.center)));
}
