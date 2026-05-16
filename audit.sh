#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# Safe Deployments Lab — Local Audit Script (Version B)
# ══════════════════════════════════════════════════════════════════════════════
# Runs Gemini CLI against the codebase using GEMINI.md as instruction context.
# Saves the audit report and exits with code 1 if critical findings are found.
#
# Usage:
#   ./audit.sh                  # Full audit
#   ./audit.sh --save           # Audit and save report to audit-report.md
#   ./audit.sh --pre-push       # Used as git pre-push hook — blocks on critical
#
# Prerequisites:
#   npm install -g @google/gemini-cli
#   gemini auth login           # or: export GEMINI_API_KEY=your_key
# ══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

REPORT_FILE="audit-report.md"
SAVE_REPORT=false
PRE_PUSH=false

# ── Parse args ────────────────────────────────────────────────────────────────
for arg in "$@"; do
  case $arg in
    --save)      SAVE_REPORT=true ;;
    --pre-push)  PRE_PUSH=true; SAVE_REPORT=true ;;
  esac
done

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

# ── Check gemini CLI is installed ─────────────────────────────────────────────
if ! command -v gemini &> /dev/null; then
  echo -e "${RED}❌ Gemini CLI not found.${NC}"
  echo ""
  echo "Install it:"
  echo "  npm install -g @google/gemini-cli"
  echo ""
  echo "Then authenticate:"
  echo "  gemini auth login              # Google account (free)"
  echo "  export GEMINI_API_KEY=...      # or: API key from AI Studio"
  exit 1
fi

# ── Check we're in the right directory ───────────────────────────────────────
if [ ! -f "GEMINI.md" ]; then
  echo -e "${RED}❌ GEMINI.md not found.${NC}"
  echo "Run this script from the root of the safe-deployments-lab repo."
  exit 1
fi

# ── Run the audit ─────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}Safe Deployments Lab — AI Audit Gate${NC}"
echo -e "${DIM}Gemini CLI · Version B (local audit)${NC}"
echo ""
echo -e "${BLUE}→ Reading GEMINI.md instructions...${NC}"
echo -e "${BLUE}→ Scanning app/ + .github/workflows/ + config files...${NC}"
echo ""

# Run gemini non-interactively with the audit prompt
# GEMINI.md is auto-loaded as context since we're in the repo root
AUDIT_OUTPUT=$(gemini -p "audit" --output-format text 2>&1)

# ── Display the report ────────────────────────────────────────────────────────
echo "$AUDIT_OUTPUT"
echo ""

# ── Save report if requested ──────────────────────────────────────────────────
if [ "$SAVE_REPORT" = true ]; then
  echo "$AUDIT_OUTPUT" > "$REPORT_FILE"
  echo -e "${DIM}Report saved: $REPORT_FILE${NC}"
  echo ""
fi

# ── Gate logic ────────────────────────────────────────────────────────────────
# Check the output for the block/warn/pass verdict
if echo "$AUDIT_OUTPUT" | grep -q "❌ DEPLOY BLOCKED"; then
  echo -e "${RED}${BOLD}Push blocked.${NC} Fix critical findings before pushing to GitHub."
  echo ""

  if [ "$PRE_PUSH" = true ]; then
    echo -e "${DIM}This check ran as a git pre-push hook.${NC}"
    echo -e "${DIM}To bypass (not recommended): git push --no-verify${NC}"
  fi

  exit 1

elif echo "$AUDIT_OUTPUT" | grep -q "⚠️  DEPLOY WITH CAUTION"; then
  echo -e "${YELLOW}${BOLD}Caution.${NC} Review findings before pushing."
  exit 0

elif echo "$AUDIT_OUTPUT" | grep -q "✅ AUDIT PASSED"; then
  echo -e "${GREEN}${BOLD}Audit passed.${NC} Safe to push."
  exit 0

else
  # Gemini output didn't match expected format — don't block, warn instead
  echo -e "${YELLOW}Could not determine audit verdict from output.${NC}"
  echo -e "${DIM}Review the output above manually before pushing.${NC}"
  exit 0
fi
