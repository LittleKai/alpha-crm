// Bundles the compiled backend (dist/server.js) into a single CommonJS file
// dist/server.cjs. Pure-JS dependencies (zca-js, proxy-agent, ...) are inlined;
// only the native addon better-sqlite3 is kept external and shipped as a real
// package alongside the bundle.
import { build } from 'esbuild';
import { fileURLToPath } from 'url';
import path from 'path';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const serviceRoot = path.resolve(__dirname, '..');

// Native addon — cannot be embedded in a JS bundle; resolved from node_modules at runtime.
const external = ['better-sqlite3'];

await build({
  entryPoints: [path.join(serviceRoot, 'dist', 'server.js')],
  outfile: path.join(serviceRoot, 'dist', 'server.cjs'),
  bundle: true,
  platform: 'node',
  format: 'cjs',
  target: 'node20',
  external,
  // config.js derives projectRoot from import.meta.url. In a CJS bundle import.meta
  // is empty, so shim it to the bundle's own path — keeps active-port.json landing in
  // <serviceDir>/.data exactly as the non-bundled dist/server.js did.
  banner: {
    js: "const import_meta_url = require('url').pathToFileURL(__filename).href;",
  },
  define: {
    'import.meta.url': 'import_meta_url',
  },
  logLevel: 'info',
  legalComments: 'none',
});

console.log('[bundle] Wrote dist/server.cjs (external: ' + external.join(', ') + ')');
