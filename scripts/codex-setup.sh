#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

printf '%s\n' "Azure DevOps Codex plugin setup"
printf '%s\n' "This will create or update the plugin's local .env.local file with your Azure DevOps settings."
printf '%s\n' "Your PAT stays on this machine and is not added to the plugin bundle."
printf '\n'

exec "$repo_root/scripts/install.sh" "$@"
