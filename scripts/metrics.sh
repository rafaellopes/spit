#!/usr/bin/env bash
# scripts/metrics.sh — painel rápido de tracção do Spit. Corre: ./scripts/metrics.sh
set -euo pipefail
REPO="Draxo-io/spit"
echo "════════ SPIT — TRACÇÃO $(date +%Y-%m-%d\ %H:%M) ════════"
echo ""
echo "▸ Downloads por release (proxy de instalações):"
gh api "/repos/$REPO/releases" --jq '.[] | "   \(.tag_name): \([.assets[].download_count] | add // 0)"'
TOTAL=$(gh api "/repos/$REPO/releases" --jq '[.[].assets[].download_count] | add')
echo "   ─────────────────────"
echo "   TOTAL: $TOTAL downloads"
echo ""
echo "▸ GitHub:"
gh api "/repos/$REPO" --jq '"   ⭐ stars: \(.stargazers_count)   👁 watchers: \(.subscribers_count)   🍴 forks: \(.forks_count)"'
echo ""
echo "▸ Tráfego do repo (14 dias):"
gh api "/repos/$REPO/traffic/views"  --jq '"   views:  \(.count) (\(.uniques) únicos)"' 2>/dev/null || echo "   (sem acesso a traffic)"
gh api "/repos/$REPO/traffic/clones" --jq '"   clones: \(.count) (\(.uniques) únicos)"' 2>/dev/null || true
echo ""
echo "▸ Referrers principais:"
gh api "/repos/$REPO/traffic/popular/referrers" --jq '.[] | "   \(.referrer): \(.count) (\(.uniques) únicos)"' 2>/dev/null | head -5 || echo "   (nenhum ainda)"
echo "════════════════════════════════════════════════"
