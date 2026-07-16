# Install Foam VS Code extension

## Goal

Foam (`foam.foam-vscode`) available in VS Code sessions on this box, for the controcanto kb.

## Decisions

- Install into the Remote-SSH server (`~/.vscode-server/extensions`) via the newest installed server's
  own CLI (`~/.vscode-server/cli/servers/Stable-*/server/bin/code-server --install-extension`),
  because Remote-SSH sessions use the server-side extension host, not the snap VS Code.
- Also install via `/snap/bin/code --install-extension` so any local/desktop VS Code on the box has it too.
- Repo-level integration in controcanto: `.vscode/extensions.json` recommendation
  (so any fresh VS Code connection prompts the install by itself) - the durable path, no manual steps.
- No settings changes beyond the extension; Foam works on plain markdown.

## Steps

1. This note.
2. `SERVER=$(ls -td ~/.vscode-server/cli/servers/Stable-*/server | head -1); $SERVER/bin/code-server --install-extension foam.foam-vscode`
3. `/snap/bin/code --install-extension foam.foam-vscode` (best effort; snap may lack a display, CLI install still works)
4. In controcanto: `.vscode/extensions.json` with the recommendation; `.foam/templates` symlink to `kb/templates`.

## Rollback

- `$SERVER/bin/code-server --uninstall-extension foam.foam-vscode` and/or `rm -rf ~/.vscode-server/extensions/foam.foam-vscode-*`
- `/snap/bin/code --uninstall-extension foam.foam-vscode`
- Delete `.vscode/extensions.json` entry and `.foam` from the repo.
