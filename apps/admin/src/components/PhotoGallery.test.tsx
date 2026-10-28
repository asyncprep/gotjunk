import { afterEach, beforeAll, describe, expect, it, vi } from 'vitest';
import { cleanup, render, screen, waitFor } from '@testing-library/react';
import i18n from '../i18n';
import { supabase } from '../lib/supabase';
import PhotoGallery from './PhotoGallery';

const photos = [
  { photo_id: 'a', storage_path: 's/a.jpg', captured_at: '2026-10-28T14:00:00Z', photo_kind: 'disposal_ticket' },
  { photo_id: 'b', storage_path: 's/b.jpg', captured_at: '2026-10-28T14:05:00Z', photo_kind: 'disposal_ticket' },
];

beforeAll(async () => {
  await i18n.changeLanguage('en');
  // a.jpg reached storage; b.jpg is still on the truck's phone.
  vi.spyOn(supabase.storage, 'from').mockReturnValue({
    createSignedUrls: async (paths: string[]) => ({
      data: paths.map((path) => path === 's/a.jpg'
        ? { path, signedUrl: 'https://files.test/a.jpg', error: null }
        : { path, signedUrl: '', error: 'Object not found' }),
      error: null,
    }),
  } as never);
});
afterEach(cleanup);

describe('PhotoGallery', () => {
  it('shows uploaded photos as thumbnails and pending ones as not received yet', async () => {
    render(<PhotoGallery photos={photos} label="Ticket photo" />);
    await waitFor(() => expect(screen.getByAltText('Ticket photo 1')).toBeTruthy());
    expect((screen.getByAltText('Ticket photo 1') as HTMLImageElement).src).toBe('https://files.test/a.jpg');
    expect(screen.getByText('Not received from the truck yet')).toBeTruthy();
    expect(screen.queryByAltText('Ticket photo 2')).toBeNull();
  });

  it('renders nothing without photos', () => {
    const { container } = render(<PhotoGallery photos={[]} label="Ticket photo" />);
    expect(container.textContent).toBe('');
  });
});
