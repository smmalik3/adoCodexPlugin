#!/usr/bin/env bash
set -euo pipefail
set +x
umask 077

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
plugin_root="$repo_root/plugins/azure-devops"
env_file="${AZURE_DEVOPS_LOCAL_ENV_FILE:-$plugin_root/.env.local}"

usage() {
  cat <<'EOF'
Set up the Azure DevOps Codex plugin on this machine.

Usage:
  ./scripts/setup-codex-plugin.sh
  ./scripts/setup-codex-plugin.sh --non-interactive

Environment variables used in non-interactive mode:
  AZURE_DEVOPS_ORG                 Required. Org slug or dev.azure.com URL.
  AZURE_DEVOPS_PAT                 Required unless PERSONAL_ACCESS_TOKEN is set.
  PERSONAL_ACCESS_TOKEN            Optional base64-encoded email:pat value.
  AZURE_DEVOPS_PROJECT             Optional.
  AZURE_DEVOPS_TEAM                Optional.
  AZURE_DEVOPS_MCP_DOMAINS         Optional.
  AZURE_DEVOPS_PAT_EMAIL           Optional. Defaults to pat.
  AZURE_DEVOPS_MCP_PACKAGE         Optional. Defaults to @azure-devops/mcp.
  AZURE_DEVOPS_LOCAL_ENV_FILE      Optional output path. Defaults to plugin .env.local.
EOF
}

fail() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

shell_quote() {
  printf '%q' "$1"
}

write_export() {
  local key="$1"
  local value="$2"
  printf 'export %s=%s\n' "$key" "$(shell_quote "$value")"
}

normalize_org_input() {
  local input="$1"
  local path_after_org

  NORMALIZED_ORG="$input"
  INFERRED_PROJECT=""

  if [[ "$input" =~ ^https?://dev\.azure\.com/([^/?#]+)/?([^?#]*) ]]; then
    NORMALIZED_ORG="${BASH_REMATCH[1]}"
    path_after_org="${BASH_REMATCH[2]}"
    path_after_org="${path_after_org#/}"
    if [[ -n "$path_after_org" ]]; then
      INFERRED_PROJECT="${path_after_org%%/*}"
    fi
  elif [[ "$input" =~ ^https?://([^./]+)\.visualstudio\.com/?([^?#]*) ]]; then
    NORMALIZED_ORG="${BASH_REMATCH[1]}"
    path_after_org="${BASH_REMATCH[2]}"
    path_after_org="${path_after_org#/}"
    if [[ -n "$path_after_org" ]]; then
      INFERRED_PROJECT="${path_after_org%%/*}"
    fi
  elif [[ "$input" == http://* || "$input" == https://* || "$input" == */* ]]; then
    fail "AZURE_DEVOPS_ORG must be an org slug or a dev.azure.com / visualstudio.com org URL"
  fi
}

prompt_with_default() {
  local prompt="$1"
  local default_value="$2"
  local answer

  if [[ -n "$default_value" ]]; then
    read -r -p "$prompt [$default_value]: " answer
    printf '%s' "${answer:-$default_value}"
  else
    read -r -p "$prompt: " answer
    printf '%s' "$answer"
  fi
}

prompt_secret() {
  local prompt="$1"
  local answer

  read -r -s -p "$prompt: " answer
  printf '\n' >&2
  printf '%s' "$answer"
}

validate_setup() {
  require_file "$plugin_root/.codex-plugin/plugin.json"
  require_file "$plugin_root/.mcp.json"
  require_file "$plugin_root/scripts/run-azure-devops-mcp.sh"
  require_file "$repo_root/.agents/plugins/marketplace.json"

  local local_env_file="${AZURE_DEVOPS_LOCAL_ENV_FILE:-$plugin_root/.env.local}"
  if [[ -f "$local_env_file" ]]; then
    load_local_env "$local_env_file"
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
}

require_file() {
  [[ -f "$1" ]] || fail "missing file: $1"
}

load_local_env() {
  local local_env_file="$1"
  local key value

  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    [[ "$line" == export\ * ]] || continue
    key="${line#export }"
    key="${key%%=*}"
    value="${line#*=}"
    case "$key" in
      AZURE_DEVOPS_ORG|AZURE_DEVOPS_AUTHENTICATION|AZURE_DEVOPS_MCP_DOMAINS|AZURE_DEVOPS_PAT_EMAIL|AZURE_DEVOPS_MCP_PACKAGE|AZURE_DEVOPS_PROJECT|AZURE_DEVOPS_TEAM|AZURE_DEVOPS_PAT|PERSONAL_ACCESS_TOKEN)
        ;;
      *)
        continue
        ;;
    esac
    # shellcheck disable=SC2163
    export "$key=$(python3 -c 'import ast,sys; raw=sys.argv[1]; print(ast.literal_eval(raw) if raw else "")' "$value")"
  done < "$local_env_file"
}

non_interactive=0
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --non-interactive)
      non_interactive=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
done

if ! command -v node >/dev/null 2>&1; then
  fail "Node.js 20+ is required, but node was not found"
fi

node_major="$(node -p 'Number(process.versions.node.split(".")[0])')"
if [[ "$node_major" -lt 20 ]]; then
  fail "Node.js 20+ is required, found $(node --version)"
fi

org_input="${AZURE_DEVOPS_ORG:-}"
project="${AZURE_DEVOPS_PROJECT:-}"
team="${AZURE_DEVOPS_TEAM:-}"
domains="${AZURE_DEVOPS_MCP_DOMAINS:-core,work-items,repositories,pipelines}"
pat_email="${AZURE_DEVOPS_PAT_EMAIL:-pat}"
package="${AZURE_DEVOPS_MCP_PACKAGE:-@azure-devops/mcp}"
raw_pat="${AZURE_DEVOPS_PAT:-}"
encoded_pat="${PERSONAL_ACCESS_TOKEN:-}"

if [[ "$non_interactive" -eq 0 ]]; then
  cat <<'EOF'
This writes a local ignored config file for the Azure DevOps Codex plugin.
It can include your PAT, so the file will be created with 0600 permissions.
EOF
  printf '\n'

  org_input="$(prompt_with_default 'Azure DevOps org slug or URL' "$org_input")"
  [[ -n "$org_input" ]] || fail "organization is required"

  normalize_org_input "$org_input"
  project="$(prompt_with_default 'Azure DevOps project' "${project:-$INFERRED_PROJECT}")"
  team="$(prompt_with_default 'Azure DevOps team (optional)' "$team")"
  domains="$(prompt_with_default 'MCP domains' "$domains")"
  pat_email="$(prompt_with_default 'PAT email label' "$pat_email")"

  if [[ -z "$raw_pat" && -z "$encoded_pat" ]]; then
    raw_pat="$(prompt_secret 'Azure DevOps PAT')"
  fi
else
  [[ -n "$org_input" ]] || fail "AZURE_DEVOPS_ORG is required in non-interactive mode"
fi

normalize_org_input "$org_input"
normalized_org="$NORMALIZED_ORG"
if [[ -z "$project" && -n "$INFERRED_PROJECT" ]]; then
  project="$INFERRED_PROJECT"
fi

if [[ -z "$raw_pat" && -z "$encoded_pat" ]]; then
  fail "AZURE_DEVOPS_PAT or PERSONAL_ACCESS_TOKEN is required"
fi

mkdir -p "$(dirname "$env_file")"
tmp_file="$(mktemp "${env_file}.tmp.XXXXXX")"
chmod 600 "$tmp_file"

{
  printf '# Local Azure DevOps Codex plugin configuration.\n'
  printf '# Generated by scripts/setup-codex-plugin.sh. Do not commit this file.\n'
  write_export AZURE_DEVOPS_ORG "$normalized_org"
  write_export AZURE_DEVOPS_AUTHENTICATION "pat"
  write_export AZURE_DEVOPS_MCP_DOMAINS "$domains"
  write_export AZURE_DEVOPS_PAT_EMAIL "$pat_email"
  write_export AZURE_DEVOPS_MCP_PACKAGE "$package"

  if [[ -n "$project" ]]; then
    write_export AZURE_DEVOPS_PROJECT "$project"
  fi

  if [[ -n "$team" ]]; then
    write_export AZURE_DEVOPS_TEAM "$team"
  fi

  if [[ -n "$raw_pat" ]]; then
    write_export AZURE_DEVOPS_PAT "$raw_pat"
  else
    write_export PERSONAL_ACCESS_TOKEN "$encoded_pat"
  fi
} > "$tmp_file"

mv "$tmp_file" "$env_file"
chmod 600 "$env_file"

printf 'Wrote local plugin config: %s\n' "$env_file"
printf 'Running local validation...\n'
validate_setup

cat <<'EOF'

Next steps:
  1. Restart Codex so the plugin process sees the new local config.
  2. Ask Codex: List my Azure DevOps projects.

If a PAT was ever pasted into chat, logs, screenshots, or shell history, revoke it
and create a new one before using this plugin with real access.
EOF
