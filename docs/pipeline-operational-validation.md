# Pipeline Operational Validation (Phase 4)

This runbook validates the SecDevOps supply-chain pipeline end-to-end without introducing new deployment infrastructure.

## Scope

Workflows covered:
- `ci.yml`
- `security.yml`
- `release-images.yml`
- `promote-images.yml`
- `rollback-images.yml`

Images covered:
- `mi-soar-policy-api`
- `mi-soar-edge-agent`

## Prerequisites

- GitHub repository secrets configured:
  - `DOCKERHUB_USERNAME`
  - `DOCKERHUB_TOKEN`
- GitHub Environments configured:
  - `dev`
  - `staging`
  - `prod` (with required reviewers)
- Optional repository variable for strict gate mode:
  - `SECURITY_GATE_BLOCK_HIGH=true` (blocks `HIGH,CRITICAL`)
- Local tools for manual verification:
  - `cosign`
  - `docker` (with buildx)
  - `gh` (optional, for workflow dispatch)

## Security Gate Policy

- Default policy: block on `CRITICAL`.
- Strict policy (`SECURITY_GATE_BLOCK_HIGH=true`): block on `HIGH,CRITICAL`.

The same severity policy is applied in:
- `security.yml`
- `release-images.yml`
- `promote-images.yml`
- `rollback-images.yml`

## Operational Checklist

1. Validate preconditions
2. Run release
3. Verify signature and identity
4. Verify SBOM attestation and identity
5. Promote to staging
6. (Optional) Promote to prod with approval
7. Run rollback test
8. Validate negative gate behavior
9. Archive run IDs and metadata artifacts

## 1) Run a Real Release

Trigger `release-images.yml` from `main` (push or `workflow_dispatch`).

Expected outputs per image:
- published digest
- SBOM artifact (`sbom-*.spdx.json`)
- release metadata artifact (`release-metadata-*.json`)
- workflow summary section

## 2) Verify Signature (cosign verify)

Use the published digest from release metadata.

```bash
cosign verify \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  --certificate-identity-regexp "^https://github.com/<org>/<repo>/.github/workflows/release-images.yml@.*$" \
  docker.io/<dockerhub_user>/mi-soar-policy-api@sha256:<digest>
```

Repeat for `mi-soar-edge-agent`.

## 3) Verify SBOM Attestation (cosign verify-attestation)

```bash
cosign verify-attestation \
  --type spdxjson \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  --certificate-identity-regexp "^https://github.com/<org>/<repo>/.github/workflows/release-images.yml@.*$" \
  docker.io/<dockerhub_user>/mi-soar-policy-api@sha256:<digest>
```

Expected: attestation present and identity verified.

## 4) Promote to Staging

Trigger `promote-images.yml` with:
- `source_tag=dev` (or `sha-...`)
- `target_environment=staging`
- `sign_images=true`

Pre-promotion verification done by workflow:
- source tag resolves to digest
- source signature identity verifies
- source SBOM attestation verifies
- vulnerability gate passes

Expected outputs:
- `staging` tag updated
- promote metadata artifact (`promote-metadata-*.json`)
- workflow summary section

## 5) Promote to Prod

Trigger `promote-images.yml` with:
- `target_environment=prod`
- optional `promote_latest=true`

Expected:
- GitHub Environment `prod` approval is required before execution
- same verify-before-promote controls as staging

## 6) Rollback Manual Test

Trigger `rollback-images.yml` with:
- `target_environment=staging` (or `prod`)
- either `source_tag` or `source_digest`
- `sign_images=true`

Pre-rollback verification done by workflow:
- source exists
- source signature identity verifies
- source SBOM attestation verifies
- vulnerability gate passes

Expected outputs:
- target environment tag rewired to source digest
- rollback metadata artifact (`rollback-metadata-*.json`)
- workflow summary section

## 7) Gate Failure Validation (Negative Test)

Suggested safe procedure:
1. Temporarily set `SECURITY_GATE_BLOCK_HIGH=true`.
2. Trigger release or promote against a known image/tag with HIGH vulnerabilities.
3. Confirm workflow fails at Trivy gate step.
4. Confirm no promotion/rollback mutation happened.
5. Restore variable value.

## 8) Troubleshooting

- `Could not resolve digest for source tag`:
  - source tag does not exist in Docker Hub
- `Source signature identity verification failed`:
  - signature missing or identity regex mismatch
- `Source SBOM attestation verification failed`:
  - attestation missing or wrong issuer/identity
- Trivy gate failure:
  - vulnerabilities above policy threshold; review severity policy and image contents

## 9) Future Deploy Phase Preparation

When deployment is introduced later, reuse the same model:
1. verify image digest/signature/attestation
2. deploy by digest (not floating tag)
3. run post-deploy smoke tests
4. gate prod promotion with manual approval
5. keep rollback by digest as first-class operation
