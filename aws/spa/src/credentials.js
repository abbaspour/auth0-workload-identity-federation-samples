const DEFAULT_SKEW_MS = 5 * 60 * 1000;

// Caches temporary AWS credentials and obtains new ones (a fresh Auth0 access token, then STS)
// shortly before they expire. Concurrent callers share one in-flight exchange.
//
//   getToken():        () => Promise<string>   current Auth0 access token
//   assumeRole(token): () => Promise<{ credentials: { accessKeyId, secretAccessKey, sessionToken,
//                                      expiration: Date }, subject, assumedRoleArn }>
export function createCredentialsProvider({ getToken, assumeRole, now = Date.now, skewMs = DEFAULT_SKEW_MS }) {
  let cached;
  let inflight;

  const isFresh = (session) => session && session.credentials.expiration.getTime() - skewMs > now();

  async function exchange() {
    const token = await getToken();
    cached = await assumeRole(token);
    return cached;
  }

  async function get() {
    if (isFresh(cached)) return cached;
    inflight ??= exchange().finally(() => {
      inflight = undefined;
    });
    return inflight;
  }

  return {
    get,
    // Shape expected by the AWS SDK's `credentials` option
    credentials: async () => (await get()).credentials,
    clear() {
      cached = undefined;
    },
  };
}
