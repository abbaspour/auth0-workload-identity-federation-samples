import { describe, expect, it, vi } from 'vitest';
import { createCredentialsProvider } from './credentials.js';

const MIN = 60 * 1000;

function setup({ lifetimeMs = 60 * MIN } = {}) {
  let clock = 1_000_000;
  let issued = 0;
  const getToken = vi.fn(async () => `token-${issued + 1}`);
  const assumeRole = vi.fn(async (token) => {
    issued += 1;
    return {
      credentials: { accessKeyId: `AK${issued}`, secretAccessKey: 's', sessionToken: 't', expiration: new Date(clock + lifetimeMs) },
      subject: 'auth0|a',
      assumedRoleArn: `arn:session/${token}`,
    };
  });
  const provider = createCredentialsProvider({ getToken, assumeRole, now: () => clock });
  return { provider, getToken, assumeRole, advance: (ms) => (clock += ms) };
}

describe('createCredentialsProvider', () => {
  it('exchanges the token once and reuses cached credentials', async () => {
    const { provider, assumeRole } = setup();
    const a = await provider.get();
    const b = await provider.get();
    expect(a).toBe(b);
    expect(assumeRole).toHaveBeenCalledTimes(1);
    expect(assumeRole).toHaveBeenCalledWith('token-1');
  });

  it('shares one in-flight exchange between concurrent callers', async () => {
    const { provider, assumeRole } = setup();
    await Promise.all([provider.get(), provider.get(), provider.credentials()]);
    expect(assumeRole).toHaveBeenCalledTimes(1);
  });

  it('gets a fresh token and new credentials inside the expiry skew window', async () => {
    const { provider, assumeRole, getToken, advance } = setup();
    await provider.get();
    advance(54 * MIN); // 6 min left: still fresh
    await provider.get();
    expect(assumeRole).toHaveBeenCalledTimes(1);
    advance(2 * MIN); // 4 min left: inside the 5 min skew
    const renewed = await provider.get();
    expect(assumeRole).toHaveBeenCalledTimes(2);
    expect(getToken).toHaveBeenCalledTimes(2);
    expect(renewed.credentials.accessKeyId).toBe('AK2');
  });

  it('returns SDK-shaped credentials', async () => {
    const { provider } = setup();
    expect(await provider.credentials()).toMatchObject({ accessKeyId: 'AK1', secretAccessKey: 's', sessionToken: 't' });
  });

  it('does not cache a failure: the next call retries', async () => {
    const { provider, assumeRole } = setup();
    assumeRole.mockRejectedValueOnce(new Error('AccessDenied'));
    await expect(provider.get()).rejects.toThrow('AccessDenied');
    await expect(provider.get()).resolves.toMatchObject({ subject: 'auth0|a' });
    expect(assumeRole).toHaveBeenCalledTimes(2);
  });

  it('clear() forces a new exchange', async () => {
    const { provider, assumeRole } = setup();
    await provider.get();
    provider.clear();
    await provider.get();
    expect(assumeRole).toHaveBeenCalledTimes(2);
  });
});
