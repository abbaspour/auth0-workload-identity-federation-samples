import { defineConfig } from 'vite';

// Port 5173 must match the Auth0 callback/logout/web-origin URLs and the S3 CORS origin
// configured by Terraform (var.spa_origins).
export default defineConfig({
  server: { port: 5173, strictPort: true },
  preview: { port: 5173, strictPort: true },
  test: { environment: 'node' },
});
