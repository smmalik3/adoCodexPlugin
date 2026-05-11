#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
plugin_root="$repo_root/plugins/azure-devops"

fail() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

require_file() {
  [[ -f "$1" ]] || fail "missing file: $1"
}

require_file "$plugin_root/.codex-plugin/plugin.json"
require_file "$plugin_root/.mcp.json"
require_file "$plugin_root/scripts/run-azure-devops-mcp.sh"
require_file "$repo_root/.agents/plugins/marketplace.json"

local_env_file="${AZURE_DEVOPS_LOCAL_ENV_FILE:-$plugin_root/.env.local}"
if [[ -f "$local_env_file" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$local_env_file"
  set +a
fi

python3 -m json.tool "$plugin_root/.codex-plugin/plugin.json" >/dev/null
python3 -m json.tool "$plugin_root/.mcp.json" >/dev/null
python3 -m json.tool "$repo_root/.agents/plugins/marketplace.json" >/dev/null
bash -n "$plugin_root/scripts/run-azure-devops-mcp.sh"

if ! command -v node >/dev/null 2>&1; then
  fail "Node.js 20+ is required, but node was not found"
fi

node_major="$(node -p 'Number(process.versions.node.split(".")[0])')"
if [[ "$node_major" -lt 20 ]]; then
  fail "Node.js 20+ is required, found $(node --version)"
fi

if [[ -z "${AZURE_DEVOPS_ORG:-}" ]]; then
  fail "AZURE_DEVOPS_ORG is not set"
fi

if [[ "${AZURE_DEVOPS_AUTHENTICATION:-pat}" == "pat" && -z "${AZURE_DEVOPS_PAT:-}" && -z "${PERSONAL_ACCESS_TOKEN:-}" ]]; then
  fail "PAT auth requires AZURE_DEVOPS_PAT or PERSONAL_ACCESS_TOKEN"
fi

(
  cd "$plugin_root"
  AZURE_DEVOPS_MCP_DRY_RUN=1 ./scripts/run-azure-devops-mcp.sh >/dev/null
)

printf 'Azure DevOps Codex plugin validation passed.\n'
