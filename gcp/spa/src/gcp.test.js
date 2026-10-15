import { describe, expect, it, vi } from 'vitest';
import { createGcsStore, createTokenExchange } from './gcp.js';

const b64url = (obj) => Buffer.from(JSON.stringify(obj)).toString('base64url');
const jwt = (claims) => `${b64url({ alg: 'RS256' })}.${b64url(claims)}.sig`;

const json = (body, init = {}) => new Response(JSON.stringify(body), { status: 200, ...init });

describe('createTokenExchange', () => {
  const providerAudience = '//iam.googleapis.com/projects/1/locations/global/workloadIdentityPools/p/providers/auth0';

  it('posts an RFC 8693 token exchange and maps the response', async () => {
    const fetchImpl = vi.fn(async () => json({ access_token: 'ya29.x', token_type: 'Bearer', expires_in: 3599 }));
    const exchange = createTokenExchange({ providerAudience }, { fetchImpl, now: () => 1_000_000 });

    const session = await exchange(jwt({ sub: 'auth0|abc' }));

    const [url, init] = fetchImpl.mock.calls[0];
    expect(url).toBe('https://sts.googleapis.com/v1/token');
    const form = Object.fromEntries(init.body);
    expect(form).toMatchObject({
      grant_type: 'urn:ietf:params:oauth:grant-type:token-exchange',
      audience: providerAudience,
      subject_token_type: 'urn:ietf:params:oauth:token-type:jwt',
      requested_token_type: 'urn:ietf:params:oauth:token-type:access_token',
    });
    expect(form.subject_token.split('.')).toHaveLength(3);
    expect(session.subject).toBe('auth0|abc');
    expect(session.credentials.accessToken).toBe('ya29.x');
    expect(session.credentials.expiration.getTime()).toBe(1_000_000 + 3599 * 1000);
  });

  it('turns an STS error into a readable message', async () => {
    const fetchImpl = async () => json({ error: 'invalid_grant', error_description: 'The audience is wrong' }, { status: 400 });
    const exchange = createTokenExchange({ providerAudience }, { fetchImpl });
    await expect(exchange(jwt({ sub: 'x' }))).rejects.toThrow(/HTTP 400.*The audience is wrong/);
  });
});

describe('createGcsStore', () => {
  const accessToken = async () => 'ya29.t';

  it('lists objects under the user prefix, following pages and skipping the prefix placeholder', async () => {
    const pages = [
      { items: [{ name: 'users/auth0|a/', size: '0', updated: '2026-01-01T00:00:00Z' }, { name: 'users/auth0|a/one.txt', size: '3', updated: '2026-01-01T00:00:00Z' }], nextPageToken: 'p2' },
      { items: [{ name: 'users/auth0|a/two.txt', size: '5', updated: '2026-01-02T00:00:00Z' }] },
    ];
    const fetchImpl = vi.fn(async () => json(pages.shift()));
    const store = createGcsStore({ bucket: 'b', accessToken }, { fetchImpl });

    const objects = await store.list('auth0|a');

    expect(objects.map((o) => [o.name, o.size])).toEqual([['one.txt', 3], ['two.txt', 5]]);
    const first = new URL(fetchImpl.mock.calls[0][0]);
    expect(first.pathname).toBe('/storage/v1/b/b/o');
    expect(first.searchParams.get('prefix')).toBe('users/auth0|a/');
    expect(new URL(fetchImpl.mock.calls[1][0]).searchParams.get('pageToken')).toBe('p2');
    expect(fetchImpl.mock.calls[0][1].headers.authorization).toBe('Bearer ya29.t');
  });

  it('uploads with an encoded object name under the user prefix', async () => {
    const fetchImpl = vi.fn(async () => json({}));
    const store = createGcsStore({ bucket: 'b', accessToken }, { fetchImpl });

    const key = await store.upload('auth0|a', { name: 'my file.txt', type: 'text/plain' });

    expect(key).toBe('users/auth0|a/my file.txt');
    const [url, init] = fetchImpl.mock.calls[0];
    const parsed = new URL(url);
    expect(parsed.pathname).toBe('/upload/storage/v1/b/b/o');
    expect(parsed.searchParams.get('uploadType')).toBe('media');
    expect(parsed.searchParams.get('name')).toBe(key);
    expect(init.method).toBe('POST');
    expect(init.headers['content-type']).toBe('text/plain');
  });

  it('downloads by encoded key with alt=media', async () => {
    const fetchImpl = vi.fn(async () => new Response('hello', { headers: { 'content-type': 'text/plain' } }));
    const store = createGcsStore({ bucket: 'b', accessToken }, { fetchImpl });

    const { bytes, contentType } = await store.download('users/auth0|a/x y.txt');

    expect(fetchImpl.mock.calls[0][0]).toBe('https://storage.googleapis.com/storage/v1/b/b/o/users%2Fauth0%7Ca%2Fx%20y.txt?alt=media');
    expect(new TextDecoder().decode(bytes)).toBe('hello');
    expect(contentType).toBe('text/plain');
  });

  it('reports Cloud Storage errors with the HTTP status', async () => {
    const fetchImpl = async () => json({ error: { code: 403, message: 'Caller does not have storage.objects.list access' } }, { status: 403 });
    const store = createGcsStore({ bucket: 'b', accessToken }, { fetchImpl });
    await expect(store.list('auth0|a')).rejects.toThrow(/HTTP 403.*storage\.objects\.list/);
  });
});
