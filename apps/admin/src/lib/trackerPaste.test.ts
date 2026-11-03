import { describe, expect, it } from 'vitest';
import { montrealIso, parseTime, parseTracker } from './trackerPaste';

// Rows as a spreadsheet copy gives them: tabs between cells, merged cells only in their top row.
// Each route block has 4 rows (Revenue, Job End Time, $/H, AJS); names are made up.
const row = (...cells: string[]) => cells.join('\t');
const jobs = (label: string, ...v: string[]) => [label, ...v, ...Array(12 - v.length).fill('')];

const block1 = [
  row('C1', '4029', 'Pink', 'Driver', 'Alex Tremblay', '7:30', ...jobs('Revenue', '$ 2,096.00'), '14:00'),
  row('', '', '', '', '', '', ...jobs('Job End Time', '13:15'), ''),
  row('', '', '', 'Navigator', 'Sam Côté', '7:30', ...jobs('$/H', '$ 182.26'), '14:00'),
  row('', '', '', '', '', '', ...jobs('AJS', '$ 2,096.00'), ''),
];
const block2 = [
  row('E1', '4028', 'Bleu', 'Driver', 'Jo Gagnon', '7:30', ...jobs('Revenue', '$ 916.00', '$ 448.00'), '17:45'),
  row('', '', '', '', '', '', ...jobs('Job End Time', '9:00', '9:45'), ''),
  row('', '', '', 'Navigator', 'Max Roy', '7:45', ...jobs('$/H', '$ 305.33'), '16:30'),
  row('', '', 'Titan', '', '', '', ...jobs('AJS', '$ 916.00'), ''),
];
const empty = [
  row('', '', '', 'Driver', '', '', ...jobs('Revenue'), ''),
  row('', '', '', '', '', '', ...jobs('Job End Time'), ''),
  row('', '', '', 'Navigator', '', '', ...jobs('$/H'), ''),
  row('', '', '', '', '', '', ...jobs('AJS'), ''),
];
const header = row('ROUTE', 'PHONE', 'TRUCK', 'POSITION', 'NAME', 'START TIME', 'JOB #',
  ...Array.from({ length: 12 }, (_, i) => String(i + 1)), 'END TIME', 'C');

describe('parseTracker', () => {
  it('reads routes, crew, positions, a second truck, and skips empty blocks (no header copied)', () => {
    const routes = parseTracker([...block1, ...block2, ...empty].join('\n'));
    expect(routes).toEqual([
      { route: 'C1', phone: '4029', truck: 'Pink', secondTruck: null, members: [
        { position: 'driver', name: 'Alex Tremblay', start: '07:30', end: '14:00' },
        { position: 'navigator', name: 'Sam Côté', start: '07:30', end: '14:00' },
      ] },
      { route: 'E1', phone: '4028', truck: 'Bleu', secondTruck: 'Titan', members: [
        { position: 'driver', name: 'Jo Gagnon', start: '07:30', end: '17:45' },
        { position: 'navigator', name: 'Max Roy', start: '07:45', end: '16:30' },
      ] },
    ]);
  });

  it('uses the header row when it is copied, and Windows line endings', () => {
    const routes = parseTracker([header, ...block1, ...block2].join('\r\n') + '\r\n');
    expect(routes.map((r) => [r.route, r.members.map((m) => m.end)])).toEqual([['C1', ['14:00', '14:00']], ['E1', ['17:45', '16:30']]]);
  });

  it('keeps a name without a position, and a morning paste without end times', () => {
    const morning = [
      row('W6', '4027', 'Frost', 'Driver', 'Lee Dubé', '10:00', ...jobs('Revenue'), ''),
      row('', '', '', '', '', '', ...jobs('Job End Time'), ''),
      row('', '', '', 'Navigator', 'Kim Pham', '10:00', ...jobs('$/H'), ''),
      row('', '', '', '', 'Pat Ouellet', '', ...jobs('AJS'), ''),
    ];
    expect(parseTracker(morning.join('\n'))[0].members).toEqual([
      { position: 'driver', name: 'Lee Dubé', start: '10:00', end: null },
      { position: 'navigator', name: 'Kim Pham', start: '10:00', end: null },
      { position: null, name: 'Pat Ouellet', start: null, end: null },
    ]);
  });

  it('reads French position names and Onboarding', () => {
    const fr = [row('C1', '4029', 'Pink', 'Chauffeur', 'Alex Tremblay', '7:30'), row('', '', '', 'Navigateur', 'Sam Côté', '7:30'),
      row('', '', '', 'Onboarding', 'Kim Pham', '7:30'), row('', '', '', 'Intégration', 'Lee Dubé', '7:30')];
    expect(parseTracker(fr.join('\n'))[0].members.map((m) => m.position)).toEqual(['driver', 'navigator', 'onboarding', 'onboarding']);
  });
});

describe('parseTime / montrealIso', () => {
  it('reads common time formats', () => {
    expect(['7:30', '07h30', '7:30 PM', '19:30:00', '12:15 am', 'x', '25:00'].map(parseTime))
      .toEqual(['07:30', '07:30', '19:30', '19:30', '00:15', null, null]);
  });
  it('converts Montréal local time, summer and winter', () => {
    expect(montrealIso('2026-10-25', '07:30')).toBe('2026-10-25T11:30:00.000Z');
    expect(montrealIso('2026-11-03', '07:30')).toBe('2026-11-03T12:30:00.000Z');
  });
});
