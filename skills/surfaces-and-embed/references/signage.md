# Screens, kiosks and signage

## Concepts

- Surface: one screen or placement, registered in Dashboard > Network or with `manage_surfaces` `create_surface`. Types cover retail, vending, transit, stadium, mall, outdoor_billboard, indoor_display, point_of_sale, lobby, speaker, ar.
- Zone: a group of surfaces with one selection strategy. Assign a campaign to the zone and every surface updates together. Strategies: priority-only (highest priority deployment wins), round-robin, weighted, zone-coordinated.
- Deployment: campaign on a surface or zone with a priority (low, normal, high, critical) and a status (scheduled, active, paused, ended). `manage_campaigns` `action: update_deployment` changes the status.
- Publish pushes content to the edge network; screens load it from there.

## Recipe

1. `query_surfaces` `operation: list_surfaces` and `list_zones`. Reuse what exists.
2. For each new screen: `manage_surfaces` `operation: create_surface` with a name people will recognise ("Lobby left screen"), the type, and the address, city and ISO country for physical locations.
3. If more than one screen shows the same thing: `manage_surfaces` `operation: create_zone`, then deploy to the zone instead of each surface.
4. `manage_campaigns` `action: deploy` with `zoneId` or `surfaceId`, `priority`, `isActive: true`.
5. `manage_campaigns` `action: publish` if the campaign is not yet published.
6. Watch `query_analytics` `action: snapshot` for the first impressions. Screens reload, so Impressions run far ahead of Reach; compare creatives on CTR (sessions).

## Interactive vs passive screens

The device's capability decides what the screen shows, not its shape. A touch screen or a screen with a QR bridge gets the conversational Squid with chips; a passive display gets the creative without controls. The creative always carries over. Do not gate this on aspect ratio.

## Android TV

SparkleTree ships a signage app for Android TV. Install it on the device, pair it from the dashboard, and the paired device is a surface like any other. Content arrives on publish.

## QR handoff

A visitor mid-conversation with a Squid on a screen can scan and continue the same conversation on their phone. Campaign and surface QR scans are tracked as clicks tagged with campaign, surface and variant. The brand-page QR (Dashboard > Brand > Publishing) lands on the brand page, not a specific campaign.

## Copy for screens

Shorter headline, one-sentence body, a CTA that works without a click ("Scan for the menu"). Run `skills/review-variants` with the surface in mind.
