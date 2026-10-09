# Lab 3

## Credentials

A real AWS account would use OIDC: GitHub's token issuer is registered as an
identity provider, and an IAM role trusts it, scoped to this repository.
Each run GitHub mints a short-lived signed token that the runner trades with
STS, so nothing is stored long-term and there is no secret to leak or rotate.

This course cannot build that in AWS Academy because the lab role denies
iam:CreateOpenIDConnectProvider and iam:CreateRole, so instead it uses
session-scoped credentials from Vocareum, pushed into GitHub Actions secrets
by refresh-gha-creds.sh. The protection here is not secrecy but time: these
credentials expire when the lab session ends, which limits the damage if they
leak — they go stale within hours regardless.
