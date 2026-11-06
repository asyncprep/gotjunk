import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/profit_share.dart';
import '../data/profit_share_repo.dart';
import '../data/repo.dart';
import '../l10n/app_localizations.dart';
import 'format.dart';

/// The bottom of the paper route sheet, filled in as the day goes: each crew member's profit
/// share, what it depends on, and what's still missing to qualify.
class ProfitShareCard extends StatefulWidget {
  const ProfitShareCard({super.key, required this.repo, required this.shiftId, required this.editable});
  final Repo repo;
  final String shiftId;
  final bool editable;

  @override
  State<ProfitShareCard> createState() => _ProfitShareCardState();
}

class _ProfitShareCardState extends State<ProfitShareCard> {
  late Stream<ProfitShareData?> _data = widget.repo.profitShareData(widget.shiftId);
  late final Timer _tick;

  // The home screen moves to another route (e.g. today's syncs in after one left open from an
  // earlier day) without rebuilding this card: follow it.
  @override
  void didUpdateWidget(ProfitShareCard old) {
    super.didUpdateWidget(old);
    if (old.shiftId != widget.shiftId || old.repo != widget.repo) {
      _data = widget.repo.profitShareData(widget.shiftId);
    }
  }

  @override
  void initState() {
    super.initState();
    // Hours grow while the route is going: recalculate every minute.
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<ProfitShareData?>(
      stream: _data,
      builder: (context, snap) {
        final data = snap.data;
        if (data == null) return const SizedBox.shrink();
        final r = data.compute(DateTime.now().toUtc());
        final pct = _percent(context);
        final status = r.qualifies ? t.psQualifies : (data.live ? t.psNotYet : t.psNotQualified);
        final statusColor = r.qualifies ? scheme.primaryContainer : scheme.surfaceContainerHighest;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(t.profitShare, style: text.titleSmall)),
                    Chip(label: Text(status), backgroundColor: statusColor, side: BorderSide.none),
                  ],
                ),
                for (final s in r.shares)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        Expanded(child: Text(s.name ?? '…', style: text.bodyLarge)),
                        Text(s.pct == null ? t.psNoRank : pct(s.pct!), style: text.bodySmall),
                        const SizedBox(width: 12),
                        Text(money(context, s.amount), style: text.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                if (r.blocks.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  for (final b in r.blocks)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 18, color: scheme.error),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_block(context, t, r, b, data.plan))),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _Figure(label: t.psRevenuePerHour, value: money(context, r.revenuePerHour)),
                    _Figure(label: t.psCogs, value: r.revenue > 0 ? pct(r.cogsPct) : '—'),
                    _Figure(label: t.psTeamHours, value: _hours(context, r.teamHours)),
                    _Figure(label: t.psAverageJob, value: money(context, r.averageJobSize)),
                  ],
                ),
                if (data.live)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(t.psLive, style: text.bodySmall),
                  ),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(t.psDetails, style: text.labelLarge),
                  children: [
                    _Line(t.revenue, money(context, r.revenue)),
                    _Line(
                      t.psWages(_hours(context, r.wageHours), money(context, data.plan.wagePerHour)),
                      money(context, r.wages),
                    ),
                    _Line(t.psDumps, money(context, r.dumps)),
                    _Line(t.psFranchise(pct(data.plan.franchisePct)), money(context, r.franchise)),
                    _Line(t.psFuel(pct(r.fuelPct)), money(context, r.fuel)),
                    if (r.swingTruck > 0) _Line(t.psSwing, money(context, r.swingTruck)),
                    _Line(t.psTotalCogs, money(context, r.cogs), bold: true),
                    _Line(t.psCogs, r.revenue > 0 ? pct(r.cogsPct) : '—', bold: true),
                  ],
                ),
                _RouteQuestions(repo: widget.repo, shiftId: widget.shiftId, data: data, editable: widget.editable),
              ],
            ),
          ),
        );
      },
    );
  }

  String _block(BuildContext context, L10n t, ProfitShareResult r, ShareBlock b, ProfitSharePlan plan) => switch (b) {
    ShareBlock.revenue => t.psBlockRevenue(money(context, r.revenue), money(context, r.minRevenue)),
    ShareBlock.revenuePerHour => t.psBlockRph(money(context, r.revenuePerHour), money(context, r.minRevenuePerHour)),
    ShareBlock.cogs => t.psBlockCogs(_percent(context)(plan.maxCogsPct)),
    ShareBlock.damages => t.psBlockDamages,
    ShareBlock.hoursType => t.psBlockHours,
  };
}

/// "39,87 %" in French, "39.87%" in English.
String Function(double) _percent(BuildContext context) {
  final fr = Localizations.localeOf(context).languageCode == 'fr';
  final f = NumberFormat('#,##0.##', fr ? 'fr_CA' : 'en_CA');
  return (v) => fr ? '${f.format(v)} %' : '${f.format(v)}%';
}

String _hours(BuildContext context, double h) =>
    NumberFormat('#,##0.##', Localizations.localeOf(context).languageCode == 'fr' ? 'fr_CA' : 'en_CA').format(h);

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          Text(label, style: text.bodySmall),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.bold = false});
  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = bold ? const TextStyle(fontWeight: FontWeight.w600) : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

/// The server's limit on shift.swing_truck_count.
const _maxSwingTrucks = 20;

/// What the paper sheet asked that only the crew knows: trucks used, swing trucks, training.
class _RouteQuestions extends StatelessWidget {
  const _RouteQuestions({required this.repo, required this.shiftId, required this.data, required this.editable});
  final Repo repo;
  final String shiftId;
  final ProfitShareData data;
  final bool editable;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final route = data.route;
    final maxHours = data.plan.trainingHoursMax;
    final hourChoices = [for (var h = 0.0; h <= maxHours + 0.001; h += 0.5) h];
    final fuelLabel = switch (route.fuelMode) {
      'split_day' => t.psFuelSplit,
      'two_trucks' => t.psFuelTwo,
      _ => t.psFuelOne,
    };
    // Answered once a day: folded away, with the current answers in the subtitle.
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      title: Text(t.psForCalculation, style: Theme.of(context).textTheme.labelLarge),
      subtitle: Text(
        [
          fuelLabel,
          if (route.swingTrucks > 0) '${t.psSwing} × ${route.swingTrucks}',
          if (route.trainingDay) '${t.psTrainingDay} (${_hours(context, route.trainingHoursRemoved)} h)',
        ].join(' · '),
      ),
      children: [
        SegmentedButton<String>(
          segments: [
            ButtonSegment(value: 'one_truck', label: Text(t.psFuelOne)),
            ButtonSegment(value: 'split_day', label: Text(t.psFuelSplit)),
            ButtonSegment(value: 'two_trucks', label: Text(t.psFuelTwo)),
          ],
          selected: {route.fuelMode},
          showSelectedIcon: false,
          onSelectionChanged: editable ? (v) => repo.setFuelMode(shiftId, v.first) : null,
        ),
        Row(
          children: [
            Expanded(child: Text(t.psSwingUsed)),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              tooltip: t.psSwingLess,
              onPressed: editable && route.swingTrucks > 0
                  ? () => repo.setSwingTrucks(shiftId, route.swingTrucks - 1)
                  : null,
            ),
            SizedBox(
              width: 32,
              child: Text('${route.swingTrucks}', textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: t.psSwingMore,
              onPressed: editable && route.swingTrucks < _maxSwingTrucks
                  ? () => repo.setSwingTrucks(shiftId, route.swingTrucks + 1)
                  : null,
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(t.psTrainingDay),
          value: route.trainingDay,
          onChanged: editable
              ? (v) => repo.setTraining(shiftId, day: v, hoursRemoved: v ? route.trainingHoursRemoved : 0)
              : null,
        ),
        if (route.trainingDay)
          Row(
            children: [
              Expanded(child: Text(t.psTrainingHours)),
              DropdownButton<double>(
                value: hourChoices.contains(route.trainingHoursRemoved) ? route.trainingHoursRemoved : null,
                items: [for (final h in hourChoices) DropdownMenuItem(value: h, child: Text(_hours(context, h)))],
                onChanged: editable ? (h) => repo.setTraining(shiftId, day: true, hoursRemoved: h ?? 0) : null,
              ),
            ],
          ),
      ],
    );
  }
}
