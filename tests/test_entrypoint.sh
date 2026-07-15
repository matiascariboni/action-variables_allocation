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

  LC_ALL="C.utf8" \
  ENV_FILE_IN="$env_in" \
  ENV_FILE_OUT="$env_out" \
  REPO_VARS="$repo_vars" \
  REPO_SECRETS="$repo_secrets" \
  GITHUB_REF_NAME="main" \
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

echo ""
echo "----------------------------------------"
echo "Total: $total, Failures: $failures"
if [[ "$failures" -gt 0 ]]; then
  exit 1
fi
exit 0
