#!/usr/bin/env bash
# Test suite for entrypoint.sh placeholder substitution.
# Run with: bash tests/test_entrypoint.sh
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

failures=0
total=0

assert_eq() {
  local test_name="$1"
  local expected="$2"
  local actual="$3"
  total=$((total + 1))
  if [[ "$expected" != "$actual" ]]; then
    failures=$((failures + 1))
    echo "❌ FAIL: $test_name"
    echo "  expected: $expected"
    echo "  actual:   $actual"
  else
    echo "✅ PASS: $test_name"
  fi
}

run_entrypoint() {
  local env_in="$1"
  local env_out="$2"
  local repo_vars="$3"
  local repo_secrets="$4"
  local ref_name="${5:-main}"

  run_entrypoint_files "[[\"$env_in\",\"$env_out\"]]" "$repo_vars" "$repo_secrets" "$ref_name"
  return $?
}

run_entrypoint_files() {
  local env_files="$1"
  local repo_vars="$2"
  local repo_secrets="$3"
  local ref_name="${4:-main}"

  LC_ALL="C.utf8" \
  ENV_FILES="$env_files" \
  REPO_VARS="$repo_vars" \
  REPO_SECRETS="$repo_secrets" \
  GITHUB_REF_NAME="$ref_name" \
  GITHUB_OUTPUT="$(mktemp)" \
    timeout 10 bash "$REPO_ROOT/entrypoint.sh" >/dev/null 2>&1
  return $?
}

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

REPO_VARS='{"PORT":"3000","WORKER_WAKE_PORT":"4000"}'
REPO_SECRETS='{"JOB_RUNNER_SHARED_SECRET":"x9N&***","SLASH_SECRET":"abc/def","BACKSLASH_SECRET":"abc\\def","QUOTE_SECRET":"it'"'"'s \"quoted\""}'

# --- Test 1: value containing '&' (the real-world bug case) ---
ENV_IN="$WORKDIR/t1.env.in"
ENV_OUT="$WORKDIR/t1.env.out"
printf "JOB_RUNNER_SHARED_SECRET='{JOB_RUNNER_SHARED_SECRET}'\n" > "$ENV_IN"
run_entrypoint "$ENV_IN" "$ENV_OUT" "$REPO_VARS" "$REPO_SECRETS"
rc=$?
assert_eq "exit code for '&' value" "0" "$rc"
assert_eq "'&' value substituted correctly, no growth/loop" \
  "JOB_RUNNER_SHARED_SECRET='x9N&***'" \
  "$(cat "$ENV_OUT" 2>/dev/null)"

# --- Test 2: value containing '/' ---
ENV_IN="$WORKDIR/t2.env.in"
ENV_OUT="$WORKDIR/t2.env.out"
printf "SLASH_SECRET='{SLASH_SECRET}'\n" > "$ENV_IN"
run_entrypoint "$ENV_IN" "$ENV_OUT" "$REPO_VARS" "$REPO_SECRETS"
assert_eq "'/' value substituted correctly" \
  "SLASH_SECRET='abc/def'" \
  "$(cat "$ENV_OUT" 2>/dev/null)"

# --- Test 3: value containing '\' ---
ENV_IN="$WORKDIR/t3.env.in"
ENV_OUT="$WORKDIR/t3.env.out"
printf "BACKSLASH_SECRET='{BACKSLASH_SECRET}'\n" > "$ENV_IN"
run_entrypoint "$ENV_IN" "$ENV_OUT" "$REPO_VARS" "$REPO_SECRETS"
assert_eq "'\\' value substituted correctly" \
  "BACKSLASH_SECRET='abc\\def'" \
  "$(cat "$ENV_OUT" 2>/dev/null)"

# --- Test 4: value containing quotes ---
ENV_IN="$WORKDIR/t4.env.in"
ENV_OUT="$WORKDIR/t4.env.out"
printf "QUOTE_SECRET='{QUOTE_SECRET}'\n" > "$ENV_IN"
run_entrypoint "$ENV_IN" "$ENV_OUT" "$REPO_VARS" "$REPO_SECRETS"
assert_eq "quoted value substituted correctly" \
  "QUOTE_SECRET='it's \"quoted\"'" \
  "$(cat "$ENV_OUT" 2>/dev/null)"

# --- Test 5: multiple placeholders on the same line ---
ENV_IN="$WORKDIR/t5.env.in"
ENV_OUT="$WORKDIR/t5.env.out"
printf "PAIR='{PORT}'_'{WORKER_WAKE_PORT}'\n" > "$ENV_IN"
run_entrypoint "$ENV_IN" "$ENV_OUT" "$REPO_VARS" "$REPO_SECRETS"
assert_eq "multiple placeholders on same line" \
  "PAIR=3000_4000" \
  "$(cat "$ENV_OUT" 2>/dev/null)"

# --- Test 6: existing simple numeric cases (no regression) ---
ENV_IN="$WORKDIR/t6.env.in"
ENV_OUT="$WORKDIR/t6.env.out"
printf "PORT='{PORT}'\nWORKER_WAKE_PORT='{WORKER_WAKE_PORT}'\n" > "$ENV_IN"
run_entrypoint "$ENV_IN" "$ENV_OUT" "$REPO_VARS" "$REPO_SECRETS"
assert_eq "PORT/WORKER_WAKE_PORT unchanged behavior" \
  "$(printf "PORT=3000\nWORKER_WAKE_PORT=4000")" \
  "$(cat "$ENV_OUT" 2>/dev/null)"

# --- Test 7: line with no placeholder at all (guard against corruption) ---
ENV_IN="$WORKDIR/t7.env.in"
ENV_OUT="$WORKDIR/t7.env.out"
printf "SOME_VAR=plain_no_placeholder\n" > "$ENV_IN"
run_entrypoint "$ENV_IN" "$ENV_OUT" "$REPO_VARS" "$REPO_SECRETS"
assert_eq "line without placeholder left untouched" \
  "SOME_VAR=plain_no_placeholder" \
  "$(cat "$ENV_OUT" 2>/dev/null)"

# --- Test 8: timing guard - must finish quickly, not hang ---
ENV_IN="$WORKDIR/t8.env.in"
ENV_OUT="$WORKDIR/t8.env.out"
printf "JOB_RUNNER_SHARED_SECRET='{JOB_RUNNER_SHARED_SECRET}'\n" > "$ENV_IN"
start=$(date +%s 2>/dev/null || echo 0)
run_entrypoint "$ENV_IN" "$ENV_OUT" "$REPO_VARS" "$REPO_SECRETS"
rc=$?
assert_eq "no infinite loop / timeout for '&' value" "0" "$rc"

# --- Test 9: environment-prefixed lookup for "deploy/preprod" -> "PREPROD_" ---
ENV_IN="$WORKDIR/t9.env.in"
ENV_OUT="$WORKDIR/t9.env.out"
REPO_VARS_ENV='{"PORT":"3000","PREPROD_HOST_DATABASE":"db.preprod.internal"}'
printf "HOST_DATABASE='{HOST_DATABASE}'\n" > "$ENV_IN"
run_entrypoint "$ENV_IN" "$ENV_OUT" "$REPO_VARS_ENV" "$REPO_SECRETS" "deploy/preprod"
assert_eq "'deploy/preprod' resolves via 'PREPROD_' prefix" \
  "HOST_DATABASE='db.preprod.internal'" \
  "$(cat "$ENV_OUT" 2>/dev/null)"

# --- Test 10: environment-prefixed lookup for "deploy/prod" -> "PROD_" ---
ENV_IN="$WORKDIR/t10.env.in"
ENV_OUT="$WORKDIR/t10.env.out"
REPO_VARS_ENV='{"PORT":"3000","PROD_HOST_DATABASE":"db.prod.internal"}'
printf "HOST_DATABASE='{HOST_DATABASE}'\n" > "$ENV_IN"
run_entrypoint "$ENV_IN" "$ENV_OUT" "$REPO_VARS_ENV" "$REPO_SECRETS" "deploy/prod"
assert_eq "'deploy/prod' resolves via 'PROD_' prefix" \
  "HOST_DATABASE='db.prod.internal'" \
  "$(cat "$ENV_OUT" 2>/dev/null)"

# --- Test 11: multiple pairs in ENV_FILES processed sequentially ---
ENV_IN_A="$WORKDIR/t11a.env.in"
ENV_OUT_A="$WORKDIR/t11a.env.out"
ENV_IN_B="$WORKDIR/t11b.env.in"
ENV_OUT_B="$WORKDIR/t11b.env.out"
printf "PORT='{PORT}'\n" > "$ENV_IN_A"
printf "WORKER_WAKE_PORT='{WORKER_WAKE_PORT}'\n" > "$ENV_IN_B"
run_entrypoint_files "[[\"$ENV_IN_A\",\"$ENV_OUT_A\"],[\"$ENV_IN_B\",\"$ENV_OUT_B\"]]" "$REPO_VARS" "$REPO_SECRETS"
rc=$?
assert_eq "exit code for multiple ENV_FILES pairs" "0" "$rc"
assert_eq "first pair output written correctly" \
  "PORT=3000" \
  "$(cat "$ENV_OUT_A" 2>/dev/null)"
assert_eq "second pair output written correctly" \
  "WORKER_WAKE_PORT=4000" \
  "$(cat "$ENV_OUT_B" 2>/dev/null)"

# --- Test 12: ENV_FILES with invalid JSON must fail ---
run_entrypoint_files "not-json" "$REPO_VARS" "$REPO_SECRETS"
rc=$?
assert_eq "invalid JSON ENV_FILES fails" "1" "$rc"

# --- Test 13: ENV_FILES pair with wrong element count must fail ---
ENV_IN_C="$WORKDIR/t13.env.in"
printf "PORT='{PORT}'\n" > "$ENV_IN_C"
run_entrypoint_files "[[\"$ENV_IN_C\"]]" "$REPO_VARS" "$REPO_SECRETS"
rc=$?
assert_eq "ENV_FILES pair missing output file fails" "1" "$rc"

echo ""
echo "----------------------------------------"
echo "Total: $total, Failures: $failures"
if [[ "$failures" -gt 0 ]]; then
  exit 1
fi
exit 0
