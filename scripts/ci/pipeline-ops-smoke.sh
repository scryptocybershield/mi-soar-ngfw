#!/usr/bin/env bash
set -euo pipefail

# Non-destructive helper: validates local prerequisites and prints
# the exact verification commands for a release digest.

if [[ $# -lt 3 ]]; then
  cat <<'USAGE'
Usage:
  scripts/ci/pipeline-ops-smoke.sh <dockerhub_user> <repo_slug> <image@digest>

Example:
  scripts/ci/pipeline-ops-smoke.sh scryptocybershield scryptocybershield/mi-soar-ngfw \
    docker.io/scryptocybershield/mi-soar-policy-api@sha256:abcd...
USAGE
  exit 1
fi

DOCKERHUB_USER="$1"
REPO_SLUG="$2"
IMAGE_DIGEST_REF="$3"

for bin in cosign docker; do
  command -v "$bin" >/dev/null || {
    echo "Missing required binary: $bin" >&2
    exit 1
  }
done

echo "[ok] tools detected: cosign, docker"
echo "[info] verifying image existence: $IMAGE_DIGEST_REF"
docker buildx imagetools inspect "$IMAGE_DIGEST_REF" >/dev/null

echo
echo "Run these verification commands:"
cat <<EOF

cosign verify \\
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \\
  --certificate-identity-regexp "^https://github.com/${REPO_SLUG}/.github/workflows/release-images.yml@.*$" \\
  ${IMAGE_DIGEST_REF}

cosign verify-attestation \\
  --type spdxjson \\
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \\
  --certificate-identity-regexp "^https://github.com/${REPO_SLUG}/.github/workflows/release-images.yml@.*$" \\
  ${IMAGE_DIGEST_REF}
EOF

echo
echo "[next] use GitHub Actions workflow_dispatch for promote/rollback with validated source tags or digests"
