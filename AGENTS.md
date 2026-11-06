# AGENTS.md

## Cursor Cloud specific instructions

This repository contains two independent products:

- **`WeekFit` (native iOS app)** — Swift + `WeekFit.xcodeproj`, with `WeekFitTests`/`WeekFitUITests`. This requires macOS + Xcode and **cannot be built, run, or tested on the Linux Cloud Agent VM.** Do not attempt to build the Xcode project here.
- **`web/`** — the WeekFit marketing site, a **Next.js 16** app (static export). This is the only product that runs on the Cloud Agent Linux VM.

### Working on `web/`

All web commands run from the `web/` directory (Node 22 is available on the VM):

- Dev server: `npm run dev` — serves on `http://localhost:3000` (Turbopack).
- Lint: `npm run lint` (eslint). Typecheck: `npm run typecheck` (`tsc --noEmit`).
- Build: `npm run build` — produces a static export in `web/out/` and runs several custom post-build scripts (`scripts/*.mjs`: prune-public, fix-og, write-cache-headers, optimize-critical-path, report-deploy-size, verify-release). `next.config.ts` sets `output: "export"`, so there is no Node runtime server in production — `npm run start` serves the exported files.

Non-obvious notes:

- This is **not** the Next.js you may know from training data; it has breaking API/convention changes. See `web/AGENTS.md` and the bundled docs in `web/node_modules/next/dist/docs/` before writing web code.
- Dependencies are installed with `npm ci` inside `web/` (matches `web/package-lock.json`). The startup update script already does this.
