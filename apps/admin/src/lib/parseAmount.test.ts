import { describe, expect, it } from 'vitest';
import { parseAmount } from './supabase';

describe('parseAmount', () => {
  it('accepts French and English decimals', () => {
    expect(parseAmount('227,30')).toBe(227.3);
    expect(parseAmount('227.30')).toBe(227.3);
    expect(parseAmount('1 200,50 $')).toBe(1200.5);
    expect(parseAmount('15')).toBe(15);
  });
  it('blank is null, junk is NaN', () => {
    expect(parseAmount('  ')).toBeNull();
    expect(parseAmount('abc')).toBeNaN();
    expect(parseAmount('-5')).toBeNaN();
    expect(parseAmount('1,2,3')).toBeNaN();
  });
});
