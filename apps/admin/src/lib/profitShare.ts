// The profit-share calculation of the paper route sheet (Aug 2024), the same as the crew app's
// (apps/mobile/lib/data/profit_share.dart). Keep the two in step; both test the client's three
// filled sheets of Oct 25, 2026 (docs/profit-share.md).

export type ProfitSharePlan = {
  wagePerHour: number;
  franchisePct: number;
  fuelPct: Record<string, number>;
  swingTruckFee: number;
  minRevenue: number;
  minRevenuePerHour: number;
  smallTeamHours: number;
  /** The short-day minimum applies to a team of at least this many people. */
  smallTeamMinCrew: number;
  smallTeamMinRevenue: number;
  trainingMinRevenue: number;
  trainingMinRevenuePerHour: number;
  trainingHoursMax: number;
  /** Client, Nov 12: the trainer's removed hours also come off revenue per hour. */
  trainingHoursOffRevenuePerHour: boolean;
  lowCogsMaxPct: number;
  midCogsMaxPct: number;
  maxCogsPct: number;
  hoursTypes: string[];
};

export const defaultPlan: ProfitSharePlan = {
  wagePerHour: 26,
  franchisePct: 16,
  fuelPct: { one_truck: 4, split_day: 5.5, two_trucks: 7 },
  swingTruckFee: 60,
  minRevenue: 2000,
  minRevenuePerHour: 135,
  smallTeamHours: 18,
  smallTeamMinCrew: 2,
  smallTeamMinRevenue: 1500,
  trainingMinRevenue: 1500,
  trainingMinRevenuePerHour: 125,
  trainingHoursMax: 3,
  trainingHoursOffRevenuePerHour: true,
  lowCogsMaxPct: 43,
  midCogsMaxPct: 47,
  maxCogsPct: 50,
  hoursTypes: ['regular_junk'],
};

/** The plan from app_setting 'profit_share_plan'; missing or unreadable values keep the sheet's default. */
export function planFromSetting(value: unknown): ProfitSharePlan {
  let j: Record<string, unknown> = {};
  try {
    const decoded = typeof value === 'string' ? JSON.parse(value) : value;
    if (decoded && typeof decoded === 'object' && !Array.isArray(decoded)) j = decoded as Record<string, unknown>;
  } catch { /* keep the defaults */ }
  const d = defaultPlan;
  const n = (key: string, fallback: number) => (typeof j[key] === 'number' ? (j[key] as number) : fallback);
  const fuel = j.fuel_pct;
  const types = j.hours_types;
  return {
    wagePerHour: n('wage_per_hour', d.wagePerHour),
    franchisePct: n('franchise_pct', d.franchisePct),
    fuelPct: fuel && typeof fuel === 'object' && !Array.isArray(fuel)
      ? Object.fromEntries(Object.entries(fuel).map(([k, v]) => [k, Number(v)])) : d.fuelPct,
    swingTruckFee: n('swing_truck_fee', d.swingTruckFee),
    minRevenue: n('min_revenue', d.minRevenue),
    minRevenuePerHour: n('min_revenue_per_hour', d.minRevenuePerHour),
    smallTeamHours: n('small_team_hours', d.smallTeamHours),
    smallTeamMinCrew: n('small_team_min_crew', d.smallTeamMinCrew),
    smallTeamMinRevenue: n('small_team_min_revenue', d.smallTeamMinRevenue),
    trainingMinRevenue: n('training_min_revenue', d.trainingMinRevenue),
    trainingMinRevenuePerHour: n('training_min_revenue_per_hour', d.trainingMinRevenuePerHour),
    trainingHoursMax: n('training_hours_max', d.trainingHoursMax),
    trainingHoursOffRevenuePerHour: typeof j.training_hours_off_revenue_per_hour === 'boolean'
      ? j.training_hours_off_revenue_per_hour : d.trainingHoursOffRevenuePerHour,
    lowCogsMaxPct: n('low_cogs_max_pct', d.lowCogsMaxPct),
    midCogsMaxPct: n('mid_cogs_max_pct', d.midCogsMaxPct),
    maxCogsPct: n('max_cogs_pct', d.maxCogsPct),
    hoursTypes: Array.isArray(types) ? types.map(String) : d.hoursTypes,
  };
}

/** One crew member: their hours on the route and their rank's % per COGS band (null = none). */
export type CrewShareInput = {
  employeeId: string;
  name?: string | null;
  hours: number;
  pctLowCogs?: number | null;
  pctMidCogs?: number | null;
  pctHighCogs?: number | null;
  /** Recruit: the share is calculated but paid to the route's trainer. */
  shareToTrainer?: boolean;
  /** Chosen by dispatch: receives the shares of the Recruits on the route. */
  trainer?: boolean;
  /** Caused damage (dispatch): the share is held back for the repair. */
  damageHold?: boolean;
};

export type RouteShareInput = {
  /** Route revenue before tax (sum of completed jobs, after discount). */
  revenue: number;
  jobs: number;
  cancels?: number;
  /** Disposal costs minus credits. */
  dumps: number;
  crew: CrewShareInput[];
  hoursType?: string | null;
  fuelMode?: string;
  swingTrucks?: number;
  trainingDay?: boolean;
  trainingHoursRemoved?: number;
};

export type CogsBand = 'low' | 'mid' | 'high' | 'over';
/** Why the route doesn't (yet) earn a profit share. Damages don't block it (client, Nov 12). */
export type ShareBlock = 'hoursType' | 'revenue' | 'revenuePerHour' | 'cogs';

export type CrewShare = {
  employeeId: string;
  name?: string | null;
  /** Null when the rank has no profit share. */
  pct: number | null;
  /** This person's own calculated share. */
  amount: number;
  /** Recruits' shares passed to this person as the route's trainer. */
  fromTrainees: number;
  /** A Recruit: amount goes to the trainer, not to them. */
  toTrainer: boolean;
  trainer: boolean;
  /** Caused damage: everything they would get is held back for the repair. */
  held: boolean;
  /** What goes to payroll for this person. */
  payout: number;
  /** What is set aside for the repair. */
  heldAmount: number;
};

export type ProfitShareResult = {
  revenue: number;
  teamHours: number;
  wageHours: number;
  revenuePerHour: number;
  averageJobSize: number;
  cancelRate: number;
  wages: number;
  dumps: number;
  franchise: number;
  fuelPct: number;
  fuel: number;
  swingTruck: number;
  cogs: number;
  cogsPct: number;
  band: CogsBand;
  minRevenue: number;
  minRevenuePerHour: number;
  blocks: ShareBlock[];
  shares: CrewShare[];
  qualifies: boolean;
  /** Every share calculated on the route, whoever it is paid to. */
  total: number;
  /** Recruits' shares while no trainer is chosen: paid to nobody until dispatch picks one. */
  waitingForTrainer: number;
};

const cents = (v: number) => Math.round(v * 100) / 100;

/** The sheet's calculation. Each line is rounded to the cent as on paper; COGS % to 0.01. */
export function computeProfitShare(plan: ProfitSharePlan, r: RouteShareInput): ProfitShareResult {
  const teamHours = r.crew.reduce((s, c) => s + c.hours, 0);
  const removed = r.trainingDay ? Math.min(Math.max(r.trainingHoursRemoved ?? 0, 0), plan.trainingHoursMax) : 0;
  const wageHours = Math.max(teamHours - removed, 0);
  const rphHours = plan.trainingHoursOffRevenuePerHour ? wageHours : teamHours;
  const revenuePerHour = rphHours > 0 ? cents(r.revenue / rphHours) : 0;

  const wages = cents(wageHours * plan.wagePerHour);
  const dumps = cents(r.dumps);
  const franchise = cents(r.revenue * plan.franchisePct / 100);
  const fuelPct = plan.fuelPct[r.fuelMode ?? 'one_truck'] ?? plan.fuelPct.one_truck ?? 0;
  const fuel = cents(r.revenue * fuelPct / 100);
  const swing = (r.swingTrucks ?? 0) * plan.swingTruckFee;
  const cogs = cents(wages + dumps + franchise + fuel + swing);
  const cogsPct = r.revenue > 0 ? Math.round(cogs / r.revenue * 10000) / 100 : Infinity;

  const band: CogsBand = cogsPct <= plan.lowCogsMaxPct ? 'low'
    : cogsPct <= plan.midCogsMaxPct ? 'mid'
      : cogsPct <= plan.maxCogsPct ? 'high' : 'over';

  const smallTeam = r.crew.length >= plan.smallTeamMinCrew && teamHours < plan.smallTeamHours;
  const minRevenue = r.trainingDay ? plan.trainingMinRevenue : smallTeam ? plan.smallTeamMinRevenue : plan.minRevenue;
  const minRph = r.trainingDay ? plan.trainingMinRevenuePerHour : plan.minRevenuePerHour;

  const blocks: ShareBlock[] = [];
  if (r.hoursType != null && !plan.hoursTypes.includes(r.hoursType)) blocks.push('hoursType');
  if (r.revenue < minRevenue) blocks.push('revenue');
  if (revenuePerHour < minRph) blocks.push('revenuePerHour');
  if (band === 'over') blocks.push('cogs');

  const pctOf = (c: CrewShareInput) => (band === 'low' ? c.pctLowCogs : band === 'mid' ? c.pctMidCogs
    : band === 'high' ? c.pctHighCogs : null) ?? null;
  const amountOf = (c: CrewShareInput) => {
    const pct = pctOf(c);
    return blocks.length === 0 && pct != null ? cents(r.revenue * pct / 100) : 0;
  };

  // A Recruit marked as trainer can't receive Recruits' shares; they wait for a real trainer.
  const trainerId = r.crew.find((c) => c.trainer && !c.shareToTrainer)?.employeeId;
  const traineeTotal = cents(r.crew.filter((c) => c.shareToTrainer).reduce((s, c) => s + amountOf(c), 0));
  const shares: CrewShare[] = r.crew.map((c) => {
    const amount = amountOf(c);
    const fromTrainees = c.employeeId === trainerId ? traineeTotal : 0;
    const toTrainer = !!c.shareToTrainer;
    const held = !!c.damageHold;
    return {
      employeeId: c.employeeId, name: c.name, pct: pctOf(c), amount, fromTrainees, toTrainer,
      trainer: c.employeeId === trainerId, held,
      payout: held || toTrainer ? 0 : cents(amount + fromTrainees),
      heldAmount: held && !toTrainer ? cents(amount + fromTrainees) : 0,
    };
  });

  const jobs = r.jobs;
  const cancels = r.cancels ?? 0;
  const booked = jobs + cancels;
  return {
    revenue: r.revenue, teamHours, wageHours, revenuePerHour,
    averageJobSize: jobs > 0 ? cents(r.revenue / jobs) : 0,
    cancelRate: booked > 0 ? cancels / booked : 0,
    wages, dumps, franchise, fuelPct, fuel, swingTruck: swing, cogs, cogsPct, band,
    minRevenue, minRevenuePerHour: minRph, blocks, shares,
    qualifies: blocks.length === 0,
    total: cents(shares.reduce((s, c) => s + c.amount, 0)),
    waitingForTrainer: shares.some((s) => s.trainer) ? 0
      : cents(shares.filter((s) => s.toTrainer).reduce((s, c) => s + c.amount, 0)),
  };
}

/** Hours a crew member worked: from when both they and the route started to when they left or
 * the route finished, or until now while the route is still going. */
export function crewHours(o: {
  routeStart: Date | null; routeFinish: Date | null; joinedAt: Date | null; leftAt: Date | null; now: Date;
}): number {
  if (!o.routeStart) return 0;
  const from = o.joinedAt && o.joinedAt > o.routeStart ? o.joinedAt : o.routeStart;
  let to = o.routeFinish ?? o.now;
  if (o.leftAt && o.leftAt < to) to = o.leftAt;
  const minutes = (to.getTime() - from.getTime()) / 60000;
  return minutes > 0 ? minutes / 60 : 0;
}
