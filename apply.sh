#!/usr/bin/env bash
# Apply the shared ruleset to every public, non-archived source repository
# owned by the account, or to the repositories named on the command line.
#
# Usage:
#   ./apply.sh                      apply to all public, non-archived source repos
#   ./apply.sh audio-stack-rs ...   apply to the named repos only
#   ./apply.sh --dry-run [repo...]  print what would change without changing anything
set -euo pipefail

owner=obazin
root=$(cd "$(dirname "$0")" && pwd)
ruleset="$root/rulesets/default-branch.json"
dry_run=false

if [ "${1:-}" = "--dry-run" ]; then
  dry_run=true
  shift
fi

name=$(jq -r .name "$ruleset")

if [ "$#" -gt 0 ]; then
  repositories=("$@")
else
  repositories=()
  while IFS= read -r repository; do
    repositories+=("$repository")
  done < <(gh repo list "$owner" --source --no-archived --visibility public --limit 1000 --json name --jq '.[].name' | sort)
fi

# Build the payload for one repository: the shared ruleset, plus a
# required_status_checks rule when checks/<repository>.json lists check names.
payload_for() {
  local repository=$1
  local checks="$root/checks/$repository.json"
  if [ -f "$checks" ]; then
    jq --slurpfile names "$checks" '
      .rules += [{
        type: "required_status_checks",
        parameters: {
          strict_required_status_checks_policy: false,
          required_status_checks: ($names[0] | map({context: .}))
        }
      }]' "$ruleset"
  else
    cat "$ruleset"
  fi
}

for repository in "${repositories[@]}"; do
  full_name="$owner/$repository"
  identifier=$(gh api "repos/$full_name/rulesets" --jq ".[] | select(.name == \"$name\") | .id")
  checks_note=""
  [ -f "$root/checks/$repository.json" ] && checks_note=" (with checks: $(jq -c . "$root/checks/$repository.json"))"

  if [ -n "$identifier" ]; then
    action="update"
  else
    action="create"
  fi

  if [ "$dry_run" = true ]; then
    echo "would $action $name on $full_name$checks_note"
    continue
  fi

  if [ "$action" = "update" ]; then
    payload_for "$repository" | gh api --method PUT "repos/$full_name/rulesets/$identifier" --input - > /dev/null
  else
    payload_for "$repository" | gh api --method POST "repos/$full_name/rulesets" --input - > /dev/null
  fi
  echo "${action}d $name on $full_name$checks_note"
done
