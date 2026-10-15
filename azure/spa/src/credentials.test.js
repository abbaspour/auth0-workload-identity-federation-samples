import { describe, expect, it, vi } from 'vitest';
import { createCredentialsProvider } from './credentials.js';

const MIN = 60 * 1000;

function setup({ lifetimeMs = 60 * MIN } = {}) {
  let clock = 1_000_000;
  let issued = 0;
  const getToken = vi.fn(async () => `token-${issued + 1}`);
  const exchange = vi.fn(async (token) => {
    issued += 1;
    return {
      credentials: { accessToken: `entra.${issued}`, expiration: new Date(clock + lifetimeMs) },
      subject: 'auth0|a',
      token,
    };
  });
  const provider = createCredentialsProvider({ getToken, exchange, now: () => clock });
  return { provider, getToken, exchange, advance: (ms) => (clock += ms) };
}

describe('createCredentialsProvider', () => {
  it('exchanges the token once and reuses cached credentials', async () => {
    const { provider, exchange } = setup();
    const a = await provider.get();
    const b = await provider.get();
    expect(a).toBe(b);
    expect(exchange).toHaveBeenCalledTimes(1);
    expect(exchange).toHaveBeenCalledWith('token-1');
  });

  it('shares one in-flight exchange between concurrent callers', async () => {
    const { provider, exchange } = setup();
    await Promise.all([provider.get(), provider.get(), provider.accessToken()]);
    expect(exchange).toHaveBeenCalledTimes(1);
  });

  it('gets a fresh token and new credentials inside the expiry skew window', async () => {
    const { provider, exchange, getToken, advance } = setup();
    await provider.get();
    advance(54 * MIN); // 6 min left: still fresh
    await provider.get();
    expect(exchange).toHaveBeenCalledTimes(1);
    advance(2 * MIN); // 4 min left: inside the 5 min skew
    const renewed = await provider.get();
    expect(exchange).toHaveBeenCalledTimes(2);
    expect(getToken).toHaveBeenCalledTimes(2);
    expect(renewed.credentials.accessToken).toBe('entra.2');
  });

  it('returns the current access token', async () => {
    const { provider } = setup();
    expect(await provider.accessToken()).toBe('entra.1');
  });

  it('does not cache a failure: the next call retries', async () => {
    const { provider, exchange } = setup();
    exchange.mockRejectedValueOnce(new Error('invalid_grant'));
    await expect(provider.get()).rejects.toThrow('invalid_grant');
    await expect(provider.get()).resolves.toMatchObject({ subject: 'auth0|a' });
    expect(exchange).toHaveBeenCalledTimes(2);
  });

  it('clear() forces a new exchange', async () => {
    const { provider, exchange } = setup();
    await provider.get();
    provider.clear();
    await provider.get();
    expect(exchange).toHaveBeenCalledTimes(2);
  });
});
