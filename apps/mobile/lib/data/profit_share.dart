import 'dart:convert';
import 'dart:math' as math;

/// The profit-share plan from the paper route sheet (Aug 2024), as set on the server
/// (app_setting 'profit_share_plan'). Defaults are the sheet's values.
class ProfitSharePlan {
  const ProfitSharePlan({
    this.wagePerHour = 26,
    this.franchisePct = 16,
    this.fuelPct = const {'one_truck': 4, 'split_day': 5.5, 'two_trucks': 7},
    this.swingTruckFee = 60,
    this.minRevenue = 2000,
    this.minRevenuePerHour = 135,
    this.smallTeamHours = 18,
    this.smallTeamMinCrew = 2,
    this.smallTeamMinRevenue = 1500,
    this.trainingMinRevenue = 1500,
    this.trainingMinRevenuePerHour = 125,
    this.trainingHoursMax = 3,
    this.trainingHoursOffRevenuePerHour = true,
    this.lowCogsMaxPct = 43,
    this.midCogsMaxPct = 47,
    this.maxCogsPct = 50,
    this.hoursTypes = const {'regular_junk'},
  });

  /// Missing or unreadable values keep the sheet's default.
  factory ProfitSharePlan.fromSetting(Object? value) {
    Map<String, dynamic> j;
    try {
      final decoded = value is String ? jsonDecode(value) : value;
      j = decoded is Map<String, dynamic> ? decoded : const {};
    } catch (_) {
      j = const {};
    }
    const d = ProfitSharePlan();
    double n(String key, double fallback) => (j[key] as num?)?.toDouble() ?? fallback;
    final fuel = j['fuel_pct'];
    final types = j['hours_types'];
    return ProfitSharePlan(
      wagePerHour: n('wage_per_hour', d.wagePerHour),
      franchisePct: n('franchise_pct', d.franchisePct),
      fuelPct: fuel is Map ? {for (final e in fuel.entries) '${e.key}': (e.value as num).toDouble()} : d.fuelPct,
      swingTruckFee: n('swing_truck_fee', d.swingTruckFee),
      minRevenue: n('min_revenue', d.minRevenue),
      minRevenuePerHour: n('min_revenue_per_hour', d.minRevenuePerHour),
      smallTeamHours: n('small_team_hours', d.smallTeamHours),
      smallTeamMinCrew: n('small_team_min_crew', d.smallTeamMinCrew),
      smallTeamMinRevenue: n('small_team_min_revenue', d.smallTeamMinRevenue),
      trainingMinRevenue: n('training_min_revenue', d.trainingMinRevenue),
      trainingMinRevenuePerHour: n('training_min_revenue_per_hour', d.trainingMinRevenuePerHour),
      trainingHoursMax: n('training_hours_max', d.trainingHoursMax),
      trainingHoursOffRevenuePerHour:
          j['training_hours_off_revenue_per_hour'] as bool? ?? d.trainingHoursOffRevenuePerHour,
      lowCogsMaxPct: n('low_cogs_max_pct', d.lowCogsMaxPct),
      midCogsMaxPct: n('mid_cogs_max_pct', d.midCogsMaxPct),
      maxCogsPct: n('max_cogs_pct', d.maxCogsPct),
      hoursTypes: types is List ? {for (final t in types) '$t'} : d.hoursTypes,
    );
  }

  final double wagePerHour;
  final double franchisePct;
  final Map<String, double> fuelPct;
  final double swingTruckFee;
  final double minRevenue;
  final double minRevenuePerHour;
  final double smallTeamHours;
  /// The short-day minimum applies to a team of at least this many people.
  final double smallTeamMinCrew;
  final double smallTeamMinRevenue;
  final double trainingMinRevenue;
  final double trainingMinRevenuePerHour;
  final double trainingHoursMax;
  /// Client, Nov 12: the trainer's removed hours also come off revenue per hour.
  final bool trainingHoursOffRevenuePerHour;
  final double lowCogsMaxPct;
  final double midCogsMaxPct;
  final double maxCogsPct;
  final Set<String> hoursTypes;
}

/// One crew member: their hours on the route and their rank's % per COGS band (null = none).
class CrewShareInput {
  const CrewShareInput({
    required this.employeeId,
    this.name,
    required this.hours,
    this.pctLowCogs,
    this.pctMidCogs,
    this.pctHighCogs,
    this.shareToTrainer = false,
    this.trainer = false,
    this.damageHold = false,
  });
  final String employeeId;
  final String? name;
  final double hours;
  final double? pctLowCogs;
  final double? pctMidCogs;
  final double? pctHighCogs;
  /// Recruit: the share is calculated but paid to the route's trainer.
  final bool shareToTrainer;
  /// Chosen by dispatch: receives the shares of the Recruits on the route.
  final bool trainer;
  /// Caused damage (dispatch): the share is held back for the repair.
  final bool damageHold;
}

class RouteShareInput {
  const RouteShareInput({
    required this.revenue,
    required this.jobs,
    this.cancels = 0,
    required this.dumps,
    required this.crew,
    this.hoursType,
    this.fuelMode = 'one_truck',
    this.swingTrucks = 0,
    this.trainingDay = false,
    this.trainingHoursRemoved = 0,
  });
  /// Route revenue before tax (sum of completed jobs, after discount).
  final double revenue;
  final int jobs;
  final int cancels;
  /// Disposal costs minus credits.
  final double dumps;
  final List<CrewShareInput> crew;
  final String? hoursType;
  final String fuelMode;
  /// Swing trucks used on the route; the fee is charged for each one.
  final int swingTrucks;
  final bool trainingDay;
  final double trainingHoursRemoved;
}

enum CogsBand { low, mid, high, over }

/// Why the route doesn't (yet) earn a profit share. Damages don't block the route: they hold back
/// the share of the person who caused them (client, Nov 12).
enum ShareBlock { revenue, revenuePerHour, cogs, hoursType }

class CrewShare {
  const CrewShare({
    required this.employeeId,
    this.name,
    required this.pct,
    required this.amount,
    this.fromTrainees = 0,
    this.toTrainer = false,
    this.trainer = false,
    this.held = false,
  });
  final String employeeId;
  final String? name;
  /// Null when the rank has no profit share.
  final double? pct;
  /// This person's own calculated share.
  final double amount;
  /// Recruits' shares passed to this person as the route's trainer.
  final double fromTrainees;
  /// A Recruit: [amount] goes to the trainer, not to them.
  final bool toTrainer;
  final bool trainer;
  /// Caused damage: everything they would get is held back for the repair.
  final bool held;

  /// What goes to payroll for this person.
  double get payout => held || toTrainer ? 0 : _cents(amount + fromTrainees);
  /// What is set aside for the repair.
  double get heldAmount => held && !toTrainer ? _cents(amount + fromTrainees) : 0;
}

class ProfitShareResult {
  const ProfitShareResult({
    required this.revenue,
    required this.teamHours,
    required this.wageHours,
    required this.revenuePerHour,
    required this.averageJobSize,
    required this.cancelRate,
    required this.wages,
    required this.dumps,
    required this.franchise,
    required this.fuelPct,
    required this.fuel,
    required this.swingTruck,
    required this.cogs,
    required this.cogsPct,
    required this.band,
    required this.minRevenue,
    required this.minRevenuePerHour,
    required this.blocks,
    required this.shares,
  });
  final double revenue;
  final double teamHours;
  final double wageHours;
  final double revenuePerHour;
  final double averageJobSize;
  final double cancelRate;
  final double wages;
  final double dumps;
  final double franchise;
  final double fuelPct;
  final double fuel;
  final double swingTruck;
  final double cogs;
  final double cogsPct;
  final CogsBand band;
  final double minRevenue;
  final double minRevenuePerHour;
  final List<ShareBlock> blocks;
  final List<CrewShare> shares;

  bool get qualifies => blocks.isEmpty;
  /// Every share calculated on the route, whoever it is paid to.
  double get total => _cents(shares.fold(0, (s, c) => s + c.amount));
  /// Recruits' shares while no trainer is chosen: paid to nobody until dispatch picks one.
  double get waitingForTrainer => shares.any((s) => s.trainer)
      ? 0
      : _cents(shares.where((s) => s.toTrainer).fold(0, (s, c) => s + c.amount));
}

double _cents(double v) => (v * 100).roundToDouble() / 100;

/// The sheet's calculation. Each line is rounded to the cent as on paper; COGS % to 0.01.
ProfitShareResult computeProfitShare(ProfitSharePlan plan, RouteShareInput r) {
  final teamHours = r.crew.fold<double>(0, (s, c) => s + c.hours);
  final removed = r.trainingDay ? math.min(math.max(r.trainingHoursRemoved, 0), plan.trainingHoursMax) : 0.0;
  final wageHours = math.max(teamHours - removed, 0.0);
  final rphHours = plan.trainingHoursOffRevenuePerHour ? wageHours : teamHours;
  final revenuePerHour = rphHours > 0 ? _cents(r.revenue / rphHours) : 0.0;

  final wages = _cents(wageHours * plan.wagePerHour);
  final dumps = _cents(r.dumps);
  final franchise = _cents(r.revenue * plan.franchisePct / 100);
  final fuelPct = plan.fuelPct[r.fuelMode] ?? plan.fuelPct['one_truck'] ?? 0;
  final fuel = _cents(r.revenue * fuelPct / 100);
  final swing = r.swingTrucks * plan.swingTruckFee;
  final cogs = _cents(wages + dumps + franchise + fuel + swing);
  final cogsPct = r.revenue > 0 ? (cogs / r.revenue * 10000).roundToDouble() / 100 : double.infinity;

  final band = cogsPct <= plan.lowCogsMaxPct
      ? CogsBand.low
      : cogsPct <= plan.midCogsMaxPct
          ? CogsBand.mid
          : cogsPct <= plan.maxCogsPct
              ? CogsBand.high
              : CogsBand.over;

  final smallTeam = r.crew.length >= plan.smallTeamMinCrew && teamHours < plan.smallTeamHours;
  final minRevenue = r.trainingDay
      ? plan.trainingMinRevenue
      : smallTeam
          ? plan.smallTeamMinRevenue
          : plan.minRevenue;
  final minRph = r.trainingDay ? plan.trainingMinRevenuePerHour : plan.minRevenuePerHour;

  final blocks = <ShareBlock>[
    if (r.hoursType != null && !plan.hoursTypes.contains(r.hoursType)) ShareBlock.hoursType,
    if (r.revenue < minRevenue) ShareBlock.revenue,
    if (revenuePerHour < minRph) ShareBlock.revenuePerHour,
    if (band == CogsBand.over) ShareBlock.cogs,
  ];

  double? pctOf(CrewShareInput c) => switch (band) {
        CogsBand.low => c.pctLowCogs,
        CogsBand.mid => c.pctMidCogs,
        CogsBand.high => c.pctHighCogs,
        CogsBand.over => null,
      };
  double amountOf(CrewShareInput c) {
    final pct = pctOf(c);
    return blocks.isEmpty && pct != null ? _cents(r.revenue * pct / 100) : 0;
  }

  // A Recruit marked as trainer can't receive Recruits' shares; they wait for a real trainer.
  final trainerId = r.crew.where((c) => c.trainer && !c.shareToTrainer).firstOrNull?.employeeId;
  final traineeTotal = _cents(r.crew.where((c) => c.shareToTrainer).fold(0.0, (s, c) => s + amountOf(c)));
  final shares = [
    for (final c in r.crew)
      CrewShare(
        employeeId: c.employeeId,
        name: c.name,
        pct: pctOf(c),
        amount: amountOf(c),
        fromTrainees: c.employeeId == trainerId ? traineeTotal : 0,
        toTrainer: c.shareToTrainer,
        trainer: c.employeeId == trainerId,
        held: c.damageHold,
      ),
  ];

  final booked = r.jobs + r.cancels;
  return ProfitShareResult(
    revenue: r.revenue,
    teamHours: teamHours,
    wageHours: wageHours,
    revenuePerHour: revenuePerHour,
    averageJobSize: r.jobs > 0 ? _cents(r.revenue / r.jobs) : 0,
    cancelRate: booked > 0 ? r.cancels / booked : 0,
    wages: wages,
    dumps: dumps,
    franchise: franchise,
    fuelPct: fuelPct,
    fuel: fuel,
    swingTruck: swing,
    cogs: cogs,
    cogsPct: cogsPct,
    band: band,
    minRevenue: minRevenue,
    minRevenuePerHour: minRph,
    blocks: blocks,
    shares: shares,
  );
}

/// Hours a crew member worked on the route: from when both they and the route started to when
/// they left or the route finished, or until [now] while the route is still going.
double crewHours({
  required DateTime? routeStart,
  required DateTime? routeFinish,
  required DateTime? joinedAt,
  required DateTime? leftAt,
  required DateTime now,
}) {
  if (routeStart == null) return 0;
  final from = joinedAt != null && joinedAt.isAfter(routeStart) ? joinedAt : routeStart;
  var to = routeFinish ?? now;
  if (leftAt != null && leftAt.isBefore(to)) to = leftAt;
  final minutes = to.difference(from).inSeconds / 60;
  return minutes > 0 ? minutes / 60 : 0;
}
