# Agent skills (portable)

This directory holds **tool-agnostic** agent skills: each subfolder is one skill with a `SKILL.md` file (YAML frontmatter + instructions). They are **not** tied to Cursor or any single product.

**Using them:** copy or symlink a skill folder into whatever environment you use, for example:

- **Cursor:** `~/.cursor/skills/<name>/` or `.cursor/skills/<name>/` in this repo
- **Codex:** `$CODEX_HOME/skills/<name>/` (see Codex skill installer docs)
- **Other agents:** follow that tool’s documented skills path and format

Keep edits in **this repo** as the source of truth when working on crawl-rc; sync to local agent dirs as needed.

| Skill | Purpose |
|-------|---------|
| [pickup-alert-rca](pickup-alert-rca/SKILL.md) | Root-cause analysis for BRC pickup-alert messages |
