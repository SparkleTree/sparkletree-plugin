---
name: troubleshoot-connection
description: SparkleTree connection problems. Use when the SparkleTree MCP server answers 401, sign-in loops, the SparkleTree tools are missing from the session, calls hit 429, or a signed-in user has no workspace. Walks the OAuth sign-in, re-authentication, the new-conversation rule, the 120 requests per minute limit and where to get support.
---

# Troubleshoot the connection

Work down the list; stop at the first fix that holds. Do not retry a failing write in a loop.

## How connecting works

An unauthenticated call to `https://app.sparkletree.io/api/mcp` returns `401` with OAuth resource metadata. A spec-compliant client discovers the authorization server (Clerk), registers itself, opens a browser consent flow, and the human signs in with an existing SparkleTree account. No account can be created through the connection. Scopes are `mcp:read` and `mcp:write`; authorisation follows the workspace and the user's role, not the scopes.

## Symptoms and fixes

| Symptom | Cause | Fix |
|---|---|---|
| Tools are absent from the session | The host loaded before the server connected, or the connector was added mid-conversation | Start a new conversation. In Claude Code, `/mcp` shows the server state and offers authentication; `/reload-plugins` reloads plugin servers |
| `401` on the first call | Not signed in, token expired or revoked | Complete the browser sign-in. In Claude Code, `/mcp`, pick sparkletree, authenticate. Elsewhere, remove and re-add the connector |
| `401` mid-session | Token expired | Re-run the bootstrap (same as above). Spec-compliant clients recover on their own |
| Sign-in loop | A stale registration or cookie | Remove the connector, sign out of app.sparkletree.io in the browser, add the connector again |
| "connection failed" right after a successful sign-in | The signed-in user has no workspace | Create one at https://app.sparkletree.io/sign-up (workspaces are created in onboarding), then reconnect |
| `429` | 120 requests per minute per token | Back off exponentially; do not fan out polls |
| `forbidden` with a remedy | The user's role does not allow the action | Read the remedy; ask an admin or editor |
| `precondition_failed` or `entitlement_required` | Quota, credits or plan feature | Tell the user; the action is blocked until the plan or quota changes. Published campaigns keep serving |
| Tools present but the profile looks wrong | A `?profile=` value that is not a valid call code | Profile names are rejected; the connection falls back to the minimal profile. Use the bare URL or a real call code from the operator |
| Session-start message says SparkleTree did not answer | The health check at `https://app.sparkletree.io/api/health` failed or timed out (2 s) | Try a read tool; if it also fails, wait and retry, then write to support |

## Verify a fix

`get_platform_info` `topic: "health"` needs no workspace; `topic: "organization"` proves the workspace binding. Both are free.

## API keys

Headless clients send `x-api-key` instead of OAuth. A `401` with a key means it was disabled or mistyped; keys are managed under Settings > API keys by an admin.

## Support

support@sparkletree.io. Include the workspace name, the tool and action, the error code and the time. Never include the token or key. Documentation: https://docs.sparkletree.io/developers/agents/ and the connector setup page linked from there.
