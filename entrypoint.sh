# If any error occurs in the script, the execution will stop with a non-zero exit code.
set -e

# Show GITHUB_REF_NAME value
echo "GITHUB_REF_NAME='$GITHUB_REF_NAME'"

echo "Available REPO_SECRETS keys:"
echo "$REPO_SECRETS" | jq -r 'keys[]'
echo "Available REPO_VARS keys:"
echo "$REPO_VARS" | jq -r 'keys[]'

# Erase or create the env file out
>"$ENV_FILE_OUT"

# Loop through each line of the input env file
while IFS= read -r line || [ -n "$line" ]; do
  echo "Processing line: $line"

  # Process placeholders until none remain
  while [[ "$line" =~ \{[A-Za-z0-9_]+\} ]]; do
    placeholder=""
    is_quoted=false
    has_tilde=false

    if echo "$line" | grep -qP "'~\{[A-Za-z0-9_]+\}'"; then
      placeholder=$(echo "$line" | grep -oP "'~\{[A-Za-z0-9_]+\}'" | head -n1)
      is_quoted=true
      has_tilde=true
      inner=$(echo "$placeholder" | grep -oP "\{[A-Za-z0-9_]+\}")
    elif echo "$line" | grep -qP "'\{[A-Za-z0-9_]+\}'"; then
      placeholder=$(echo "$line" | grep -oP "'\{[A-Za-z0-9_]+\}'" | head -n1)
      is_quoted=true
      has_tilde=false
      inner=$(echo "$placeholder" | grep -oP "\{[A-Za-z0-9_]+\}")
    else
      # No quoted placeholder → break to avoid touching raw {VAR}
      break
    fi

    var_name=$(echo "$placeholder" | grep -oP "(?<=\{)[A-Za-z0-9_]+(?=\})")

    # Build the full variable name using the uppercase ref name (e.g., BRANCHNAME_VARNAME)
    if [[ -n "$GITHUB_REF_NAME" ]]; then
      full_var_name="$(echo "${GITHUB_REF_NAME}" | tr '[:lower:]' '[:upper:]')_${var_name}"
    else
      full_var_name=""
    fi

    echo -e "\033[1;34m🔍 Looking for:\033[0m \033[1;32m'$full_var_name'\033[0m or \033[1;32m'$var_name'\033[0m"

    # Resolve the variable value by checking secrets and vars in priority order
    var_value=""
    if [[ -n "$full_var_name" ]]; then
      var_value=$(echo "$REPO_SECRETS" | jq -r --arg key "$full_var_name" '.[$key] // empty')
      [[ -z "$var_value" ]] && var_value=$(echo "$REPO_VARS" | jq -r --arg key "$full_var_name" '.[$key] // empty')
    fi
    [[ -z "$var_value" ]] && var_value=$(echo "$REPO_SECRETS" | jq -r --arg key "$var_name" '.[$key] // empty')
    [[ -z "$var_value" ]] && var_value=$(echo "$REPO_VARS" | jq -r --arg key "$var_name" '.[$key] // empty')

    echo "Final resolved value for '$var_name': '$var_value'"

    if [[ -z "$var_value" ]] || [[ "$var_value" == "null" ]]; then
      echo "Error: $var_name not found in REPO_VARS or REPO_SECRETS."
      exit 1
    fi

    # Quoted placeholder → choose quoting or raw depending on tilde
    if $has_tilde; then
      echo -e "\033[1;33m⚠️ Detected '~' escape for $var_name → using raw value without quotes\033[0m"
      processed_value="$var_value"
      line=${line/$placeholder/$processed_value}
    else
      processed_value="$var_value"
      line=${line/$inner/$processed_value}
    fi

    echo "Line after replacement: $line"
  done

  # Write the processed line to the output env file
  echo "$line" >>"$ENV_FILE_OUT"
done <"$ENV_FILE_IN"

# Build the full variable name for the CloudFront distribution ID,
# using the uppercase branch name as a prefix (e.g., MAIN_CLOUDFRONT_DIST_ID)
if [[ -n "$GITHUB_REF_NAME" ]]; then
  full_var_name="$(echo "${GITHUB_REF_NAME}" | tr '[:lower:]' '[:upper:]')_CLOUDFRONT_DIST_ID"
else
  full_var_name="CLOUDFRONT_DIST_ID"
fi

# Try to get the value from REPO_VARS using the full variable name
CLOUDFRONT_DIST_ID=""
if [[ -n "$full_var_name" ]] && [[ "$full_var_name" != "CLOUDFRONT_DIST_ID" ]]; then
  CLOUDFRONT_DIST_ID=$(echo "$REPO_VARS" | jq -r --arg key "$full_var_name" '.[$key] // empty')
  [[ -z "$CLOUDFRONT_DIST_ID" ]] && CLOUDFRONT_DIST_ID=$(echo "$REPO_SECRETS" | jq -r --arg key "$full_var_name" '.[$key] // empty')
fi

[[ -z "$CLOUDFRONT_DIST_ID" ]] && CLOUDFRONT_DIST_ID=$(echo "$REPO_SECRETS" | jq -r --arg key "CLOUDFRONT_DIST_ID" '.[$key] // empty')
[[ -z "$CLOUDFRONT_DIST_ID" ]] && CLOUDFRONT_DIST_ID=$(echo "$REPO_VARS" | jq -r --arg key "CLOUDFRONT_DIST_ID" '.[$key] // empty')

if [[ -z "$CLOUDFRONT_DIST_ID" ]] || [[ "$CLOUDFRONT_DIST_ID" == "null" ]]; then
  echo "CLOUDFRONT_DIST_ID not found in REPO_VARS or REPO_SECRETS."
  CLOUDFRONT_DIST_ID="null"
fi

echo "CLOUDFRONT_DIST_ID=$CLOUDFRONT_DIST_ID" >>"$GITHUB_OUTPUT"