# If any error occurs in the script, the execution will stop with a non-zero exit code.
set -e

# Erase or create the env file out
> "$ENV_FILE_OUT"

# Loop through each line of the input env file
while IFS= read -r line || [ -n "$line" ]
do
  # Ignore lines that start with '//' (treated as comments)
  if [[ ! "$line" =~ ^// ]]; then

    # Check if the line contains a placeholder in the format '{VARNAME}' wrapped in single quotes
    if [[ "$line" =~ \'\{[a-zA-Z0-9_]+\}\' ]]; then

      # Extract the variable name from the placeholder
      var_name=$(echo "$line" | grep -oP "(?<=\{)[a-zA-Z0-9_]+(?=\})")

      # Build the full variable name using the uppercase ref name (e.g., BRANCHNAME_VARNAME)
      full_var_name="$(echo "${GITHUB_REF_NAME}" | tr '[:lower:]' '[:upper:]')_${var_name}"

      # Try to resolve the variable value by checking secrets and vars in priority order
      var_value=$(echo "$REPO_SECRETS" | jq -r --arg key "$full_var_name" '.[$key] // empty')
      [[ -z "$var_value" ]] && var_value=$(echo "$REPO_VARS" | jq -r --arg key "$full_var_name" '.[$key] // empty')
      [[ -z "$var_value" ]] && var_value=$(echo "$REPO_SECRETS" | jq -r --arg key "$var_name" '.[$key] // empty')
      [[ -z "$var_value" ]] && var_value=$(echo "$REPO_VARS" | jq -r --arg key "$var_name" '.[$key] // empty')

      # Fail the script if the variable could not be found
      if [ -z "$var_value" ] || [[ "$var_value" == "null" ]]; then
        echo "Error: $var_name not found in REPO_VARS or REPO_SECRETS." >&2
        exit 1
      fi

      # If the value is not a number, true, or false, wrap it in single quotes
      if ! [[ "$var_value" =~ ^[0-9]+$ ]] && \
      [[ "$var_value" != "true" ]] && \
      [[ "$var_value" != "false" ]] && \
      ! [[ "$var_value" =~ ^\[[^]]*\]$ ]]; then
        var_value="'$var_value'"
      fi

      # Replace the placeholder in the line with the resolved value
      line=${line//\'\{$var_name\}\'/$var_value}
    fi

    # Write the processed line to the output env file
    echo "$line" >> "$ENV_FILE_OUT"
  fi
done < "$ENV_FILE_IN"

# Build the full variable name for the CloudFront distribution ID,
# using the uppercase branch name as a prefix (e.g., MAIN_CLOUDFRONT_DIST_ID)
full_var_name="$(echo "${GITHUB_REF_NAME}" | tr '[:lower:]' '[:upper:]')_CLOUDFRONT_DIST_ID"

# Try to get the value from REPO_VARS using the full variable name
CLOUDFRONT_DIST_ID=$(echo "$REPO_VARS" | jq -r --arg key "$full_var_name" '.[$key] // empty')

# If not found, try REPO_SECRETS with the same full variable name
[[ -z "$CLOUDFRONT_DIST_ID" ]] && CLOUDFRONT_DIST_ID=$(echo "$REPO_SECRETS" | jq -r --arg key "$full_var_name" '.[$key] // empty')

# If still not found, try REPO_SECRETS without the branch prefix
[[ -z "$CLOUDFRONT_DIST_ID" ]] && CLOUDFRONT_DIST_ID=$(echo "$REPO_SECRETS" | jq -r --arg key "CLOUDFRONT_DIST_ID" '.[$key] // empty')

# Finally, try REPO_VARS without the branch prefix
[[ -z "$CLOUDFRONT_DIST_ID" ]] && CLOUDFRONT_DIST_ID=$(echo "$REPO_VARS" | jq -r --arg key "CLOUDFRONT_DIST_ID" '.[$key] // empty')

# If the variable is still missing or null
if [ -z "$CLOUDFRONT_DIST_ID" ] || [[ "$CLOUDFRONT_DIST_ID" == "null" ]]; then
  echo "CLOUDFRONT_DIST_ID not found in REPO_VARS or REPO_SECRETS."
  CLOUDFRONT_DIST_ID="NOCDNFOUND"
fi

# Exporting CloudFront Distribution
echo "CLOUDFRONT_DIST_ID=$CLOUDFRONT_DIST_ID" >> "$GITHUB_OUTPUT"