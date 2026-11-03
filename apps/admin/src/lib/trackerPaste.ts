import type { Position } from './supabase';

// Reads the rows dispatch copies from the daily tracker spreadsheet (ROUTE, PHONE, TRUCK,
// POSITION, NAME, START TIME … END TIME). A spreadsheet copy arrives as tab-separated text;
// merged cells only fill their top-left cell, so each route block is read across its rows.

export type PastedMember = { position: Position | null; name: string; start: string | null; end: string | null };
export type PastedRoute = {
  route: string; phone: string; truck: string; secondTruck: string | null; members: PastedMember[];
};

const POSITIONS: Record<string, Position> = {
  driver: 'driver', chauffeur: 'driver', navigator: 'navigator', navigateur: 'navigator',
};

export const normalize = (s: string) =>
  s.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().replace(/[-_.]/g, ' ').replace(/\s+/g, ' ').trim();

/** "7:30", "07h30", "7:30 PM" → "07:30" / "19:30"; anything else → null. */
export function parseTime(cell: string): string | null {
  const m = cell.trim().match(/^(\d{1,2})\s*[:h]\s*(\d{2})(?::\d{2})?\s*([ap]\.?m\.?)?$/i);
  if (!m) return null;
  let h = Number(m[1]);
  const min = Number(m[2]);
  const ampm = m[3]?.[0].toLowerCase();
  if (ampm === 'p' && h < 12) h += 12;
  if (ampm === 'a' && h === 12) h = 0;
  if (h > 23 || min > 59) return null;
  return `${String(h).padStart(2, '0')}:${String(min).padStart(2, '0')}`;
}

type Columns = { route: number; phone: number; truck: number; position: number; name: number; start: number; end: number };

const HEADERS: Record<string, keyof Columns> = {
  route: 'route', phone: 'phone', truck: 'truck', camion: 'truck', telephone: 'phone',
  position: 'position', poste: 'position', name: 'name', nom: 'name',
  'start time': 'start', debut: 'start', 'end time': 'end', fin: 'end',
};

function headerColumns(cells: string[]): Columns | null {
  const found: Partial<Columns> = {};
  cells.forEach((c, i) => {
    const key = HEADERS[normalize(c)];
    if (key && found[key] === undefined) found[key] = i;
  });
  if (found.position === undefined || found.name === undefined) return null;
  return {
    route: found.route ?? -1, phone: found.phone ?? -1, truck: found.truck ?? -1,
    position: found.position, name: found.name, start: found.start ?? -1, end: found.end ?? -1,
  };
}

export function parseTracker(text: string): PastedRoute[] {
  const rows = text.replace(/\r/g, '').split('\n').map((r) => r.split('\t').map((c) => c.trim()));
  let cols: Columns | null = null;
  const routes: PastedRoute[] = [];
  let current: PastedRoute | null = null;

  for (const cells of rows) {
    const header = headerColumns(cells);
    if (header) { cols = header; continue; }
    if (!cols) {
      // No header copied: the POSITION column is the one holding Driver / Navigator.
      const p = cells.findIndex((c) => POSITIONS[normalize(c)]);
      if (p < 0) continue;
      cols = { route: p - 3, phone: p - 2, truck: p - 1, position: p, name: p + 1, start: p + 2, end: -1 };
    }
    const at = (i: number) => (i >= 0 ? cells[i] ?? '' : '');
    const position = POSITIONS[normalize(at(cols.position))] ?? null;
    const name = at(cols.name);
    const startsBlock = at(cols.route) !== '' || at(cols.phone) !== ''
      || (cols.route < 0 && cols.phone < 0 && position === 'driver');

    if (startsBlock || !current) {
      current = { route: at(cols.route), phone: at(cols.phone), truck: '', secondTruck: null, members: [] };
      routes.push(current);
    }
    const truck = at(cols.truck);
    if (truck) {
      if (!current.truck) current.truck = truck;
      else if (normalize(truck) !== normalize(current.truck)) current.secondTruck = truck;
    }
    if (name) {
      // END TIME is its own column when the header was copied; otherwise it's the row's last time.
      const end = cols.end >= 0 ? parseTime(at(cols.end))
        : [...cells.slice(cols.start + 1)].reverse().map(parseTime).find((x) => x) ?? null;
      current.members.push({ position, name, start: parseTime(at(cols.start)), end });
    }
  }
  return routes.filter((r) => r.members.length > 0);
}

/** Montréal wall-clock time on a business date → ISO timestamp. */
export function montrealIso(date: string, hhmm: string): string {
  const guess = new Date(`${date}T${hhmm}:00Z`);
  const offset = new Intl.DateTimeFormat('en-US', { timeZone: 'America/Toronto', timeZoneName: 'longOffset' })
    .formatToParts(guess).find((p) => p.type === 'timeZoneName')?.value ?? 'GMT';
  const m = offset.match(/GMT([+-])(\d{2}):(\d{2})/);
  const minutes = m ? (m[1] === '-' ? -1 : 1) * (Number(m[2]) * 60 + Number(m[3])) : 0;
  return new Date(guess.getTime() - minutes * 60_000).toISOString();
}
