# Azure DevOps Codex Plugin

This repository packages an internal Codex plugin for Azure DevOps. It contains:

- `plugins/azure-devops/`: the plugin implementation
- `.agents/plugins/marketplace.json`: repo-local marketplace metadata

The plugin uses Microsoft's local `@azure-devops/mcp` server and PAT authentication.

## Install

Clone this repository somewhere local, for example:

```bash
git clone <internal-repo-url> ~/dev/azure-devops-codex-plugin
cd ~/dev/azure-devops-codex-plugin
```

Run the local setup script:

```bash
./scripts/configure-plugin.sh
```

The script writes `plugins/azure-devops/.env.local` with `0600` permissions. That file is ignored by Git and is loaded automatically by the plugin launcher.

For scripted setup, provide values through environment variables:

```bash
AZURE_DEVOPS_ORG=gps-aie-devops \
AZURE_DEVOPS_PROJECT=AIE \
AZURE_DEVOPS_PAT="<your-pat>" \
./scripts/configure-plugin.sh --non-interactive
```

Validate the local setup any time with:

```bash
./scripts/validate-plugin.sh
```

Restart Codex after setup so the MCP server is reloaded.

## Share With Teammates

The safest distribution path is a private internal Git repository containing this whole repo. Teammates clone it, run `./scripts/configure-plugin.sh`, and install or enable the repo-local marketplace/plugin in Codex.

Do not share PATs in Git, Slack, docs, screenshots, or shell transcripts. If a PAT is exposed, revoke it and issue a new one.

## Files To Customize Before Publishing

- `plugins/azure-devops/.codex-plugin/plugin.json`: replace author, repository, privacy, and terms placeholders.
- `.agents/plugins/marketplace.json`: replace marketplace name/display name placeholders if your Codex marketplace UI uses them.
- `plugins/azure-devops/README.md`: add team-specific PAT scope guidance if your org has a standard policy.
