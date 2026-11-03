import 'package:flutter_test/flutter_test.dart';
import 'package:truck_team_os/data/profit_share.dart';

// The three filled route sheets of Oct 25, 2026 (docs/profit-share.md) are the expected results.
const plan = ProfitSharePlan();

CrewShareInput recruit(double h) => CrewShareInput(employeeId: 'r', hours: h);
CrewShareInput wingman(double h) =>
    CrewShareInput(employeeId: 'w', hours: h, pctLowCogs: 3, pctMidCogs: 2, pctHighCogs: 1);
CrewShareInput professional(double h) =>
    CrewShareInput(employeeId: 'p', hours: h, pctLowCogs: 4, pctMidCogs: 3, pctHighCogs: 2);
CrewShareInput expert(double h) =>
    CrewShareInput(employeeId: 'e', hours: h, pctLowCogs: 5, pctMidCogs: 4, pctHighCogs: 3);

void main() {
  test('route 1: one truck, training day with 3 hours off wages', () {
    final r = computeProfitShare(plan, RouteShareInput(
      revenue: 3522, jobs: 9, dumps: 222 - 3.10, crew: [expert(10.75), recruit(10.75)],
      hoursType: 'regular_junk', trainingDay: true, trainingHoursRemoved: 3,
    ));
    expect(r.teamHours, 21.5);
    expect(r.revenuePerHour, 163.81, reason: 'the sheet uses all hours for revenue per hour (A13)');
    expect(r.averageJobSize, 391.33);
    expect(r.wages, 481.00);
    expect(r.franchise, 563.52);
    expect(r.fuel, 140.88);
    expect(r.cogs, 1404.30);
    expect(r.cogsPct, 39.87);
    expect(r.band, CogsBand.low);
    expect(r.qualifies, isTrue);
    expect(r.shares.map((s) => s.amount), [176.10, 0]);
    expect(r.shares.last.pct, isNull, reason: 'no % for that rank');
  });

  test('route 2: two trucks', () {
    final r = computeProfitShare(plan, RouteShareInput(
      revenue: 4196, jobs: 5, dumps: 346.70 - 80, crew: [wingman(10.25), professional(10.5)],
      hoursType: 'regular_junk', fuelMode: 'two_trucks',
    ));
    expect(r.revenuePerHour, 202.22);
    expect(r.wages, 539.50);
    expect(r.fuel, 293.72);
    expect(r.cogs, 1771.28);
    expect(r.band, CogsBand.low);
    expect(r.shares.map((s) => s.amount), [125.88, 167.84]);
  });

  test('route 3: under 18 team hours, middle COGS band', () {
    final r = computeProfitShare(plan, RouteShareInput(
      revenue: 2935.40, jobs: 7, dumps: 189 - 12, crew: [wingman(8.75), professional(8.75)],
      hoursType: 'regular_junk', fuelMode: 'two_trucks',
    ));
    expect(r.minRevenue, 1500, reason: 'small team');
    expect(r.franchise, 469.66);
    expect(r.fuel, 205.48);
    expect(r.cogs, 1307.14);
    expect(r.cogsPct, 44.53);
    expect(r.band, CogsBand.mid);
    expect(r.shares.map((s) => s.amount), [58.71, 88.06]);
  });

  test('no share below the minimums, over 50% COGS, with damages or non-junk hours', () {
    RouteShareInput route({double revenue = 3000, bool damages = false, String hours = 'regular_junk', double dumps = 0}) =>
        RouteShareInput(revenue: revenue, jobs: 5, dumps: dumps, crew: [wingman(10), professional(10)],
            hoursType: hours, damages: damages);
    expect(computeProfitShare(plan, route(revenue: 1900)).blocks, contains(ShareBlock.revenue));
    expect(computeProfitShare(plan, route(revenue: 2600)).blocks, contains(ShareBlock.revenuePerHour),
        reason: r'$130 an hour');
    final over = computeProfitShare(plan, route(dumps: 900));
    expect(over.band, CogsBand.over);
    expect(over.blocks, [ShareBlock.cogs]);
    expect(over.total, 0);
    expect(computeProfitShare(plan, route(damages: true)).blocks, [ShareBlock.damages]);
    expect(computeProfitShare(plan, route(hours: 'warehouse')).blocks, [ShareBlock.hoursType]);
    expect(computeProfitShare(plan, route()).qualifies, isTrue);
  });

  test('swing truck fee and split-day fuel', () {
    final r = computeProfitShare(plan, RouteShareInput(
      revenue: 3000, jobs: 5, dumps: 0, crew: [wingman(10), professional(10)], fuelMode: 'split_day', swingTruck: true,
    ));
    expect(r.fuel, 165);
    expect(r.swingTruck, 60);
    expect(r.cogs, 520 + 480 + 165 + 60);
  });

  test('plan read from the server setting, defaults for anything missing', () {
    final p = ProfitSharePlan.fromSetting('{"wage_per_hour": 27, "fuel_pct": {"one_truck": 5}, "training_hours_off_revenue_per_hour": true}');
    expect(p.wagePerHour, 27);
    expect(p.fuelPct['one_truck'], 5);
    expect(p.trainingHoursOffRevenuePerHour, isTrue);
    expect(p.franchisePct, 16);
    expect(ProfitSharePlan.fromSetting('not json').wagePerHour, 26);
  });

  test('the short-day minimum follows the team size set by the admin', () {
    final route = RouteShareInput(revenue: 1800, jobs: 4, dumps: 0, crew: [wingman(8), professional(8)], hoursType: 'regular_junk');
    expect(computeProfitShare(plan, route).minRevenue, 1500, reason: 'team of 2 under 18 hours');
    final threeOrMore = ProfitSharePlan.fromSetting('{"small_team_min_crew": 3}');
    expect(computeProfitShare(threeOrMore, route).minRevenue, 2000);
  });

  test('crew hours count from the route start to finish, leaving, or now', () {
    final start = DateTime.utc(2026, 10, 25, 12);
    final now = DateTime.utc(2026, 10, 25, 15, 30);
    expect(crewHours(routeStart: start, routeFinish: null, joinedAt: DateTime.utc(2020), leftAt: null, now: now), 3.5);
    expect(crewHours(routeStart: start, routeFinish: DateTime.utc(2026, 10, 25, 22, 45), joinedAt: null, leftAt: null, now: now),
        10.75);
    expect(crewHours(routeStart: start, routeFinish: null, joinedAt: DateTime.utc(2026, 10, 25, 13),
        leftAt: DateTime.utc(2026, 10, 25, 14), now: now), 1);
    expect(crewHours(routeStart: null, routeFinish: null, joinedAt: null, leftAt: null, now: now), 0);
  });
}
