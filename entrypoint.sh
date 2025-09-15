# If any error occurs in the script, the execution will stop with a non-zero exit code.
set -e

findVarName() {
  local line="$1"
  echo "Processing line: $line" >&2

  # Extract the current placeholder found
  local placeholder=$(echo "$line" | grep -oP "'~?\{[a-zA-Z0-9_-]+\}'" | head -n1)
  # Extract just the variable name from the placeholder
  local var_name=$(echo "$placeholder" | grep -oP "(?<=\{)[a-zA-Z0-9_-]+(?=\})")

  # Build the full variable name using the uppercase ref name (e.g., BRANCHNAME_VARNAME)
  if [[ -n "$GITHUB_REF_NAME" ]]; then
    local full_var_name="$(echo "${GITHUB_REF_NAME}" | tr '[:lower:]' '[:upper:]')_${var_name}"
  else
    local full_var_name=""
  fi

  echo "$var_name $full_var_name $placeholder"
}

findVarValue() {
  local var_name=$1
  local full_var_name=$2
  local bypass_err="${3:-false}"
  local var_value=""

  # Look for full_var_name (branch + var) in repo secrets
  if [[ -n "$full_var_name" ]]; then
    var_value=$(echo "$REPO_SECRETS" | jq -r --arg key "$full_var_name" '.[$key] // empty')
    echo "Checked REPO_SECRETS[$full_var_name]: $(if [[ -n "$var_value" ]]; then echo "'$var_value'"; else echo "''"; fi)" >&2
  fi

  # Case secrets doesn't have full_var_name, find it in repo vars
  if [[ -z "$var_value" ]] && [[ -n "$full_var_name" ]]; then
    var_value=$(echo "$REPO_VARS" | jq -r --arg key "$full_var_name" '.[$key] // empty')
    echo "Checked REPO_VARS[$full_var_name]: $(if [[ -n "$var_value" ]]; then echo "'$var_value'"; else echo "''"; fi)" >&2
  fi

  # Case full_var_name are not in repo secrets or vars, let's find the variable without prefix in repo secrets
  if [[ -z "$var_value" ]]; then
    var_value=$(echo "$REPO_SECRETS" | jq -r --arg key "$var_name" '.[$key] // empty')
    echo "Checked REPO_SECRETS[$var_name]: $(if [[ -n "$var_value" ]]; then echo "'$var_value'"; else echo "''"; fi)" >&2
  fi

  # Case var_name are not in repo secrets, let's find it in repo vars
  if [[ -z "$var_value" ]]; then
    var_value=$(echo "$REPO_VARS" | jq -r --arg key "$var_name" '.[$key] // empty')
    echo "Checked REPO_VARS[$var_name]: $(if [[ -n "$var_value" ]]; then echo "'$var_value'"; else echo "''"; fi)" >&2
  fi

  # If var_name doesn't exists, throw error and stop de execution
  if [[ -z "$var_value" ]] || [[ "$var_value" == "null" ]]; then
    echo -e "\033[1;31m❌ Error:\033[0m \033[1;31m'$var_name'\033[0m or \033[1;31m'$full_var_name'\033[0m not found in REPO_VARS or REPO_SECRETS." >&2
    if [[ "$bypass_err" == "false" ]]; then
      exit 1
    else
      echo "⚠️ The execution will continue (bypass_err=true)" >&2
      echo "null"
      return 0
    fi
  fi

  echo "$var_value"
}

formatValue() {
  local placeholder=$1
  local var_value=$2

  # If the file it's a json, add double quotes
  if [[ "$ENV_FILE_OUT" == *.json ]]; then
    jq -Rn --arg v "$var_value" '$v'
  # If the value isn't an int number, boolean or don't have "~" then add single quotes
  elif ! [[ "$var_value" =~ ^-?[0-9]+([.][0-9]+)?$ ]] &&
    [[ "$var_value" != "true" ]] &&
    [[ "$var_value" != "false" ]] &&
    ! [[ "$var_value" =~ ^\[[^]]*\]$ ]] &&
    ! [[ "$placeholder" =~ ^\'~\{ ]]; then
    var_value="'$var_value'"
  # If it does not match these conditions, leave it without any quotes.
  fi

  echo "$var_value"
}

processFile() {
  # Show GITHUB_REF_NAME value
  echo "GITHUB_REF_NAME='$GITHUB_REF_NAME'"

  if [[ "$GITHUB_REF_NAME" == *"/"* ]]; then
  echo -e "\033[1;33m⚠️  Warning:\033[0m Branch name contains '/' -> prefixed environment variables will not work with this version of 'variables_allocation'. Execution will continue."
  fi

  echo "Available REPO_SECRETS keys:"
  echo "$REPO_SECRETS" | jq -r 'keys[]'
  echo "Available REPO_VARS keys:"
  echo "$REPO_VARS" | jq -r 'keys[]'

  # Erase or create the env file out
  >"$ENV_FILE_OUT"

  # Loop through each line of the input env file
  while IFS= read -r line || [ -n "$line" ]; do
  # Process all placeholders in the line using a while loop
    while [[ "$line" =~ \'~?\{[a-zA-Z0-9_-]+\}\' ]]; do
      read var_name full_var_name placeholder <<< "$(findVarName "$line")"

      echo -e "\033[1;34m🔍 Looking for:\033[0m \033[1;32m'$full_var_name'\033[0m or \033[1;32m'$var_name'\033[0m"

      read var_value <<< "$(findVarValue "$var_name" "$full_var_name")"

      echo -e "\033[1;32m✅ Final resolved value for '\033[1;36m$var_name\033[1;32m': '\033[1;33m$var_value\033[1;32m'\033[0m"

      read processed_value <<< "$(formatValue "$placeholder" "$var_value")"

      echo "Replacing '$placeholder' with '$processed_value'"

      # Replace THIS SPECIFIC placeholder in the line with the resolved value
      line=${line/$placeholder/$processed_value}

      echo "Line after replacement: $line"
    done

    # Write the processed line to the output env file
    echo "$line" >>"$ENV_FILE_OUT"
  done <"$ENV_FILE_IN"
}

processCloudFront() {
  local line="'~{CLOUDFRONT_DIST_ID}'"

  read var_name full_var_name placeholder <<< "$(findVarName "$line")"

  echo -e "\033[1;34m🔍 Looking for:\033[0m \033[1;32m'$full_var_name'\033[0m or \033[1;32m'$var_name'\033[0m"

  read var_value <<< "$(findVarValue "$var_name" "$full_var_name" "true")"

  if [[ "$var_value" == "null" ]]; then
    echo "CLOUDFRONT_DIST_ID not found. Finishing..."
    return 0
  fi

  echo -e "\033[1;32m✅ Final resolved '\033[1;36m$var_name\033[1;32m' for: '\033[1;33m$var_value\033[1;32m'\033[0m"

  # Exporting CloudFront Distribution
  echo "$var_name=$var_value" >>"$GITHUB_OUTPUT"
}

processFile
processCloudFront