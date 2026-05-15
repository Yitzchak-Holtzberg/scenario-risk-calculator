# web — SvelteKit dashboard

Single-screen country-risk dashboard. Country picker → probability card (with 90% CI) → per-indicator contribution table → reference class disclosure → model card link.

## Bootstrap

```sh
cd web
npm create svelte@latest .
npm install
npm install -D @types/chart.js chart.js
```

Pick the TypeScript + ESLint + Prettier options when prompted.

Set `VITE_API_BASE_URL` in `.env` to point at the local Go API (default `http://localhost:8080`).
