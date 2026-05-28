#!/usr/bin/env bash
set -euo pipefail
set +x
umask 077

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
plugin_root="$(cd "$script_dir/.." && pwd)"
local_env_file="${AZURE_DEVOPS_LOCAL_ENV_FILE:-$plugin_root/.env.local}"

if [[ -f "$local_env_file" ]]; then
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
fi

if [[ -z "${AZURE_DEVOPS_ORG:-}" ]]; then
  cat >&2 <<'EOF'
AZURE_DEVOPS_ORG is required.

Set it to your Azure DevOps organization slug, for example:
  export AZURE_DEVOPS_ORG=contoso

Full dev.azure.com URLs are accepted too. The launcher will extract the org slug
and infer the project from the first path segment when AZURE_DEVOPS_PROJECT is
not already set.

Optional environment variables:
  AZURE_DEVOPS_MCP_PACKAGE=@azure-devops/mcp
  AZURE_DEVOPS_MCP_DOMAINS=core,work-items,repositories,pipelines
  AZURE_DEVOPS_AUTHENTICATION=pat
  AZURE_DEVOPS_PAT=<raw Azure DevOps PAT>
  AZURE_DEVOPS_PAT_EMAIL=pat
  PERSONAL_ACCESS_TOKEN=<base64-encoded email:pat>
  AZURE_DEVOPS_PROJECT="Project name"
  AZURE_DEVOPS_TEAM="Team name"

You can also run:
  ./scripts/setup-codex-plugin.sh
EOF
  exit 64
fi

package="${AZURE_DEVOPS_MCP_PACKAGE:-@azure-devops/mcp}"
authentication="${AZURE_DEVOPS_AUTHENTICATION:-}"
organization="$AZURE_DEVOPS_ORG"
inferred_project=""

if [[ "$organization" =~ ^https?://dev\.azure\.com/([^/?#]+)/?([^?#]*) ]]; then
  organization="${BASH_REMATCH[1]}"
  path_after_org="${BASH_REMATCH[2]}"
  path_after_org="${path_after_org#/}"
  if [[ -n "$path_after_org" ]]; then
    inferred_project="${path_after_org%%/*}"
  fi
elif [[ "$organization" =~ ^https?://([^./]+)\.visualstudio\.com/?([^?#]*) ]]; then
  organization="${BASH_REMATCH[1]}"
  path_after_org="${BASH_REMATCH[2]}"
  path_after_org="${path_after_org#/}"
  if [[ -n "$path_after_org" ]]; then
    inferred_project="${path_after_org%%/*}"
  fi
elif [[ "$organization" == http://* || "$organization" == https://* || "$organization" == */* ]]; then
  cat >&2 <<EOF
AZURE_DEVOPS_ORG should be an organization slug, not an arbitrary URL.

Expected:
  export AZURE_DEVOPS_ORG=gps-aie-devops

Accepted URL form:
  export AZURE_DEVOPS_ORG=https://dev.azure.com/gps-aie-devops/AIE/

Received:
  $AZURE_DEVOPS_ORG
EOF
  exit 66
fi

if [[ -z "${AZURE_DEVOPS_PROJECT:-}" && -n "$inferred_project" ]]; then
  export AZURE_DEVOPS_PROJECT="$inferred_project"
fi

if [[ -n "${AZURE_DEVOPS_PAT:-}" ]]; then
  authentication="${authentication:-pat}"
  pat_email="${AZURE_DEVOPS_PAT_EMAIL:-pat}"
  export PERSONAL_ACCESS_TOKEN
  PERSONAL_ACCESS_TOKEN="$(printf '%s:%s' "$pat_email" "$AZURE_DEVOPS_PAT" | base64 | tr -d '\n')"
fi

if [[ "$authentication" == "pat" && -z "${PERSONAL_ACCESS_TOKEN:-}" ]]; then
  cat >&2 <<'EOF'
PAT authentication requires a token.

Set one of these before starting Codex:
  export AZURE_DEVOPS_PAT=<raw Azure DevOps PAT>

or set the Microsoft MCP server's expected value directly:
  export PERSONAL_ACCESS_TOKEN=<base64-encoded email:pat>

Do not commit PAT values to plugin config files.
EOF
  exit 65
fi

args=("-y" "$package" "$organization")

if [[ -n "$authentication" ]]; then
  args+=("--authentication" "$authentication")
fi

if [[ -n "${AZURE_DEVOPS_MCP_DOMAINS:-}" ]]; then
  IFS=',' read -r -a domains <<< "$AZURE_DEVOPS_MCP_DOMAINS"
  cleaned_domains=()
  for domain in "${domains[@]}"; do
    domain="${domain#"${domain%%[![:space:]]*}"}"
    domain="${domain%"${domain##*[![:space:]]}"}"
    if [[ -n "$domain" ]]; then
      cleaned_domains+=("$domain")
    fi
  done

  if [[ "${#cleaned_domains[@]}" -gt 0 ]]; then
    args+=("-d")
    args+=("${cleaned_domains[@]}")
  fi
fi

if [[ -n "${AZURE_DEVOPS_PROJECT:-}" ]]; then
  export ado_mcp_project="$AZURE_DEVOPS_PROJECT"
fi

if [[ -n "${AZURE_DEVOPS_TEAM:-}" ]]; then
  export ado_mcp_team="$AZURE_DEVOPS_TEAM"
fi

if [[ "${AZURE_DEVOPS_MCP_DRY_RUN:-}" == "1" ]]; then
  printf 'organization=%s\n' "$organization"
  printf 'authentication=%s\n' "${authentication:-default}"
  printf 'project=%s\n' "${AZURE_DEVOPS_PROJECT:-}"
  printf 'team=%s\n' "${AZURE_DEVOPS_TEAM:-}"
  printf 'domains=%s\n' "${AZURE_DEVOPS_MCP_DOMAINS:-default}"
  exit 0
fi

exec npx "${args[@]}"
