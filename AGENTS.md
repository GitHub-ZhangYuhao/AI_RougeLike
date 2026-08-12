# Repository Guidelines

## Project Structure & Module Organization

This repository is a dependency-free browser game built with JavaScript ES modules and Canvas. `index.html` is the entry page; `js/main.js` starts the fixed-step game loop. Core gameplay modules live directly under `js/`, while enemy implementations are in `js/enemies/`, weapon implementations in `js/weapons/`, and shared gameplay systems in `js/systems/`. Keep balance values centralized in `js/config.js`. Development utilities are in `tools/`, design notes in `DESIGN.md` and `Docs/`, and generated media experiments belong under ignored `Experimental/`. The `video-to-alpha-flipbook/` directory is a separate media-processing skill/toolset.

## Build, Test, and Development Commands

- `npm start` — run the local static server at `http://localhost:5173`.
- `npm run smoke` — execute the headless gameplay smoke test without launching a browser.
- `node tools/serve.js` and `node tools/headless-smoke.mjs` — direct equivalents of the npm scripts.

There is no compile or bundle step. Use a current Node.js release that supports ES modules.

## Coding Style & Naming Conventions

Use 2-space indentation, semicolons, single-quoted strings, and explicit `.js` extensions in imports. Follow existing ES module patterns: PascalCase for classes (`WaveDirector`), camelCase for functions and variables (`createEnemyByType`), and kebab-case for filenames (`rare-items.js`). Keep rendering, state updates, and configuration responsibilities separated. Add comments only for non-obvious mechanics or constraints. No formatter or linter is configured, so match nearby code closely.

## Testing Guidelines

Run `npm run smoke` before every commit. Extend `tools/headless-smoke.mjs` when changing combat, cards, waves, input, or state transitions. Tests should be deterministic and fail by throwing a descriptive error. For visual or UI changes, also run `npm start` and verify keyboard, mouse, HUD, pause, death, and restart behavior in a browser. No formal coverage threshold is configured.

## Commit & Pull Request Guidelines

Recent history uses Conventional Commit-style subjects, primarily `feat: <summary>`. Use an imperative, scoped summary such as `fix: prevent duplicate boss rewards`; keep unrelated changes in separate commits. Pull requests should explain gameplay impact, list validation performed, link relevant issues or design notes, and include screenshots or short recordings for visible changes. Call out balance-value changes and any intentional limitations.
