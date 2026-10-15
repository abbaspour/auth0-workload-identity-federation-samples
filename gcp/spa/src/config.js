const VARS = {
  domain: 'VITE_AUTH0_DOMAIN',
  clientId: 'VITE_AUTH0_CLIENT_ID',
  audience: 'VITE_AUTH0_AUDIENCE',
  providerAudience: 'VITE_GCP_WIP_AUDIENCE',
  bucket: 'VITE_GCS_BUCKET',
};

export function loadConfig(env = import.meta.env) {
  const config = {};
  const missing = [];
  for (const [key, name] of Object.entries(VARS)) {
    const value = env[name];
    if (value) config[key] = value;
    else missing.push(name);
  }
  if (missing.length) {
    throw new Error(`Missing configuration: ${missing.join(', ')}. Run gcp/scripts/spa-env.sh to generate .env.local.`);
  }
  return config;
}
