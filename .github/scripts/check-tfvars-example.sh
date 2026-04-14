#!/usr/bin/env bash
# Checks that every variable declared in a module's .tf files is present in
# terraform.tfvars.example, and vice versa. Catches the case where a variable
# is added to the code but the example file is not updated (or the other way around).
#
# Only runs for modules that have a terraform.tfvars.example (infra uses clouds.yaml,
# so it is excluded).

set -euo pipefail

fail=0

for module in vault keycloak; do
  example="terraform/${module}/terraform.tfvars.example"

  if [[ ! -f "${example}" ]]; then
    continue
  fi

  # Variable names declared across all .tf files in the module
  declared=$(grep -rh '^variable "' "terraform/${module}/"*.tf \
    | sed 's/^variable "\([^"]*\)".*/\1/' \
    | sort -u)

  # Variable names present in the example file (skip comments and blank lines)
  in_example=$(grep -v '^[[:space:]]*#' "${example}" \
    | grep '=' \
    | awk '{print $1}' \
    | sort -u)

  missing=$(comm -23 <(echo "${declared}") <(echo "${in_example}"))
  extra=$(comm -13 <(echo "${declared}") <(echo "${in_example}"))

  if [[ -n "${missing}" ]]; then
    echo "FAIL terraform/${module}: declared in .tf but missing from terraform.tfvars.example:"
    echo "${missing}" | sed 's/^/  - /'
    fail=1
  fi

  if [[ -n "${extra}" ]]; then
    echo "FAIL terraform/${module}: in terraform.tfvars.example but not declared in .tf files:"
    echo "${extra}" | sed 's/^/  - /'
    fail=1
  fi

  if [[ $fail -eq 0 ]]; then
    echo "OK   terraform/${module}"
  fi
done

exit ${fail}
