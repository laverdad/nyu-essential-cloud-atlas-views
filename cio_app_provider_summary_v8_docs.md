# cio_app_provider_summary_v8.xsl

## Overview
Renders the **Application Summary** — a single-app detail view showing ownership, security classification, usage profile, services provided, external references, and annual cost for one application. Accessed by clicking an app name in the Application Atlas (v20).

## Parameters
| Parameter | Description |
|---|---|
| `param1` | The application instance ID, passed via the `PMA` URL parameter — the standard EAS platform convention for identifying the subject `Application_Provider` or `Composite_Application_Provider` instance of a report. Used server-side for cost and reference-list resolution. |
| `viewScopeTermIds` | Declared and parsed by the EAS framework but not applied in this view — no effect |

## Data sources

**API calls (client-side, fetched on page load):**
| API handle | Purpose |
|---|---|
| `busCapAppMartApps` | Full application list — the target app is located within this by matching `PMA` |
| `orgSummary` | Organisation relationships (business units, people, ITSP units) |

**Server-side (computed at XSL render time from the knowledge base XML):**
| Data | Source instances |
|---|---|
| Data Sensitivity | `al_security_classifications` slot → `Security_Classification` instances |
| Supplier | `ap_supplier` slot → `Supplier` instances |
| Annual Cost | `Cost` and cost component instances scoped to `$param1`; currency symbol from the `Default Currency` Report_Constant |
| Purpose | `application_provider_purpose` slot → `Application_Provider_Purpose` instances (name shown) |
| Regulations | `ea_subject_to_regulations` slot → join instance → `regulated_component_regulation` slot → `Regulation` instances (name shown). The view drills past the join (whose own name is a composed display string) so only the plain regulation name is rendered. |
| Services Provided | `provides_application_services` slot → `Application_Service_Provision` instances → `implementing_application_service` slot → `Application_Service` instances (name shown). The view drills past the Provision (whose own name is a composed "App X as Service Y" display string) so only the plain service name is rendered. |
| External References | `external_reference_links` slot → `External_Reference` instances → `external_reference_url` slot. The URL is sanitised client-side: only `http://`, `https://`, `mailto:`, and protocol-relative `//` schemes are allowed in the `href`; bare values like `www.google.com` are auto-prefixed with `https://`; other schemes (`javascript:`, `data:`, `file:`, etc.) are rejected and the link is not rendered. The visible link label shows the URL exactly as entered. |

All four reference-list resolutions are scoped to `$param1`, so they touch only the instances directly linked from the current application.

Only cost components considered current as of the render date are included in the total. The date logic applied per component (`cc_cost_start_date_iso_8601` / `cc_cost_end_date_iso_8601`):

| Start date | End date | Included if |
|---|---|---|
| Absent | Absent | Always |
| Present | Absent | Start ≤ today |
| Absent | Present | (End − 5 years) ≤ today ≤ End |
| Present | Present | Start ≤ today ≤ End |

Only components with a positive `cc_cost_amount` are summed. Dates must be valid ISO 8601 (`YYYY-MM-DD`) to be recognised; blank or malformed values are treated as absent.

## Sections rendered

### Header card
Application name, lifecycle status badge, Purpose line (when present), and description.

| Field | Slot(s) | Source |
|---|---|---|
| Name | `name` | API |
| Lifecycle Status | `lifecycle_status_application_provider` | API |
| Purpose | `application_provider_purpose` → `Application_Provider_Purpose` instances | Server-side XSL |
| Description | `ap_description` | API |

### Hero tiles
At-a-glance summary badges displayed at the top of the page:

| Field | Slot(s) | Source |
|---|---|---|
| Business Criticality | `ap_business_criticality` | API |
| Data Sensitivity | `al_security_classifications` → `Security_Classification` | Server-side XSL |
| SSO Protected | `inIList` / `outIList` — the application's inbound and outbound interface lists as returned by the `busCapAppMartApps` API; each entry is checked for the substrings `oauth2`, `saml2`, `pam`, or `entra` (case-insensitive). If any interface matches, the app is flagged as SSO-protected. | API |
| Lifecycle Status | `lifecycle_status_application_provider` | API |
| Annual Cost | `costs_for_element` / `cost_for_elements` on `Cost`; `cc_cost_amount` on components | Server-side XSL |

### Ownership

| Field | Slot(s) | Source |
|---|---|---|
| Supplier | `ap_supplier` → `Supplier` instances | Server-side XSL |
| Business Units | `sA2R` — list of Actor-to-Role assignment IDs on the application (`busCapAppMartApps`), resolved against `orgSummary.a2rs` (each record: `id`, `actor` name, `type`, `role`). Business Units are `Group_Actor` entries whose role does not contain "ITSP". | API (`busCapAppMartApps` + `orgSummary`) |
| People | `sA2R` — same resolution as above; People are `Individual_Actor` entries. | API (`busCapAppMartApps` + `orgSummary`) |
| IT Service Provider (ITSP) | `sA2R` — same resolution as above; ITSP entries are `Group_Actor` entries whose role contains "ITSP". | API (`busCapAppMartApps` + `orgSummary`) |

### Security & Classification

| Field | Slot(s) | Source |
|---|---|---|
| Business Criticality | `ap_business_criticality` | API |
| Data Sensitivity | `al_security_classifications` → `Security_Classification` | Server-side XSL |
| Integration Complexity | `Integration Complexity` | API |
| Single Sign-On (SSO) | `inIList` / `outIList` — the application's inbound and outbound interface lists as returned by the `busCapAppMartApps` API; each entry is checked for the substrings `oauth2`, `saml2`, `pam`, or `entra` (case-insensitive). If any interface matches, the app is flagged as SSO-protected. | API |
| Subject to Regulations | `ea_subject_to_regulations` → join → `regulated_component_regulation` → `Regulation` (name) | Server-side XSL |

### Usage Profile

| Field | Slot(s) | Source |
|---|---|---|
| User Base | `User Base` | API |
| User Population | `User Population` | API |
| Annual Cost | `costs_for_element` / `cost_for_elements` on `Cost`; `cc_cost_amount` on components | Server-side XSL |

### Services Provided

| Field | Slot(s) | Source |
|---|---|---|
| Services Provided | `provides_application_services` → `Application_Service_Provision` → `implementing_application_service` → `Application_Service` (name) | Server-side XSL |

### External References
Clickable links open in a new tab with `rel="noopener noreferrer"`. Entries without a URL render as plain text.

| Field | Slot(s) | Source |
|---|---|---|
| External References | `external_reference_links` → `External_Reference` → `external_reference_url` (the URL itself is used as both `href` and visible label) | Server-side XSL |

## Navigation
- Back link returns to `cio_app_portfolio_table_charts_v20.xsl`
- The `PMA` URL parameter is the standard EAS platform convention for passing the subject instance ID to a report view; here it identifies the `Application_Provider` or `Composite_Application_Provider` being summarised
- Page `<title>` updates dynamically to `<App Name> — Application Summary`

## Related files
| File | Relationship |
|---|---|
| `cio_app_portfolio_table_charts_v20.xsl` | Parent view — back-link target and source of drill-through |
