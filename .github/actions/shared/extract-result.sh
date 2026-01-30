#!/bin/bash
# Shared logic for reviewer actions
# Usage: source this file, then call the functions
# Sets: CHECKS_PASSED, CHECKS_FAILED, CHECKS_SKIPPED, PASSED, RESULT

# Generate skipped result JSON
# Usage: generate_skipped_result "reason" "Check1" "Check2" "Check3" ...
# Sets: CHECKS_PASSED, CHECKS_FAILED, CHECKS_SKIPPED, PASSED, RESULT
generate_skipped_result() {
  local REASON="$1"
  shift
  local CHECK_NAMES=("$@")

  CHECKS_PASSED=0
  CHECKS_FAILED=0
  CHECKS_SKIPPED=${#CHECK_NAMES[@]}
  PASSED="true"

  # Build checks array
  local CHECKS_JSON="["
  local FIRST=true
  for NAME in "${CHECK_NAMES[@]}"; do
    if [ "$FIRST" = "true" ]; then
      FIRST=false
    else
      CHECKS_JSON="$CHECKS_JSON,"
    fi
    CHECKS_JSON="$CHECKS_JSON$(jq -n --arg name "$NAME" --arg reason "$REASON" '{name: $name, status: "skipped", result: $reason, reasoning: $reason, files: []}')"
  done
  CHECKS_JSON="$CHECKS_JSON]"

  RESULT=$(jq -n --argjson checks "$CHECKS_JSON" --arg reason "$REASON" '{checks: $checks, message: $reason}' | jq -c '.')
}

# Extract review result from execution file
# Usage: extract_review_result "$EXEC_FILE"
# Sets: CHECKS_PASSED, CHECKS_FAILED, CHECKS_SKIPPED, PASSED, RESULT
extract_review_result() {
  local EXEC="$1"

  # Initialize defaults
  CHECKS_PASSED=0
  CHECKS_FAILED=0
  CHECKS_SKIPPED=0
  PASSED="false"
  RESULT='{"checks":[],"message":"Review failed to complete"}'

  if [ -f "$EXEC" ]; then
    # Get ALL text from assistant messages, joined together
    ALL_TEXT=$(jq -r '[.[] | select(.type=="assistant") | .message.content[]? | select(.type=="text") | .text] | join("\n")' "$EXEC" 2>/dev/null || echo "")

    JSON=""

    # Strategy 1: Extract from ```json blocks — take the LAST valid one with .checks
    # (Claude may output example JSON before the actual result)
    if [ -z "$JSON" ]; then
      local BLOCK=""
      local IN_BLOCK=false
      while IFS= read -r line; do
        if [[ "$line" == '```json'* ]]; then
          IN_BLOCK=true
          BLOCK=""
          continue
        fi
        if [[ "$line" == '```'* ]] && [ "$IN_BLOCK" = true ]; then
          IN_BLOCK=false
          if echo "$BLOCK" | jq -e '.checks' >/dev/null 2>&1; then
            JSON="$BLOCK"
            # Don't break — keep going to find the LAST valid block
          fi
          continue
        fi
        if [ "$IN_BLOCK" = true ]; then
          BLOCK="${BLOCK}${line}"$'\n'
        fi
      done <<< "$ALL_TEXT"
      if [ -n "$JSON" ]; then
        echo "  [extract] Strategy 1 matched (json code block)" >&2
      fi
    fi

    # Strategy 2: Try to find raw JSON object with "checks" key on a single line
    if [ -z "$JSON" ] || ! echo "$JSON" | jq -e '.checks' >/dev/null 2>&1; then
      JSON=""
      local CANDIDATE
      CANDIDATE=$(echo "$ALL_TEXT" | grep -oP '\{"checks":\s*\[.*\]\s*(,"message":[^}]*)?\}' 2>/dev/null | head -1 || true)
      if [ -n "$CANDIDATE" ] && echo "$CANDIDATE" | jq -e '.checks' >/dev/null 2>&1; then
        JSON="$CANDIDATE"
        echo "  [extract] Strategy 2 matched (grep single-line)" >&2
      fi
    fi

    # Strategy 3: Extract JSON starting with {"checks" using perl range operator
    if [ -z "$JSON" ] || ! echo "$JSON" | jq -e '.checks' >/dev/null 2>&1; then
      JSON=""
      local CANDIDATE
      CANDIDATE=$(echo "$ALL_TEXT" | perl -ne 'print if /\{"checks":\s*\[/.../"message"\s*:/' 2>/dev/null | tr '\n' ' ' || true)
      if [ -n "$CANDIDATE" ] && echo "$CANDIDATE" | jq -e '.checks' >/dev/null 2>&1; then
        JSON="$CANDIDATE"
        echo "  [extract] Strategy 3 matched (perl range)" >&2
      fi
    fi

    # Strategy 4: Use Python brace-depth counter for robust multiline extraction
    if [ -z "$JSON" ] || ! echo "$JSON" | jq -e '.checks' >/dev/null 2>&1; then
      JSON=""
      local CANDIDATE
      CANDIDATE=$(echo "$ALL_TEXT" | python3 -c "
import sys, json

text = sys.stdin.read()
# Find all top-level JSON objects containing 'checks'
results = []
i = 0
while i < len(text):
    if text[i] == '{':
        depth = 0
        start = i
        while i < len(text):
            if text[i] == '{':
                depth += 1
            elif text[i] == '}':
                depth -= 1
                if depth == 0:
                    candidate = text[start:i+1]
                    try:
                        obj = json.loads(candidate)
                        if 'checks' in obj:
                            results.append(candidate)
                    except (json.JSONDecodeError, ValueError):
                        pass
                    break
            i += 1
    i += 1

# Print the last valid match (actual result comes after examples)
if results:
    print(results[-1])
" 2>/dev/null || true)
      if [ -n "$CANDIDATE" ] && echo "$CANDIDATE" | jq -e '.checks' >/dev/null 2>&1; then
        JSON="$CANDIDATE"
        echo "  [extract] Strategy 4 matched (python brace-depth)" >&2
      fi
    fi

    if [ -n "$JSON" ] && echo "$JSON" | jq -e '.checks' >/dev/null 2>&1; then
      # Count checks by status
      CHECKS_PASSED=$(echo "$JSON" | jq '[.checks[]? | select(.status == "passed")] | length')
      CHECKS_FAILED=$(echo "$JSON" | jq '[.checks[]? | select(.status == "failed")] | length')
      CHECKS_SKIPPED=$(echo "$JSON" | jq '[.checks[]? | select(.status == "skipped")] | length')

      # Only pass if ALL checks passed (no failures)
      if [ "$CHECKS_FAILED" = "0" ] && [ "$CHECKS_PASSED" -gt "0" ]; then
        PASSED="true"
      elif [ "$CHECKS_FAILED" = "0" ] && [ "$CHECKS_PASSED" = "0" ] && [ "$CHECKS_SKIPPED" -gt "0" ]; then
        # All skipped is considered a pass
        PASSED="true"
      fi

      RESULT=$(echo "$JSON" | jq -c '.')
    else
      echo "  [extract] No strategy matched — using default failed result" >&2
    fi
  fi
}
