# The default tool surface

Fifteen tools on the bare URL. Reads and writes never share a tool. Names and actions verified against the server code; the three `query_brand`, `query_surfaces` and `query_video_commissions` tools are the read halves split out of the former `manage_brand`, `manage_surfaces` and `video_commission` tools.

| Tool | Read or write | Actions | Notes |
|---|---|---|---|
| `get_platform_info` | read | `topic: health, organization, tool_profiles` | `organization` is the default and names the workspace |
| `query_campaigns` | read | `action: list, get, variants, deployments, generation_status, share_links, dooh_status, dooh_analytics, manifest` | `list` pages with `cursor`; `get` accepts `include: [variants, products, targeting, experiments, generatedContent]` |
| `manage_campaigns` | write | `action: create, update, delete, create_variant, update_variant, delete_variant, publish, deploy, update_deployment, duplicate, create_share_link, revoke_share_link, generate_playbook` | `deploy` takes exactly one of `surfaceId` or `zoneId`; `publish` accepts `visibility: public or private`; `create` is an empty shell with no playbook; `generate_playbook` writes the conversational playbook (opening message, product facts, FAQs, chips) for an existing campaign from its products and variants, and activation runs it when the campaign has none |
| `generate_campaign` | write, credits | `mode: start` (needs `intent`), `mode: regenerate` (needs `campaignId`, `fromStep`) | Async. Poll `query_campaigns` `generation_status` |
| `query_products` | read | `action: list, get, import_status` | |
| `manage_products` | write | `action: create, import_from_url, update, delete, import_csv` | `import_from_url` reaches the open web and runs paid inference |
| `query_surfaces` | read | `operation: list_surfaces, get_surface, list_zones` | |
| `manage_surfaces` | write | `operation: create_surface, create_zone` | Surface types: web, vending, retail, transit, stadium, mall, outdoor_billboard, indoor_display, point_of_sale, lobby, speaker, ar, other |
| `query_brand` | read | `action: get, get_page` | `get`: brand book, profile, voice, concierge. `get_page`: the brand host home page: live state (default render or an agent-authored page), every stored version with a signed preview URL, and the agent guide for writing one |
| `manage_brand` | write | `action: update_brandbook, update_profile, update_voice, update_concierge, create_page, publish_page, revert_page` | Writes merge per subtree; admin role required. `create_page` takes one complete HTML document (1 MiB max) for the brand host root and stores a draft with a preview URL (member role is enough for a draft); `publish: true` or `publish_page` with a `pageId` puts it live (admin); `revert_page` returns the host to the default render |
| `query_analytics` | read | `action: snapshot, ab_test, cvg_dashboard, insights, export` | `snapshot` `sections` default `["summary"]`; others: timeseries, funnel, cohorts, abTests, insights, products, breakdowns, spend (plan gated) |
| `query_video` | read | `action: templates, progress, renders` | `templates` with `templateId` expands one template's props schema |
| `render_video` | write, credits | `mode: video` (template + props), `mode: campaign` (campaignId, optional variantId), `mode: still` (one frame) | `quality: draft` and `mode: still` are the cheap iterations |
| `query_video_commissions` | read | `action: list, get` | Commission status: poll `get` until `proof_ready` or `delivered` |
| `video_commission` | write, credits, metered | `action: create, approve, revise, cancel` | `create` takes `briefMd`, `aspects`, `targetDurationS` (max 30), optional `tier: marquee or atelier` |

## The generate_campaign intent

```json
{
  "mode": "start",
  "intent": {
    "objective": "increase_sales | drive_traffic | build_awareness | promote_event",
    "products": [{ "id": "<uuid if known>", "query": "product name", "confidence": 0.9 }],
    "context": {
      "timeConstraints": [{ "dayParts": ["evening"], "daysOfWeek": ["friday", "saturday"] }],
      "locationConstraints": [{ "type": "city", "value": "Stockholm" }],
      "audienceSegments": [{ "type": "behavioral", "value": "weekend brunch regulars" }]
    },
    "urgency": "immediate | scheduled | ongoing",
    "expectedOutcome": "one sentence, measurable",
    "successMetrics": ["bookings", "CTR (sessions)"]
  },
  "options": {
    "brandGuidelines": { "voice": "", "tone": "", "messagingRules": "" },
    "includeImages": true,
    "variantCount": 3,
    "generateConversationPlaybook": true
  }
}
```

At least one product must resolve; list products first with `query_products` `action: list`.

## Resources and prompts

Resources: `mosaic://capabilities`, `mosaic://brand-page-guide` (how to author the brand home page: palette, live campaign ids, the relative embed and link paths the edge serves, the rules), `mosaic://org/{id}`, `mosaic://org/{id}/brand-guidelines`, `mosaic://campaigns/{id}`, `mosaic://products/{id}`, `mosaic://surfaces/{id}`.

Prompts: `campaign_brief` (goal, brandName, targetAudience, budget), `analytics_deep_dive`, `surface_network_planner`, `content_optimizer`, `ai_studio_image_workflow`, `platform_onboarding`.

## Roles

Viewer: reads only. Member: create, edit and publish campaigns, create products, surfaces and zones. Editor: member plus delete products and invitations. Admin: everything, including brand writes and workspace settings. A tool call outside the role returns `forbidden` with a remedy naming who can do it.
