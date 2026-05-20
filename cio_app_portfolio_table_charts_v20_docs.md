# cio_app_portfolio_table_charts_v20.xsl

## Overview
Renders the **Application Atlas** — a filterable, sortable table of all applications in the portfolio. Intended as the primary portfolio browse view; each app row links through to the Application Summary view (v7).

## Parameters
| Parameter | Description |
|---|---|
| `param1` | Reserved (not used by this view) |
| `viewScopeTermIds` | Declared and parsed by the Essential Project platform but not applied in this view — no effect |

## Data sources

**API calls (client-side, fetched on page load):**
| API handle | Purpose |
|---|---|
| `busCapAppMartApps` | Primary application list — names, attributes, filter metadata |
| `orgSummary` | Organisation relationships (business units, people, ITSP units) |

**Server-side (computed at XSL render time from the knowledge base XML):**
| Data | Source instances |
|---|---|
| Data Sensitivity | `al_security_classifications` slot → `Security_Classification` instances |
| Supplier | `ap_supplier` slot → `Supplier` instances |
| Annual Cost | `Cost` and cost component instances — see [Annual Cost computation](#annual-cost-computation) |

## Annual Cost computation
The cost total for each application is built server-side as follows:

1. Find all `Cost` instances whose `costs_for_element` **or** `cost_for_elements` slot references the application. Both slot names are checked because deployments vary on the spelling.
2. Resolve each `Cost`'s `cost_components` slot to its component instances — typically `Annual_Cost_Component` or `Adhoc_Cost_Component`. Components are matched by ID, so any cost-component subtype is included automatically (one-off adhoc charges count toward the total alongside annual ones).
3. Keep only components that are current as of the render date (date logic below).
4. Sum `cc_cost_amount` across the surviving components, counting **positive values only** — negative amounts (e.g. credits) are excluded.

The currency symbol comes from the `Default Currency` Report_Constant, defaulting to `$` if unset.

Date logic per component (`cc_cost_start_date_iso_8601` / `cc_cost_end_date_iso_8601`):

| Start date | End date | Included if |
|---|---|---|
| Absent | Absent | Always |
| Present | Absent | Start ≤ today |
| Absent | Present | (End − 5 years) ≤ today ≤ End |
| Present | Present | Start ≤ today ≤ End |

Dates must be valid ISO 8601 (`YYYY-MM-DD`) to be recognised; blank or malformed values are treated as absent.

## Columns
All columns can be toggled via the column-chooser menu.

| Column | Slot(s) | Source | Notes |
|---|---|---|---|
| Name | `name` | API | Links to `cio_app_provider_summary_v8.xsl` |
| Description | `ap_description` | API | |
| Business Unit | `sA2R` — list of Actor-to-Role assignment IDs on the application (`busCapAppMartApps`), resolved against `orgSummary.a2rs` (each record: `id`, `actor` name, `type`, `role`). Business Units are `Group_Actor` entries whose role does not contain "ITSP". | API (`busCapAppMartApps` + `orgSummary`) | |
| Stakeholder (People) | `sA2R` — same resolution as above; People are `Individual_Actor` entries. | API (`busCapAppMartApps` + `orgSummary`) | |
| ITSP Unit | `sA2R` — same resolution as above; ITSP entries are `Group_Actor` entries whose role contains "ITSP". | API (`busCapAppMartApps` + `orgSummary`) | |
| Business Criticality | `ap_business_criticality` | API | Color-coded badge |
| Data Sensitivity | `al_security_classifications` → `Security_Classification` | Server-side XSL | Color-coded badge |
| SSO Protected | `inIList` / `outIList` — the application's inbound and outbound interface lists as returned by the `busCapAppMartApps` API; each entry is checked for the substrings `oauth2`, `saml2`, `pam`, or `entra` (case-insensitive). If any interface matches, the app is flagged as SSO-protected. | API | Yes/No badge |
| Lifecycle Status | `lifecycle_status_application_provider` | API | Color-coded badge |
| Integration Complexity | `Integration Complexity` | API | Color-coded badge |
| User Base | `User Base` | API | |
| User Population | `User Population` | API | |
| Supplier | `ap_supplier` → `Supplier` instances | Server-side XSL | |
| Annual Cost | See [Annual Cost computation](#annual-cost-computation) | Server-side XSL | |

## Filters
A universal free-text search box in the toolbar searches across all visible columns simultaneously. Below that, a collapsible per-column filter panel with a Reset button provides more targeted filtering. Input type varies by column:

| Column | Filter type |
|---|---|
| Name | Text |
| Description | Text |
| Business Unit | Text |
| People | Text |
| Supplier | Text |
| Annual Cost | Text |
| ITSP Unit | Dropdown |
| Business Criticality | Dropdown |
| Data Sensitivity | Dropdown |
| SSO Protected | Dropdown |
| Integration Complexity | Dropdown |
| User Base | Dropdown |
| User Population | Dropdown |
| Lifecycle Status | Multi-select checkbox group (default: all checked except Sunset / Retired) |

## Export
CSV export of all currently visible and filtered rows.

## Navigation
App name cells link to `cio_app_provider_summary_v8.xsl?PMA=<appId>`. `PMA` is the standard Essential Project platform convention for passing the subject instance ID to a report view; here it carries the `Application_Provider` or `Composite_Application_Provider` instance ID.

## Related files
| File | Relationship |
|---|---|
| `cio_app_provider_summary_v8.xsl` | Drill-through target from app name links |

