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
  original_line="$line"

  # Process all placeholders in the line using a while loop
  while [[ "$line" =~ \'\{[a-zA-Z0-9_]+\}\' ]]; do
    # Extract the first placeholder found
    placeholder=$(echo "$line" | grep -oP "\'\{[a-zA-Z0-9_]+\}\'" | head -n1)
    # Extract just the variable name from the placeholder
    var_name=$(echo "$placeholder" | grep -oP "(?<=\{)[a-zA-Z0-9_]+(?=\})")

    echo -e "\033[1;34m🔍 Looking for:\033[0m \033[1;32m'$full_var_name'\033[0m or \033[1;32m'$var_name'\033[0m"

    # Build the full variable name using the uppercase ref name (e.g., BRANCHNAME_VARNAME)
    if [[ -n "$GITHUB_REF_NAME" ]]; then
      full_var_name="$(echo "${GITHUB_REF_NAME}" | tr '[:lower:]' '[:upper:]')_${var_name}"
    else
      full_var_name=""
    fi

    # Try to resolve the variable value by checking secrets and vars in priority order
    var_value=""

    # Only try full_var_name if it's not empty
    if [[ -n "$full_var_name" ]]; then
      var_value=$(echo "$REPO_SECRETS" | jq -r --arg key "$full_var_name" '.[$key] // empty')
      echo "Checked REPO_SECRETS[$full_var_name]: '$var_value'"
    fi

    if [[ -z "$var_value" ]] && [[ -n "$full_var_name" ]]; then
      var_value=$(echo "$REPO_VARS" | jq -r --arg key "$full_var_name" '.[$key] // empty')
      echo "Checked REPO_VARS[$full_var_name]: '$var_value'"
    fi

    if [[ -z "$var_value" ]]; then
      var_value=$(echo "$REPO_SECRETS" | jq -r --arg key "$var_name" '.[$key] // empty')
      echo "Checked REPO_SECRETS[$var_name]: '$var_value'"
    fi

    if [[ -z "$var_value" ]]; then
      var_value=$(echo "$REPO_VARS" | jq -r --arg key "$var_name" '.[$key] // empty')
      echo "Checked REPO_VARS[$var_name]: '$var_value'"
    fi

    echo "Final resolved value for '$var_name': '$var_value'"

    # Fail the script if the variable could not be found
    if [[ -z "$var_value" ]] || [[ "$var_value" == "null" ]]; then
      echo "Error: $var_name not found in REPO_VARS or REPO_SECRETS."
      exit 1
    fi

    # If the value is not a number, true, or false, wrap it in single quotes (unless it's JSON)
    processed_value="$var_value"
    if [[ "$ENV_FILE_OUT" == *.json ]]; then
      processed_value="\"$var_value\""
    elif ! [[ "$var_value" =~ ^[0-9]+$ ]] &&
      [[ "$var_value" != "true" ]] &&
      [[ "$var_value" != "false" ]] &&
      ! [[ "$var_value" =~ ^\[[^]]*\]$ ]]; then
      processed_value="'$var_value'"
    fi

    echo "Replacing '$placeholder' with '$processed_value'"

    # Replace THIS SPECIFIC placeholder in the line with the resolved value
    line=${line/$placeholder/$processed_value}

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
  # If not found, try REPO_SECRETS with the same full variable name
  [[ -z "$CLOUDFRONT_DIST_ID" ]] && CLOUDFRONT_DIST_ID=$(echo "$REPO_SECRETS" | jq -r --arg key "$full_var_name" '.[$key] // empty')
fi

# If still not found, try REPO_SECRETS without the branch prefix
[[ -z "$CLOUDFRONT_DIST_ID" ]] && CLOUDFRONT_DIST_ID=$(echo "$REPO_SECRETS" | jq -r --arg key "CLOUDFRONT_DIST_ID" '.[$key] // empty')
# Finally, try REPO_VARS without the branch prefix
[[ -z "$CLOUDFRONT_DIST_ID" ]] && CLOUDFRONT_DIST_ID=$(echo "$REPO_VARS" | jq -r --arg key "CLOUDFRONT_DIST_ID" '.[$key] // empty')

# If the variable is still missing or null
if [[ -z "$CLOUDFRONT_DIST_ID" ]] || [[ "$CLOUDFRONT_DIST_ID" == "null" ]]; then
  echo "CLOUDFRONT_DIST_ID not found in REPO_VARS or REPO_SECRETS."
  CLOUDFRONT_DIST_ID="null"
fi

# Exporting CloudFront Distribution
echo "CLOUDFRONT_DIST_ID=$CLOUDFRONT_DIST_ID" >>"$GITHUB_OUTPUT"