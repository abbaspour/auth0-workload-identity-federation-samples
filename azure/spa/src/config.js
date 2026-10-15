const VARS = {
  domain: 'VITE_AUTH0_DOMAIN',
  clientId: 'VITE_AUTH0_CLIENT_ID',
  audience: 'VITE_AUTH0_AUDIENCE',
  tenantId: 'VITE_AZURE_TENANT_ID',
  appClientId: 'VITE_AZURE_APP_CLIENT_ID',
  account: 'VITE_AZURE_STORAGE_ACCOUNT',
  container: 'VITE_AZURE_CONTAINER',
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
    throw new Error(`Missing configuration: ${missing.join(', ')}. Run azure/scripts/spa-env.sh to generate .env.local.`);
  }
  return config;
}
