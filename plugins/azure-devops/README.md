# Azure DevOps Codex Plugin

This plugin wires Codex to Microsoft's local Azure DevOps MCP server.

## Setup

Install Node.js 20 or newer, then run the repository setup script:

```bash
./scripts/configure-plugin.sh
```

The script writes a local ignored `plugins/azure-devops/.env.local` file that this launcher reads automatically.

You can also expose your Azure DevOps organization slug and PAT manually:

```bash
export AZURE_DEVOPS_ORG=contoso
export AZURE_DEVOPS_AUTHENTICATION=pat
export AZURE_DEVOPS_PAT="your-raw-pat"
```

Use only the organization slug from your Azure DevOps URL. For example:

```text
https://dev.azure.com/gps-aie-devops/AIE/
                      ^ organization: gps-aie-devops
                                     ^ project: AIE
```

So the preferred config is:

```bash
export AZURE_DEVOPS_ORG=gps-aie-devops
export AZURE_DEVOPS_PROJECT=AIE
```

The launcher also accepts the full `https://dev.azure.com/<org>/<project>/` URL and will extract those values, but the slug form is less surprising.

Optional settings:

```bash
export AZURE_DEVOPS_MCP_DOMAINS=core,work-items,repositories,pipelines
export AZURE_DEVOPS_PROJECT="Project name"
export AZURE_DEVOPS_TEAM="Team name"
export AZURE_DEVOPS_PAT_EMAIL=pat
```

`AZURE_DEVOPS_MCP_DOMAINS` is a comma-separated list. Useful values include `core`, `work`, `work-items`, `search`, `test-plans`, `repositories`, `wiki`, `pipelines`, and `advanced-security`.

The Microsoft Azure DevOps MCP server expects PAT auth as `--authentication pat` plus a `PERSONAL_ACCESS_TOKEN` value containing base64-encoded `email:pat`. This plugin launcher accepts `AZURE_DEVOPS_PAT` as a safer raw input and encodes it for the MCP server at startup. If you already have the encoded value, set `PERSONAL_ACCESS_TOKEN` directly instead.

Do not commit PAT values in `.mcp.json`, `.env`, shell history, or docs.

## Prompts To Try

- List my Azure DevOps projects.
- Show my assigned work items.
- Summarize open pull requests in this repo.
- Check the latest pipeline run and explain any failures.

## Notes

The hosted Azure DevOps remote MCP server is public preview. This plugin defaults to the local `@azure-devops/mcp` server because the remote path currently has stricter client authentication support.
