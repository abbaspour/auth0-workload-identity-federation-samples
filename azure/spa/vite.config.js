import { defineConfig } from 'vite';

// Stand-in for worker/index.js in dev and preview: /entra/<tenant>/token goes to the Entra token endpoint with the
// browser's Origin header removed (Entra refuses a client_credentials request that carries one, AADSTS9002326).
const entraProxy = {
  '/entra': {
    target: 'https://login.microsoftonline.com',
    changeOrigin: true,
    rewrite: (path) => path.replace(/^\/entra\/([^/]+)\/token$/, '/$1/oauth2/v2.0/token'),
    configure: (proxy) => proxy.on('proxyReq', (proxyReq) => proxyReq.removeHeader('origin')),
  },
};

// Port 5173 must match the Auth0 callback/logout/web-origin URLs and the storage CORS origin
// configured by Terraform (azure_spa_origins in auth0/).
export default defineConfig({
  server: { port: 5173, strictPort: true, proxy: entraProxy },
  preview: { port: 5173, strictPort: true, proxy: entraProxy },
  test: { environment: 'node' },
});
