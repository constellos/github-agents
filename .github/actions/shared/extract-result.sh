#!/bin/bash
# Shared JSON extraction logic for reviewer actions
# Usage: source this file, then call extract_review_result "$EXEC_FILE"
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

    # Strategy 1: Extract from ```json block
    JSON=$(echo "$ALL_TEXT" | sed -n '/```json/,/```/{/```/d;p;}' | head -100)

    # Strategy 2: If no json block, try to find raw JSON object with "checks" key
    if ! echo "$JSON" | jq . >/dev/null 2>&1; then
      JSON=$(echo "$ALL_TEXT" | grep -oP '\{"checks":\s*\[.*\]\s*(,"message":[^}]*)?\}' | head -1)
    fi

    # Strategy 3: Extract any JSON object starting with {"checks"
    if ! echo "$JSON" | jq . >/dev/null 2>&1; then
      JSON=$(echo "$ALL_TEXT" | perl -ne 'print if /\{"checks":\[/.../"message":/' | tr '\n' ' ')
    fi

    # Strategy 4: Use Python for robust multiline JSON extraction
    if ! echo "$JSON" | jq . >/dev/null 2>&1; then
      JSON=$(echo "$ALL_TEXT" | python3 -c "import re,sys; t=sys.stdin.read(); m=re.search(r'\{[^{}]*\"checks\"[^{}]*\[.*?\][^{}]*\}',t,re.DOTALL); print(m.group() if m else '')" 2>/dev/null)
    fi

    if echo "$JSON" | jq . >/dev/null 2>&1; then
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
    fi
  fi
}
