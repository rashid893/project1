#!/usr/bin/env bash
# =============================================================================
# repo-setup.sh — Configure GitHub repo settings for the CI/CD pipeline
#
# Prerequisites:
#   - GitHub CLI (gh) authenticated
#   - Repo already created on GitHub
#
# Usage:
#   ./scripts/repo-setup.sh <owner/repo>
#   Example: ./scripts/repo-setup.sh myorg/cicd-demo-api
# =============================================================================
set -euo pipefail

REPO="${1:?Usage: $0 <owner/repo>}"

echo "==> Configuring repository: ${REPO}"

# ---------------------------------------------------------------------------
# 1. Create GitHub Environments
# ---------------------------------------------------------------------------
echo "--- Creating environments..."

# Dev environment (no approval required)
gh api -X PUT "repos/${REPO}/environments/dev" \
  --input - <<'EOF'
{
  "wait_timer": 0,
  "deployment_branch_policy": {
    "protected_branches": false,
    "custom_branch_policies": true
  }
}
EOF

# Allow dev deploys from main and develop
for branch in main develop; do
  gh api -X POST "repos/${REPO}/environments/dev/deployment-branch-policies" \
    --input - <<EOF
{ "name": "${branch}" }
EOF
done

# Production environment (manual approval required)
gh api -X PUT "repos/${REPO}/environments/production" \
  --input - <<'EOF'
{
  "wait_timer": 0,
  "reviewers": [],
  "deployment_branch_policy": {
    "protected_branches": false,
    "custom_branch_policies": true
  }
}
EOF

# Production only from main
gh api -X POST "repos/${REPO}/environments/production/deployment-branch-policies" \
  --input - <<'EOF'
{ "name": "main" }
EOF

echo ""
echo "⚠️  MANUAL STEP: Add required reviewers to the 'production' environment"
echo "   Go to: https://github.com/${REPO}/settings/environments/production"
echo "   Under 'Required reviewers', add at least one person/team."
echo ""

# ---------------------------------------------------------------------------
# 2. Set repository secrets
# ---------------------------------------------------------------------------
echo "--- Setting secrets (you'll be prompted for values)..."

SECRETS=(
  "AWS_ROLE_ARN"
  "AWS_ROLE_ARN_PROD"
  "SONAR_TOKEN"
  "SONAR_HOST_URL"
  "SLACK_WEBHOOK_URL"
)

for secret in "${SECRETS[@]}"; do
  echo ""
  read -rsp "Enter value for ${secret} (hidden): " value
  echo ""
  if [[ -n "${value}" ]]; then
    echo "${value}" | gh secret set "${secret}" --repo "${REPO}"
    echo "  ✓ ${secret} set"
  else
    echo "  ⏭  Skipped ${secret}"
  fi
done

# ---------------------------------------------------------------------------
# 3. Branch protection on main
# ---------------------------------------------------------------------------
echo ""
echo "--- Configuring branch protection for 'main'..."

gh api -X PUT "repos/${REPO}/branches/main/protection" \
  --input - <<'EOF'
{
  "required_status_checks": {
    "strict": true,
    "contexts": [
      "Build & Test",
      "Code Quality (SonarQube)"
    ]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": true
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF

echo "  ✓ Branch protection applied to main"

# ---------------------------------------------------------------------------
echo ""
echo "==> Setup complete for ${REPO}"
echo ""
echo "Remaining manual steps:"
echo "  1. Add reviewers to the 'production' environment"
echo "  2. Set up SonarQube project (sonar-project.properties is included)"
echo "  3. Create ECR repository:  aws ecr create-repository --repository-name cicd-demo-api"
echo "  4. Create ECS clusters, services, and ALB (see infra/ directory)"
echo "  5. Set up OIDC identity provider in AWS for GitHub Actions"
