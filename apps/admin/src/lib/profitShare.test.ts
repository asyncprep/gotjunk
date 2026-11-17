import { describe, expect, it } from 'vitest';
import { computeProfitShare, crewHours, defaultPlan, planFromSetting, type CrewShareInput } from './profitShare';

// Same cases as the crew app (apps/mobile/test/profit_share_test.dart): the client's sheets of Oct 25, 2026.
const plan = defaultPlan;
const sheetPlan = { ...defaultPlan, trainingHoursOffRevenuePerHour: false };
const recruit = (h: number): CrewShareInput => ({ employeeId: 'r', hours: h, pctLowCogs: 3, pctMidCogs: 2, pctHighCogs: 1, shareToTrainer: true });
const wingman = (h: number): CrewShareInput => ({ employeeId: 'w', hours: h, pctLowCogs: 3, pctMidCogs: 2, pctHighCogs: 1 });
const professional = (h: number): CrewShareInput => ({ employeeId: 'p', hours: h, pctLowCogs: 4, pctMidCogs: 3, pctHighCogs: 2 });
const expert = (h: number, o: { trainer?: boolean; damageHold?: boolean } = {}): CrewShareInput =>
  ({ employeeId: 'e', hours: h, pctLowCogs: 5, pctMidCogs: 4, pctHighCogs: 3, ...o });

describe('profit share, as on the paper route sheet', () => {
  it('route 1: one truck, training day with 3 hours off wages', () => {
    const r = computeProfitShare(sheetPlan, {
      revenue: 3522, jobs: 9, dumps: 222 - 3.10, crew: [expert(10.75), recruit(10.75)],
      hoursType: 'regular_junk', trainingDay: true, trainingHoursRemoved: 3,
    });
    expect(r.teamHours).toBe(21.5);
    expect(r.revenuePerHour).toBe(163.81);
    expect(r.averageJobSize).toBe(391.33);
    expect(r.wages).toBe(481);
    expect(r.franchise).toBe(563.52);
    expect(r.fuel).toBe(140.88);
    expect(r.cogs).toBe(1404.3);
    expect(r.cogsPct).toBe(39.87);
    expect(r.band).toBe('low');
    expect(r.qualifies).toBe(true);
    expect(r.shares[0].amount).toBe(176.1);
  });

  it("a Recruit's share goes to the trainer chosen by dispatch", () => {
    const route = (trainer: boolean) => computeProfitShare(plan, {
      revenue: 3522, jobs: 9, dumps: 218.9, crew: [expert(10.75, { trainer }), recruit(10.75)],
      hoursType: 'regular_junk', trainingDay: true, trainingHoursRemoved: 3,
    });
    const r = route(true);
    expect(r.revenuePerHour).toBe(190.38);
    expect(r.shares[1].amount).toBe(105.66);
    expect(r.shares[1].payout).toBe(0);
    expect(r.shares[0].payout).toBe(281.76);
    expect(route(false).waitingForTrainer).toBe(105.66);
  });

  it('damage holds back only that person\'s share', () => {
    const r = computeProfitShare(plan, {
      revenue: 4196, jobs: 5, dumps: 266.7, crew: [wingman(10.25), expert(10.5, { damageHold: true })],
      hoursType: 'regular_junk', fuelMode: 'two_trucks',
    });
    expect(r.qualifies).toBe(true);
    expect(r.shares[0].payout).toBe(125.88);
    expect(r.shares[1].heldAmount).toBe(209.8);
  });

  it('route 2: two trucks', () => {
    const r = computeProfitShare(plan, {
      revenue: 4196, jobs: 5, dumps: 346.7 - 80, crew: [wingman(10.25), professional(10.5)],
      hoursType: 'regular_junk', fuelMode: 'two_trucks',
    });
    expect(r.revenuePerHour).toBe(202.22);
    expect(r.wages).toBe(539.5);
    expect(r.fuel).toBe(293.72);
    expect(r.cogs).toBe(1771.28);
    expect(r.shares.map((s) => s.amount)).toEqual([125.88, 167.84]);
  });

  it('route 3: under 18 team hours, middle COGS band', () => {
    const r = computeProfitShare(plan, {
      revenue: 2935.4, jobs: 7, dumps: 189 - 12, crew: [wingman(8.75), professional(8.75)],
      hoursType: 'regular_junk', fuelMode: 'two_trucks',
    });
    expect(r.minRevenue).toBe(1500);
    expect(r.cogs).toBe(1307.14);
    expect(r.cogsPct).toBe(44.53);
    expect(r.band).toBe('mid');
    expect(r.shares.map((s) => s.amount)).toEqual([58.71, 88.06]);
  });

  it('no share below the minimums, over 50% COGS, or with non-junk hours', () => {
    const route = (o: { revenue?: number; hours?: string; dumps?: number } = {}) => computeProfitShare(plan, {
      revenue: o.revenue ?? 3000, jobs: 5, dumps: o.dumps ?? 0, crew: [wingman(10), professional(10)],
      hoursType: o.hours ?? 'regular_junk',
    });
    expect(route({ revenue: 1900 }).blocks).toContain('revenue');
    expect(route({ revenue: 2600 }).blocks).toContain('revenuePerHour');
    expect(route({ dumps: 900 }).blocks).toEqual(['cogs']);
    expect(route({ dumps: 900 }).total).toBe(0);
    expect(route({ hours: 'warehouse' }).blocks).toEqual(['hoursType']);
    expect(route().qualifies).toBe(true);
  });

  it('swing truck fee and split-day fuel', () => {
    const r = computeProfitShare(plan, {
      revenue: 3000, jobs: 5, dumps: 0, crew: [wingman(10), professional(10)], fuelMode: 'split_day', swingTrucks: 3,
    });
    expect(r.fuel).toBe(165);
    expect(r.swingTruck).toBe(180);
    expect(r.cogs).toBe(520 + 480 + 165 + 180);
  });

  it('reads the plan from the server setting, with defaults for anything missing', () => {
    const p = planFromSetting({ wage_per_hour: 27, fuel_pct: { one_truck: 5 }, training_hours_off_revenue_per_hour: false });
    expect(p.wagePerHour).toBe(27);
    expect(p.fuelPct.one_truck).toBe(5);
    expect(p.trainingHoursOffRevenuePerHour).toBe(false);
    expect(p.franchisePct).toBe(16);
    expect(planFromSetting('not json').wagePerHour).toBe(26);
  });

  it('crew hours count from the route start to finish, leaving, or now', () => {
    const start = new Date(Date.UTC(2026, 9, 25, 12));
    const now = new Date(Date.UTC(2026, 9, 25, 15, 30));
    expect(crewHours({ routeStart: start, routeFinish: null, joinedAt: new Date(Date.UTC(2020, 0, 1)), leftAt: null, now })).toBe(3.5);
    expect(crewHours({ routeStart: start, routeFinish: new Date(Date.UTC(2026, 9, 25, 22, 45)), joinedAt: null, leftAt: null, now })).toBe(10.75);
    expect(crewHours({ routeStart: null, routeFinish: null, joinedAt: null, leftAt: null, now })).toBe(0);
  });
});
