---
description: Sync documentation, commit all changes, and push
---

# Sync documentation, commit all changes, and push

Analyze all staged and unstaged changes in the repository, update the project documentation accordingly, then commit everything (source code + documentation) and push to the remote.

## Steps

### 1. Gather the diff

Run the following and read the full output carefully:

```bash
git diff HEAD
git status --short
```

If there is nothing to commit (`git status` returns clean), stop and inform the user — there is nothing to document.

### 2. Understand what changed

From the diff, extract:

- **Files added / deleted / renamed** — structural changes that may affect the folder-structure section of `docs/` or `README.md`
- **New components or Web Components** (`src/client/components/wm-*`) — each deserves a dedicated `docs/components/wm-*.md` file following the pattern of existing docs (attributes API, CSS custom properties, slots, file locations table)
- **CSS changes in components** (`src/client/components/wm-*/*.css`) — if CSS custom properties are added or changed, update the CSS custom properties table in `docs/components/wm-*.md`
- **CSS changes in global styles** (`src/client/styles/global/`) — if breakpoints, typography tokens, or base variables change, update `docs/setup.md` or the relevant section of `README.md`
- **New routes or API endpoints** (`src/server/routes/`) — update or create `docs/api.md`
- **Database migrations** (`src/server/db/migrations/`) — update `docs/db/README.md` with the new table / column / index
- **New views or Eta partials** (`src/server/views/`) — update `docs/views.md` if it exists, or add a note in `README.md`
- **Configuration changes** (`env.example.json`, `tsconfig*.json`, `vite.config.*`, `package.json`, `postcss.config.*`) — update `docs/setup.md` or the relevant section of `README.md`
- **New static assets** (`static/images/`) — update the asset table in `README.md`
- **Any other change** that a new developer would need to understand

### 3. Update or create documentation files in `docs/`

Before editing any existing file in `docs/`, read it in full so you don't duplicate content or break its structure and voice.

For each area that changed, update the relevant Markdown file inside `docs/`. Follow these rules:

- **Write in English**, present tense, concise prose — match the voice of the existing docs (no bullet soup, prefer short paragraphs and tables)
- **Never delete existing accurate content** — only add or correct
- **One file per concern**: `docs/db/README.md` for database, `docs/components/wm-*.md` for components, `docs/setup.md` for setup, `docs/api.md` for routes, etc.
- If a `docs/` file does not exist yet and the change warrants one, create it
- Keep the folder structure consistent with what already exists under `docs/`

### 4. Update `README.md`

Update the root `README.md` if any of the following changed:

- Folder structure
- Available scripts / commands
- Static asset table
- Prerequisites or environment variables
- High-level feature list

Do **not** rewrite sections that were not affected.

### 5. Update `CHANGELOG.md`

Prepend a new entry at the top of `CHANGELOG.md` using this format:

```markdown
## YYYY-MM-DD

### Added
- …

### Changed
- …

### Fixed
- …

### Removed
- …
```

Use today's date. Only include sections that have entries. Be specific: name the files, components, or routes that changed. Do not include entries for documentation-only changes triggered by this command itself.

### 6. Stage, commit and push

Derive the conventional commit type from the nature of the changes:

- `feat:` — new functionality, new components, new routes
- `fix:` — bug corrections
- `refactor:` — restructuring without behavior change
- `chore:` — config, deps, build tooling only
- `docs:` — ONLY when exclusively documentation files changed (no source code)

If changes span multiple types, use the most significant one. Draft a message that names the main artifacts that changed. Examples: `feat: wm-step-nav component and breakpoints system` or `fix: hbar layout and step1 styles`. Then:

```bash
git add --all
git commit -m "<your derived message here>"
git push
```

If `git push` fails because the remote has diverged, tell the user and stop — do not force-push.

## Rules

- Do not modify source code during this command — only documentation files (`docs/`, `README.md`, `CHANGELOG.md`) may be written or edited as part of this workflow; all other changes come from the working tree as-is
- Stage everything with `git add --all` so no file is left behind
- Never force-push (`--force`)
- Never amend a commit that has already been pushed
- If the diff is too large to analyze in a single pass, process it file by file and consolidate at the end before committing
