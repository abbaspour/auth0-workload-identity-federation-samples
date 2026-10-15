import { defineConfig } from 'vite';

// Port 5173 must match the Auth0 callback/logout/web-origin URLs and the bucket CORS origin
// configured by Terraform (gcp_spa_origins in auth0/).
export default defineConfig({
  server: { port: 5173, strictPort: true },
  preview: { port: 5173, strictPort: true },
  test: { environment: 'node' },
});
