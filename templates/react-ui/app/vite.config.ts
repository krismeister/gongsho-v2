import react from '@vitejs/plugin-react';
import { defineConfig } from 'vite';

// NOTE: no `base` here on purpose. Every build passes --base explicitly:
// the stable deployment path (/acme/shop/ui-1/) or a dev session path
// (/dev/<session>/acme/shop/ui-1/). Asset dir stays the Vite default
// `assets/` so the proxy's long-cache matcher (/assets/*) applies.
export default defineConfig({
  plugins: [react()],
});
