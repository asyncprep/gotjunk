import { describe, expect, it } from 'vitest';
import { parseQuickAccounts } from './quickSignIn';

describe('parseQuickAccounts', () => {
  it('reads label, email and optional password', () => {
    expect(parseQuickAccounts('Direction|a@x.ca|pw1; Crew | b@x.ca ')).toEqual([
      { label: 'Direction', email: 'a@x.ca', password: 'pw1' },
      { label: 'Crew', email: 'b@x.ca', password: undefined },
    ]);
  });

  it('ignores empty and malformed entries', () => {
    expect(parseQuickAccounts(undefined)).toEqual([]);
    expect(parseQuickAccounts('')).toEqual([]);
    expect(parseQuickAccounts(';Nope|not-an-email;|c@x.ca')).toEqual([]);
  });
});
