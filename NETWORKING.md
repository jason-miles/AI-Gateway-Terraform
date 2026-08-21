# Networking, multi-region & data residency

How to run the AI Gateway securely at enterprise scale, and how the Terraform here supports it.

## 1 · The traffic paths to reason about
An AI Gateway request has up to three network hops, each governed differently:

1. **Client → Databricks endpoint** (`/serving-endpoints/<name>/invocations`). Secured by the
   workspace's existing network controls — **Private Link / private connectivity**, IP access lists,
   and Unity Catalog identity. No new surface: it's the same front door as the rest of Databricks.
2. **Gateway → external provider** (OpenAI, Anthropic, …). This egresses to the provider's public API.
   Route it through your **stable egress** (NAT gateway / firewall / secure egress) so provider
   allow-lists and DLP see a known source. For zero public egress, prefer **Databricks-hosted
   foundation models** (a `databricks` served entity) or a provider reachable over private networking.
3. **Gateway → Unity Catalog** (usage + inference tables). Stays inside your account/region.

## 2 · Private Link / private connectivity
- **Front-door privacy:** enable Private Link (AWS PrivateLink / Azure Private Link / GCP PSC) on the
  workspace so `…/invocations` is reachable only over the private network. This is workspace-level
  configuration (network config / NCC), not a serving-endpoint setting — do it once per workspace and
  every gateway endpoint inherits it.
- **Egress control:** external-model calls leave the workspace's data plane. Pin egress to a controlled
  NAT/firewall and allow-list only the provider domains you use. Log egress for audit.
- **Keep data in-plane:** to avoid third-party egress entirely, serve **Databricks-hosted** models
  through the gateway (still governed identically) and reserve external providers for BAA'd/approved use.

## 3 · Multi-region & data residency (POPIA / GDPR)
Serving endpoints are **regional** (they live in a workspace, which lives in a region). For residency:

- **One workspace per region**, and deploy an **identical governed endpoint** into each — see
  `examples/multi-region/`. Terraform expresses this with **aliased providers**
  (`provider "databricks" { alias = "region_a" }`) and `providers = { databricks = databricks.region_a }`
  on each module instance, so one definition yields consistent governance in every region.
- **Route apps to their in-region URL** so a region's prompts/responses (and the inference logs) never
  leave that region. Inference tables land in that region's Unity Catalog.
- **Consistency at scale:** because every region uses the same module, guardrails / rate limits /
  logging are provably identical — no drift between regions.

## 4 · Account-level governance (the endgame)
The roadmap **account-level central gateway** governs all workspaces from one control plane. Until then,
this Terraform gives you the equivalent: a single repo, one module, `for_each` over endpoints, and the
aliased-provider pattern for regions — reviewed via PR, enforced via CI (`../.github/workflows`).

## 5 · Checklist for a regulated rollout
- [ ] Private Link enabled on each workspace; `…/invocations` not public.
- [ ] Controlled egress + provider domain allow-list; egress logged.
- [ ] One workspace/endpoint per residency region; apps use in-region URLs.
- [ ] Inference tables + usage stay in-region; retention set on the UC tables.
- [ ] Guardrails identical across regions (same module) — verify via `terraform plan` diff.
- [ ] Provider keys in per-region secret scopes; rotation runbook in place.
