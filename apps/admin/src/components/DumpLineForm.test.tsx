import { afterEach, beforeAll, describe, expect, it, vi } from 'vitest';
import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react';
import i18n from '../i18n';
import DumpLineForm, { parseWeight } from './DumpLineForm';

const materials = [{ material_type_id: 'm1', name: 'Mixed' }, { material_type_id: 'm2', name: 'Wood' }];

beforeAll(async () => { await i18n.changeLanguage('en'); });
afterEach(cleanup);

describe('parseWeight', () => {
  it('reads kg with a comma or a dot, more than 0', () => {
    expect(parseWeight('640')).toBe(640);
    expect(parseWeight('640,5')).toBe(640.5);
    expect(parseWeight(' 1 200 ')).toBe(1200);
    expect(parseWeight('0')).toBeNull();
    expect(parseWeight('12.34')).toBeNull();
    expect(parseWeight('abc')).toBeNull();
  });
});

describe('DumpLineForm', () => {
  it('adds a weigh-in line, then clears the form', async () => {
    const onAdd = vi.fn().mockResolvedValue(true);
    render(<DumpLineForm materials={materials} busy={false} onAdd={onAdd} />);
    fireEvent.change(screen.getByLabelText('Material'), { target: { value: 'm2' } });
    fireEvent.change(screen.getByLabelText('Weight (kg)'), { target: { value: '640,5' } });
    fireEvent.click(screen.getByText('Add'));
    await waitFor(() => expect(onAdd).toHaveBeenCalledWith('m2', 640.5));
    await waitFor(() => expect((screen.getByLabelText('Weight (kg)') as HTMLInputElement).value).toBe(''));
  });

  it('keeps what was typed when the server refuses it', async () => {
    const onAdd = vi.fn().mockResolvedValue(false);
    render(<DumpLineForm materials={materials} busy={false} onAdd={onAdd} />);
    fireEvent.change(screen.getByLabelText('Material'), { target: { value: 'm1' } });
    fireEvent.change(screen.getByLabelText('Weight (kg)'), { target: { value: '300' } });
    fireEvent.click(screen.getByText('Add'));
    await waitFor(() => expect(onAdd).toHaveBeenCalled());
    expect((screen.getByLabelText('Weight (kg)') as HTMLInputElement).value).toBe('300');
  });

  it('asks for the material and a valid weight', () => {
    const onAdd = vi.fn();
    render(<DumpLineForm materials={materials} busy={false} onAdd={onAdd} />);
    fireEvent.click(screen.getByText('Add'));
    expect(screen.getByText('Pick the material')).toBeTruthy();
    fireEvent.change(screen.getByLabelText('Material'), { target: { value: 'm1' } });
    fireEvent.change(screen.getByLabelText('Weight (kg)'), { target: { value: '0' } });
    fireEvent.click(screen.getByText('Add'));
    expect(screen.getByText(/Invalid weight/)).toBeTruthy();
    expect(onAdd).not.toHaveBeenCalled();
  });

  it('says when the site has no material with a rate', () => {
    render(<DumpLineForm materials={[]} busy={false} onAdd={vi.fn()} />);
    expect(screen.getByText(/No material with a rate/)).toBeTruthy();
  });
});
