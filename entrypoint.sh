#!/usr/bin/env bash

# Exit immediately if any command fails
set -e

# Erase or create the env output file
>"$ENV_FILE_OUT"

# Loop through each line of the input env file
while IFS= read -r line || [ -n "$line" ]; do

  # Process all placeholders inside the current line
  # Placeholders must match the format: '{VARNAME}' (wrapped in single quotes)
  while [[ "$line" =~ \'\{([a-zA-Z0-9_]+)\}\' ]]; do
    # Extract the variable name from the regex match (e.g., MONGO_USER)
    var_name="${BASH_REMATCH[1]}"

    # Build the full variable name using the uppercase branch name as prefix
    # Example: MAIN_MONGO_USER
    full_var_name="$(echo "${GITHUB_REF_NAME}" | tr '[:lower:]' '[:upper:]')_${var_name}"

    # Try to resolve the variable value from secrets and vars in priority order
    var_value=$(echo "$REPO_SECRETS" | jq -r --arg key "$full_var_name" '.[$key] // empty')
    [[ -z "$var_value" ]] && var_value=$(echo "$REPO_VARS" | jq -r --arg key "$full_var_name" '.[$key] // empty')
    [[ -z "$var_value" ]] && var_value=$(echo "$REPO_SECRETS" | jq -r --arg key "$var_name" '.[$key] // empty')
    [[ -z "$var_value" ]] && var_value=$(echo "$REPO_VARS" | jq -r --arg key "$var_name" '.[$key] // empty')

    # Fail if the variable could not be found
    if [ -z "$var_value" ] || [[ "$var_value" == "null" ]]; then
      echo "Error: $var_name not found in REPO_VARS or REPO_SECRETS." >&2
      exit 1
    fi

    # Add quotes around values if necessary
    # - JSON output requires double quotes
    # - Non-numeric, non-boolean values in .env require single quotes
    if [[ "$ENV_FILE_OUT" == *.json ]]; then
      var_value="\"$var_value\""
    elif ! [[ "$var_value" =~ ^[0-9]+$ ]] &&
      [[ "$var_value" != "true" ]] &&
      [[ "$var_value" != "false" ]] &&
      ! [[ "$var_value" =~ ^\[[^]]*\]$ ]]; then
      var_value="'$var_value'"
    fi

    # Replace only the first matched placeholder in the line with the value
    line="${line/${BASH_REMATCH[0]}/$var_value}"
  done

  # Write the fully processed line to the output file
  echo "$line" >>"$ENV_FILE_OUT"
done <"$ENV_FILE_IN"

# Build the full variable name for the CloudFront distribution ID,
# using the uppercase branch name as prefix (e.g., MAIN_CLOUDFRONT_DIST_ID)
full_var_name="$(echo "${GITHUB_REF_NAME}" | tr '[:lower:]' '[:upper:]')_CLOUDFRONT_DIST_ID"

# Try to get the value from REPO_VARS using the full variable name
CLOUDFRONT_DIST_ID=$(echo "$REPO_VARS" | jq -r --arg key "$full_var_name" '.[$key] // empty')

# If not found, try REPO_SECRETS with the same full variable name
[[ -z "$CLOUDFRONT_DIST_ID" ]] && CLOUDFRONT_DIST_ID=$(echo "$REPO_SECRETS" | jq -r --arg key "$full_var_name" '.[$key] // empty')

# If still not found, try REPO_SECRETS without the branch prefix
[[ -z "$CLOUDFRONT_DIST_ID" ]] && CLOUDFRONT_DIST_ID=$(echo "$REPO_SECRETS" | jq -r --arg key "CLOUDFRONT_DIST_ID" '.[$key] // empty')

# Finally, try REPO_VARS without the branch prefix
[[ -z "$CLOUDFRONT_DIST_ID" ]] && CLOUDFRONT_DIST_ID=$(echo "$REPO_VARS" | jq -r --arg key "CLOUDFRONT_DIST_ID" '.[$key] // empty')

# If still missing or null, set it to "null"
if [ -z "$CLOUDFRONT_DIST_ID" ] || [[ "$CLOUDFRONT_DIST_ID" == "null" ]]; then
  echo "CLOUDFRONT_DIST_ID not found in REPO_VARS or REPO_SECRETS."
  CLOUDFRONT_DIST_ID="null"
fi

# Exporting CloudFront Distribution ID to GitHub output
echo "CLOUDFRONT_DIST_ID=$CLOUDFRONT_DIST_ID" >>"$GITHUB_OUTPUT"