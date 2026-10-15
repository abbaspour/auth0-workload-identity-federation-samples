const DEFAULT_SKEW_MS = 5 * 60 * 1000;

// Caches the federated Google access token and obtains a new one (a fresh Auth0 access token, then
// Google STS) shortly before it expires. Concurrent callers share one in-flight exchange.
//
//   getToken():      () => Promise<string>   current Auth0 access token
//   exchange(token): () => Promise<{ credentials: { accessToken, expiration: Date }, subject }>
export function createCredentialsProvider({ getToken, exchange, now = Date.now, skewMs = DEFAULT_SKEW_MS }) {
  let cached;
  let inflight;

  const isFresh = (session) => session && session.credentials.expiration.getTime() - skewMs > now();

  async function renew() {
    const token = await getToken();
    cached = await exchange(token);
    return cached;
  }

  async function get() {
    if (isFresh(cached)) return cached;
    inflight ??= renew().finally(() => {
      inflight = undefined;
    });
    return inflight;
  }

  return {
    get,
    // The current access token, renewed when needed
    accessToken: async () => (await get()).credentials.accessToken,
    clear() {
      cached = undefined;
    },
  };
}
