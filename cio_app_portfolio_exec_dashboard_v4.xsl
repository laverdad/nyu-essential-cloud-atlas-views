<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0"
    xpath-default-namespace="http://protege.stanford.edu/xml"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xalan="http://xml.apache.org/xslt"
    xmlns:pro="http://protege.stanford.edu/xml"
    xmlns:eas="http://www.enterprise-architecture.org/essential"
    xmlns:functx="http://www.functx.com"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:ess="http://www.enterprise-architecture.org/essential/errorview"
    xmlns:jsesc="http://nyu.local/xsl/jsesc"
    exclude-result-prefixes="jsesc">

    <!-- IMPORT MUST COME FIRST -->
    <xsl:import href="../../common/core_js_functions.xsl"/>

    <!-- REQUIRED INCLUDES -->
    <xsl:include href="../../common/core_doctype.xsl"/>
    <xsl:include href="../../common/core_common_head_content.xsl"/>
    <xsl:include href="../../common/core_header.xsl"/>
    <xsl:include href="../../common/core_footer.xsl"/>
    <xsl:include href="../../common/core_external_doc_ref.xsl"/>
    <xsl:include href="../../common/core_api_fetcher.xsl"/>
    <xsl:include href="../../common/core_handlebars_functions.xsl"/>

    <xsl:output method="html" omit-xml-declaration="yes" indent="yes"/>
    <xsl:param name="param1"/>
    <xsl:param name="viewScopeTermIds"/>

    <xsl:variable name="viewScopeTerms" select="eas:get_scoping_terms_from_string($viewScopeTermIds)"/>
    <xsl:variable name="linkClasses" select="('Composite_Application_Provider', 'Application_Provider')"/>

    <!-- OWASP A03: escape arbitrary text for safe insertion into a JS double-quoted string literal -->
    <xsl:function name="jsesc:str" as="xs:string">
        <xsl:param name="s" as="xs:string?"/>
        <xsl:variable name="t" select="string($s)"/>
        <xsl:value-of select="replace(replace(replace(replace(replace($t,
            '\\', '\\\\'),
            '&quot;', '\\&quot;'),
            '&#10;', '\\n'),
            '&#13;', '\\r'),
            '/', '\\/')"/>
    </xsl:function>

    <xsl:template match="knowledge_base">
        <xsl:call-template name="docType"/>
        <!-- WCAG 3.1.1 (Level A): lang attribute identifies page language for assistive technologies -->
        <html lang="en">
            <head>
                <xsl:call-template name="commonHeadContent"/>
                <xsl:call-template name="RenderModalReportContent">
                    <xsl:with-param name="essModalClassNames" select="$linkClasses"/>
                </xsl:call-template>

                <title>Application Atlas &#8212; Risk KPI Dashboard</title>

                <style>
                    /* ── Layout ─────────────────────────────────────────── */
                    .eas-dash-wrapper {
                        padding: 20px;
                        max-width: 1400px;
                        margin: 10px auto 40px auto;
                        font-family: 'Open Sans', Helvetica, Arial, sans-serif;
                    }
                    .eas-dash-header { margin-bottom: 24px; }
                    .eas-dash-header h1 {
                        margin: 0 0 4px 0;
                        font-size: 24px;
                        font-weight: 600;
                        color: #2c3e50;
                    }
                    .eas-dash-subtitle { margin: 0; color: #455a64; font-size: 14px; }

                    /* ── KPI tiles ──────────────────────────────────────── */
                    .eas-kpi-row {
                        display: flex;
                        gap: 16px;
                        margin-bottom: 28px;
                        flex-wrap: wrap;
                    }
                    .eas-kpi-tile {
                        flex: 1;
                        min-width: 180px;
                        background: #ffffff;
                        border-radius: 8px;
                        padding: 20px 24px;
                        text-align: center;
                        box-shadow: 0 2px 8px rgba(0,0,0,0.08);
                    }
                    .eas-kpi-icon { font-size: 28px; margin-bottom: 8px; }
                    .eas-kpi-value { font-size: 40px; font-weight: 700; color: #2c3e50; line-height: 1; }
                    .eas-kpi-label { font-size: 13px; color: #455a64; margin-top: 6px; font-weight: 700; }

                    /* Pie chart for KPI tiles */
                    .eas-pie-chart {
                        width: 128px;
                        height: 128px;
                        border-radius: 50%;
                        display: inline-block;
                        margin-top: 4px;
                        margin-bottom: 12px;
                        box-shadow: 0 2px 6px rgba(0,0,0,0.15);
                        border: 2px solid #fff;
                    }

                    /* ── Section headings ───────────────────────────────── */
                    .eas-section-heading {
                        font-size: 13px;
                        font-weight: 700;
                        /* WCAG 1.4.3 (Level AA): #546e7a gives ~5.35:1 contrast on white, up from #607d8b (~4.33:1) */
                        color: #546e7a;
                        margin: 0 0 12px 0;
                        padding-bottom: 6px;
                        border-bottom: 2px solid #ecf0f1;
                        text-transform: uppercase;
                        letter-spacing: 0.07em;
                    }

                    /* ── Loading ────────────────────────────────────────── */
                    .eas-loading { text-align: center; padding: 60px; color: #455a64; font-size: 16px; }

                    /* WCAG 1.3.1 / 4.1.2: visually hide content while keeping it in the accessibility tree */
                    .eas-sr-only {
                        position: absolute;
                        width: 1px;
                        height: 1px;
                        padding: 0;
                        margin: -1px;
                        overflow: hidden;
                        clip: rect(0, 0, 0, 0);
                        white-space: nowrap;
                        border: 0;
                    }

                    /* ── ITSP Filter bar ────────────────────────────────── */
                    .eas-filter-bar {
                        display: flex;
                        align-items: center;
                        gap: 12px;
                        margin-bottom: 20px;
                        flex-wrap: wrap;
                    }
                    .eas-filter-label {
                        font-size: 13px;
                        font-weight: 700;
                        color: #455a64;
                        white-space: nowrap;
                        margin: 0;
                    }
                    .eas-filter-select {
                        padding: 7px 10px;
                        border: 1px solid #949494;
                        border-radius: 6px;
                        font-size: 13px;
                        color: #333;
                        background: #fff;
                        cursor: pointer;
                        outline: none;
                        min-width: 200px;
                    }
                    .eas-filter-select:focus { border-color: #337ab7; box-shadow: 0 0 0 2px rgba(51,122,183,0.2); }
                    .eas-filter-clear-btn {
                        padding: 7px 14px;
                        background: #f8fafc;
                        color: #455a64;
                        border: 1px solid #949494;
                        border-radius: 6px;
                        font-size: 12px;
                        font-weight: 600;
                        cursor: pointer;
                    }
                    .eas-filter-clear-btn:hover { background: #ecf0f1; color: #2c3e50; }
                    /* WCAG 1.4.3 (Level AA): #546e7a gives ~5.35:1 contrast on white */
                    .eas-filter-status { font-size: 12px; color: #546e7a; font-style: italic; }
                    /* WCAG 2.4.7: visible focus indicators */
                    .eas-filter-select:focus-visible,
                    .eas-filter-clear-btn:focus-visible {
                        outline: 3px solid #ffbf47;
                        outline-offset: 2px;
                    }
                </style>

                <script type="text/javascript">
                    <xsl:call-template name="RenderViewerAPIJSFunction"/>

                    /* ── Application Security Classifications Mapping ────── */
                    var appSecMapping = {
                        <xsl:for-each select="/node()/simple_instance[(type = 'Application_Provider' or type = 'Composite_Application_Provider') and own_slot_value[slot_reference='al_security_classifications']]">
                            "<xsl:value-of select="jsesc:str(name)"/>": [
                                <xsl:for-each select="own_slot_value[slot_reference='al_security_classifications']/value">
                                    "<xsl:value-of select="jsesc:str(.)"/>"<xsl:if test="position() != last()">,</xsl:if>
                                </xsl:for-each>
                            ]<xsl:if test="position() != last()">,</xsl:if>
                        </xsl:for-each>
                    };

                    /* ── Security Classifications Label Map ──────────────── */
                    var secClassLookup = {
                        <xsl:for-each select="/node()/simple_instance[type='Security_Classification']">
                            <xsl:variable name="rendered">
                                <xsl:call-template name="RenderMultiLangInstanceName">
                                    <xsl:with-param name="isForJSONAPI" select="true()"/>
                                    <xsl:with-param name="theSubjectInstance" select="."/>
                                </xsl:call-template>
                            </xsl:variable>
                            "<xsl:value-of select="jsesc:str(name)"/>": "<xsl:value-of select="jsesc:str(string($rendered))"/>"<xsl:if test="not(position() = last())">,</xsl:if>
                        </xsl:for-each>
                    };

                    /* ── Helpers ─────────────────────────────────────────── */
                    function safeStr(val) {
                        if (val == null) { return ''; }
                        return String(val).trim();
                    }

                    /* OWASP A03: Encode all HTML special chars before inserting into attribute or HTML context */
                    function escHtml(str) {
                        return String(str == null ? '' : str)
                            .replace(/&amp;/g, '&amp;amp;')
                            .replace(/[&lt;]/g, '&amp;lt;')
                            .replace(/[>]/g, '&amp;gt;')
                            .replace(/"/g, '&amp;quot;')
                            .replace(/'/g, '&amp;#39;');
                    }

                    function isCritical(app) {
                        var v = app.businessCriticality.toLowerCase();
                        return v.indexOf('mission') &gt;= 0 || (v.indexOf('critical') &gt;= 0 &amp;&amp; v.indexOf('not') &lt; 0);
                    }

                    /* ── API handles ─────────────────────────────────────── */
                    let busCapAppMartApps, orgSummary;

                    /* ── View model ──────────────────────────────────────── */
                    var viewModel = { applications: [] };
                    var activeApps = [];

                    /* ── Entry point ─────────────────────────────────────── */
                    $(document).ready(function () {
                        var apiList = ['busCapAppMartApps', 'orgSummary'];

                        async function executeFetchAndRender() {
                            try {
                                var responses = await fetchAndRenderData(apiList);
                                ({ busCapAppMartApps, orgSummary } = responses);
                                buildViewModel();
                                renderView();
                            } catch (err) {
                                console.error('[CIO Dashboard] Error loading data:', err);
                                /* WCAG 4.1.3 (Level AA): role="alert" ensures screen readers announce the error immediately */
                                document.getElementById('kpiSection').innerHTML =
                                    '&lt;div class="alert alert-danger" role="alert"&gt;' +
                                    '&lt;strong&gt;Error loading data.&lt;/strong&gt; Check the browser console.&lt;/div&gt;';
                            }
                        }

                        executeFetchAndRender();
                    });

                    /* ════════════════════════════════════════════════════════
                       BUILD VIEW MODEL  (identical logic to v4)
                    ════════════════════════════════════════════════════════ */
                    function buildViewModel() {

                        /* 1. A2R index: { a2rId -> { actor, type, role } } */
                        var a2rIndex = {};
                        if (orgSummary &amp;&amp; orgSummary.a2rs) {
                            orgSummary.a2rs.forEach(function (a2r) {
                                if (a2r.id) {
                                    a2rIndex[a2r.id.trim()] = {
                                        actor: a2r.actor || '',
                                        type:  a2r.type  || '',
                                        role:  a2r.role  || a2r.roleName || a2r.role_name || ''
                                    };
                                }
                            });
                        }

                        /* 2. Business criticality and lifecycle status indices */
                        var criticalityIndex = {};
                        var lifecycleIndex   = {};
                        if (busCapAppMartApps &amp;&amp; busCapAppMartApps.filters) {
                            var critFilter = null;
                            for (var fi = 0; fi &lt; busCapAppMartApps.filters.length; fi++) {
                                if (busCapAppMartApps.filters[fi].slotName === 'ap_business_criticality') {
                                    critFilter = busCapAppMartApps.filters[fi];
                                }
                                if (busCapAppMartApps.filters[fi].slotName === 'ap_lifecycle_status' ||
                                    busCapAppMartApps.filters[fi].slotName === 'lifecycle_status_application_provider') {
                                    if (busCapAppMartApps.filters[fi].values) {
                                        busCapAppMartApps.filters[fi].values.forEach(function (v) {
                                            if (v.id) { lifecycleIndex[v.id.trim()] = v.enum_name || v.name || 'Unknown'; }
                                        });
                                    }
                                }
                            }
                            if (critFilter &amp;&amp; critFilter.values) {
                                critFilter.values.forEach(function (v) {
                                    if (v.id) { criticalityIndex[v.id.trim()] = v.enum_name || v.name || 'Unknown'; }
                                });
                            }
                        }

                        /* 3. SSO-protected app ID set
                           Check inIList / outIList entry names for OAuth2, SAML2, PAM */
                        var SSO_TERMS = ['oauth2', 'saml2', 'pam'];
                        var ssoAppIds = {};
                        if (busCapAppMartApps &amp;&amp; busCapAppMartApps.applications) {
                            busCapAppMartApps.applications.forEach(function (app) {
                                var appId = safeStr(app.id);
                                var allIfaceEntries = (app.inIList || []).concat(app.outIList || []);
                                for (var ii = 0; ii &lt; allIfaceEntries.length; ii++) {
                                    var entry = allIfaceEntries[ii];
                                    var entryName = safeStr(entry &amp;&amp; typeof entry === 'object' ? entry.name : entry).toLowerCase();
                                    for (var ti = 0; ti &lt; SSO_TERMS.length; ti++) {
                                        if (entryName.indexOf(SSO_TERMS[ti]) &gt;= 0) {
                                            ssoAppIds[appId] = true;
                                            break;
                                        }
                                    }
                                    if (ssoAppIds[appId]) { break; }
                                }
                            });
                        }

                        /* 4. Map each application to normalised fields */
                        var apps = (busCapAppMartApps &amp;&amp; busCapAppMartApps.applications)
                            ? busCapAppMartApps.applications : [];

                        viewModel.applications = apps.map(function (app) {
                            var appId = (app.id || '').trim();

                            /* Stakeholders — ITSP role detection */
                            var sA2Rs     = app.sA2R || [];
                            var itspParts = [];
                            for (var si = 0; si &lt; sA2Rs.length; si++) {
                                var a2rEntry = a2rIndex[(sA2Rs[si] || '').trim()];
                                if (a2rEntry &amp;&amp; a2rEntry.actor &amp;&amp; a2rEntry.type === 'Group_Actor') {
                                    if (a2rEntry.role &amp;&amp; a2rEntry.role.indexOf('ITSP') &gt;= 0) {
                                        itspParts.push(a2rEntry.actor);
                                    }
                                }
                            }
                            var itspUnit = itspParts.length &gt; 0 ? itspParts.join(', ') : 'None';

                            /* Business criticality */
                            var critIds   = app.ap_business_criticality || [];
                            var firstCrit = critIds.length &gt; 0 ? critIds[0].trim() : null;
                            var businessCriticality = firstCrit
                                ? (criticalityIndex[firstCrit] || app.criticality || 'Unclassified')
                                : (app.criticality || 'Unclassified');

                            /* Lifecycle status */
                            var lifecycleStatus = 'Active';
                            var lcIds   = app.lifecycle_status_application_provider || app.ap_lifecycle_status || app.ap_disposition_lifecycle_status || [];
                            var lcLabel = lcIds.length &gt; 0 ? lifecycleIndex[lcIds[0]] : null;
                            if (!lcLabel &amp;&amp; app.lifecycle) { lcLabel = lifecycleIndex[app.lifecycle] || app.lifecycle; }
                            if (lcLabel) { lifecycleStatus = lcLabel; }

                            /* Data sensitivity from security classification */
                            var appSecClasses = appSecMapping[appId] || app.securityClassifications || [];
                            var dataSensitivity = 'Unclassified';
                            for (var ci = 0; ci &lt; appSecClasses.length; ci++) {
                                var classId     = safeStr(appSecClasses[ci]);
                                var classNameStr = secClassLookup[classId] || classId;
                                var cn          = classNameStr.toLowerCase();
                                if (cn.indexOf('high') &gt;= 0 || cn.indexOf('restricted') &gt;= 0 || cn.indexOf('confidential') &gt;= 0 || cn.indexOf('secret') &gt;= 0) {
                                    dataSensitivity = 'High'; break;
                                }
                                if (cn.indexOf('medium') &gt;= 0 || cn.indexOf('moderate') &gt;= 0) {
                                    dataSensitivity = 'Moderate'; break;
                                }
                                if (cn.indexOf('low') &gt;= 0 || cn.indexOf('public') &gt;= 0 || cn.indexOf('open') &gt;= 0) {
                                    dataSensitivity = 'Low'; break;
                                }
                            }

                            /* SSO */
                            var ssoProtected = ssoAppIds[appId] === true;

                            return {
                                id:                  appId,
                                name:                app.name || 'Unnamed Application',
                                businessCriticality: businessCriticality,
                                dataSensitivity:     dataSensitivity,
                                itspUnit:            itspUnit,
                                ssoProtected:        ssoProtected,
                                lifecycleStatus:     lifecycleStatus
                            };
                        });
                    }

                    /* ════════════════════════════════════════════════════════
                       RENDER
                    ════════════════════════════════════════════════════════ */
                    function renderView() {
                        activeApps = viewModel.applications.filter(function (a) {
                            var lc = a.lifecycleStatus ? String(a.lifecycleStatus).toLowerCase() : '';
                            return lc.indexOf('sunset') &lt; 0 &amp;&amp; lc.indexOf('retired') &lt; 0;
                        });
                        populateItspFilter();
                        applyItspFilter();

                        document.getElementById('filter-itsp').addEventListener('change', applyItspFilter);
                        document.getElementById('filter-clear-btn').addEventListener('click', function () {
                            document.getElementById('filter-itsp').value = '';
                            applyItspFilter();
                        });
                    }

                    /* ── Populate ITSP dropdown from live data ───────────── */
                    function populateItspFilter() {
                        var select = document.getElementById('filter-itsp');
                        if (!select) { return; }
                        var itspSet = {};
                        var hasNone = false;
                        activeApps.forEach(function (a) {
                            var val = a.itspUnit || '';
                            if (val === 'None' || val === '') { hasNone = true; return; }
                            val.split(',').forEach(function (part) {
                                var name = part.trim();
                                if (name) { itspSet[name] = true; }
                            });
                        });
                        var itspList = Object.keys(itspSet).sort(function (a, b) {
                            return a.toLowerCase().localeCompare(b.toLowerCase());
                        });
                        var frag = document.createDocumentFragment();
                        itspList.forEach(function (name) {
                            var opt = document.createElement('option');
                            opt.value = name;
                            opt.textContent = name;
                            frag.appendChild(opt);
                        });
                        if (hasNone) {
                            var noneOpt = document.createElement('option');
                            noneOpt.value = '__none__';
                            noneOpt.textContent = 'None (unassigned)';
                            frag.appendChild(noneOpt);
                        }
                        select.appendChild(frag);
                    }

                    /* ── Apply ITSP filter and re-render KPIs ────────────── */
                    function applyItspFilter() {
                        var filterVal = document.getElementById('filter-itsp').value;
                        var filtered;
                        if (!filterVal) {
                            filtered = activeApps;
                        } else if (filterVal === '__none__') {
                            filtered = activeApps.filter(function (a) {
                                return !a.itspUnit || a.itspUnit === 'None';
                            });
                        } else {
                            filtered = activeApps.filter(function (a) {
                                if (!a.itspUnit || a.itspUnit === 'None') { return false; }
                                return a.itspUnit.split(',').some(function (part) {
                                    return part.trim() === filterVal;
                                });
                            });
                        }
                        renderKpiTiles(filtered);
                        var statusEl = document.getElementById('filter-status');
                        if (statusEl) {
                            statusEl.textContent = filterVal
                                ? 'Showing ' + filtered.length + ' of ' + activeApps.length + ' applications'
                                : '';
                        }
                        var clearBtn = document.getElementById('filter-clear-btn');
                        if (clearBtn) { clearBtn.style.display = filterVal ? '' : 'none'; }
                    }

                    /* ── Pie segment builder ─────────────────────────────── */
                    /* WCAG 1.3.1 / 4.1.2: returns a `segments` array so the renderer can build a structured
                       (per-item) accessible name via aria-labelledby rather than a run-on aria-label. */
                    /* If a segment carries `n` (count), the legend, tooltip, and a11y list
                       all show "label: count (pct%)". Otherwise the count is omitted. */
                    function buildPie(segments) {
                        var grad = [], tt = [], subs = [];
                        var curDeg = 0;
                        var sep = segments.length &gt; 1 ? 0.8 : 0;
                        for (var i = 0; i &lt; segments.length; i++) {
                            var seg = segments[i];
                            var end = curDeg + seg.v;
                            grad.push(seg.c + ' ' + curDeg + '% ' + (end - sep) + '%');
                            if (sep &gt; 0) { grad.push('#fff ' + (end - sep) + '% ' + end + '%'); }
                            var pct = Math.round(seg.v);
                            var hasN = (typeof seg.n === 'number');
                            var amount = hasN ? (seg.n + ' (' + pct + '%)') : (pct + '%');
                            tt.push(seg.l + ': ' + amount);
                            subs.push('&lt;span style="white-space:nowrap"&gt;&lt;span style="color:' + (seg.c === '#757575' ? '#555' : seg.c) + ';font-weight:600"&gt;' + seg.s + ':&lt;/span&gt; ' + amount + '&lt;/span&gt;');
                            curDeg = end;
                        }
                        return {
                            gradient: grad.join(', '),
                            tooltip: tt.join(' | '),
                            subtitleHtml: subs.join(' | '),
                            segments: segments.map(function (s) {
                                var pct = Math.round(s.v);
                                return {
                                    label: s.l,
                                    percent: pct,
                                    count: (typeof s.n === 'number') ? s.n : null
                                };
                            })
                        };
                    }

                    /* Monotonic counter so each pie gets a unique id for aria-labelledby */
                    var __pieIdCounter = 0;

                    /* ── KPI tile HTML builder ───────────────────────────── */
                    /* WCAG 2.1.1 / 2.4.3: non-interactive elements (pies, value numerics) no longer carry tabindex.
                       WCAG 1.3.1 / 4.1.2: pies use aria-labelledby pointing to a visually-hidden &lt;ul&gt;
                       so screen reader users get a structured, navigable readout rather than a run-on label. */
                    function kpiTileHtml(color, icon, value, label, percentStr, multiPieObj, pctMeta) {
                        var valHtml;
                        if (multiPieObj !== undefined &amp;&amp; multiPieObj !== null) {
                            var pieId = 'eas-pie-desc-' + (++__pieIdCounter);
                            var listItems = (multiPieObj.segments || []).map(function (s) {
                                var amount = (s.count != null) ? (s.count + ' (' + s.percent + '%)') : (s.percent + '%');
                                return '&lt;li&gt;' + escHtml(s.label) + ': ' + amount + '&lt;/li&gt;';
                            }).join('');
                            var srList = '&lt;ul id="' + pieId + '" class="eas-sr-only"&gt;' + listItems + '&lt;/ul&gt;';
                            /* title= retained for sighted hover tooltip; aria-labelledby supplies the AT name */
                            var titleAttr = multiPieObj.tooltip
                                ? ' title="' + escHtml(multiPieObj.tooltip) + '"'
                                : '';
                            valHtml = srList +
                                '&lt;div class="eas-pie-chart" style="background: conic-gradient(' + multiPieObj.gradient + ');" role="img" aria-labelledby="' + pieId + '"' + titleAttr + '&gt;&lt;/div&gt;';
                            if (multiPieObj.subtitleHtml) {
                                /* aria-hidden: the same information is already exposed via aria-labelledby */
                                valHtml += '&lt;div aria-hidden="true" style="font-size:11px; color:#555; line-height:1.5; margin-bottom:8px;"&gt;' + multiPieObj.subtitleHtml + '&lt;/div&gt;';
                            }
                        } else if (percentStr !== undefined &amp;&amp; percentStr !== null) {
                            var p = parseFloat(percentStr);
                            var displayP = (p &gt; 0 &amp;&amp; p &lt; 2) ? 2 : p;
                            /* Single-percentage tile: when pctMeta {count, denom} is supplied,
                               render a colour-coded "count of denom (pct%)" subtitle in the
                               same visual rhythm as the multi-segment pies, and use the same
                               format for the accessible name and tooltip. */
                            var ariaText, subtitleHtml = '';
                            if (pctMeta &amp;&amp; typeof pctMeta.count === 'number' &amp;&amp; typeof pctMeta.denom === 'number') {
                                ariaText = label + ': ' + pctMeta.count + ' of ' + pctMeta.denom + ' (' + p + '%)';
                                subtitleHtml = '&lt;div aria-hidden="true" style="font-size:11px; color:#555; line-height:1.5; margin-bottom:8px;"&gt;' +
                                    '&lt;span style="white-space:nowrap"&gt;' +
                                    '&lt;span style="color:' + color + ';font-weight:600"&gt;' + pctMeta.count + '&lt;/span&gt;' +
                                    ' of ' + pctMeta.denom + ' (' + p + '%)' +
                                    '&lt;/span&gt;&lt;/div&gt;';
                            } else {
                                ariaText = p + '%';
                            }
                            valHtml = '&lt;div class="eas-pie-chart" style="background: conic-gradient(' + color + ' ' + displayP + '%, #ecf0f1 0);" role="img" aria-label="' + escHtml(ariaText) + '" title="' + escHtml(ariaText) + '"&gt;&lt;/div&gt;' + subtitleHtml;
                        } else {
                            valHtml = '&lt;div class="eas-kpi-value"&gt;' + escHtml(String(value)) + '&lt;/div&gt;';
                        }
                        return '&lt;div class="eas-kpi-tile" style="border-top:4px solid ' + color + '"&gt;' +
                               /* WCAG 1.1.1 (Level A): aria-hidden prevents screen readers from announcing meaningless icon class names */
                               '&lt;div class="eas-kpi-icon"&gt;&lt;i class="fa ' + icon + '" aria-hidden="true" style="color:' + color + '"&gt;&lt;/i&gt;&lt;/div&gt;' +
                               valHtml +
                               '&lt;div class="eas-kpi-label"&gt;' + label + '&lt;/div&gt;' +
                               '&lt;/div&gt;';
                    }

                    /* ── KPI tiles ─────────────────────────────────────────── */
                    function renderKpiTiles(apps) {
                        var total = apps.length;

                        /* ── Row 1 counts ── */
                        var critHigh    = apps.filter(function (a) { return isCritical(a); }).length;
                        var critLow     = apps.filter(function (a) { var v = a.businessCriticality.toLowerCase(); return v.indexOf('not') &gt;= 0 || v === 'low' || v === 'medium'; }).length;
                        var critUnclass = total - critHigh - critLow;

                        var sensHigh     = apps.filter(function (a) { return a.dataSensitivity === 'High'; }).length;
                        var sensModerate = apps.filter(function (a) { return a.dataSensitivity === 'Moderate'; }).length;
                        var sensLow      = apps.filter(function (a) { return a.dataSensitivity === 'Low'; }).length;
                        var sensUnclass  = apps.filter(function (a) { return a.dataSensitivity === 'Unclassified'; }).length;

                        var noItspCount      = apps.filter(function (a) { return a.itspUnit === 'None'; }).length;
                        var ssoProtectedCount = apps.filter(function (a) { return a.ssoProtected; }).length;

                        var noItspPercent = total &gt; 0 ? Math.round((noItspCount / total) * 100) : 0;
                        var ssoPercent    = total &gt; 0 ? Math.round((ssoProtectedCount / total) * 100) : 0;

                        /* Criticality pie */
                        var critPie = null;
                        if (total &gt; 0) {
                            var segs = [];
                            if (critHigh    &gt; 0) { segs.push({ c: '#c62828', v: (critHigh    / total) * 100, n: critHigh,    l: 'Critical',      s: 'Critical' }); }
                            if (critLow     &gt; 0) { segs.push({ c: '#246d27', v: (critLow     / total) * 100, n: critLow,     l: 'Not Critical',   s: 'Not Critical' }); }
                            if (critUnclass &gt; 0) { segs.push({ c: '#757575', v: (critUnclass / total) * 100, n: critUnclass, l: 'Unclassified',   s: 'Unclassified' }); }
                            critPie = buildPie(segs);
                        }

                        /* Data sensitivity pie */
                        var sensPie = null;
                        if (total &gt; 0) {
                            var segs = [];
                            if (sensHigh     &gt; 0) { segs.push({ c: '#c62828', v: (sensHigh     / total) * 100, n: sensHigh,     l: 'High',          s: 'High' }); }
                            if (sensModerate &gt; 0) { segs.push({ c: '#9e6d00', v: (sensModerate / total) * 100, n: sensModerate, l: 'Moderate',      s: 'Mod' }); }
                            if (sensLow      &gt; 0) { segs.push({ c: '#246d27', v: (sensLow      / total) * 100, n: sensLow,      l: 'Low',           s: 'Low' }); }
                            if (sensUnclass  &gt; 0) { segs.push({ c: '#757575', v: (sensUnclass  / total) * 100, n: sensUnclass,  l: 'Unclassified',  s: 'Unclassified' }); }
                            sensPie = buildPie(segs);
                        }

                        /* ── Row 2: security risk intersection counts ── */
                        var critNoItsp          = apps.filter(function (a) { return isCritical(a) &amp;&amp; a.itspUnit === 'None'; }).length;
                        var highSensNoItsp      = apps.filter(function (a) { return a.dataSensitivity === 'High' &amp;&amp; a.itspUnit === 'None'; }).length;
                        var critHighSensNoItsp  = apps.filter(function (a) { return isCritical(a) &amp;&amp; a.dataSensitivity === 'High' &amp;&amp; a.itspUnit === 'None'; }).length;
                        var noSsoNoItsp         = apps.filter(function (a) { return !a.ssoProtected &amp;&amp; a.itspUnit === 'None'; }).length;

                        var critHighSensNoItspNoSso = apps.filter(function (a) { return isCritical(a) &amp;&amp; a.dataSensitivity === 'High' &amp;&amp; a.itspUnit === 'None' &amp;&amp; !a.ssoProtected; }).length;

                        var critNoItspPct             = total &gt; 0 ? Math.round((critNoItsp             / total) * 100) : 0;
                        var highSensNoItspPct         = total &gt; 0 ? Math.round((highSensNoItsp         / total) * 100) : 0;
                        var critHighSensNoItspPct     = total &gt; 0 ? Math.round((critHighSensNoItsp     / total) * 100) : 0;
                        var noSsoNoItspPct            = total &gt; 0 ? Math.round((noSsoNoItsp            / total) * 100) : 0;
                        var critHighSensNoItspNoSsoPct = total &gt; 0 ? Math.round((critHighSensNoItspNoSso / total) * 100) : 0;

                        document.getElementById('kpiSection').innerHTML =

                            /* ── Row 1: Portfolio Overview ── */
                            '&lt;h3 class="eas-section-heading"&gt;Portfolio Overview&lt;/h3&gt;' +
                            '&lt;div class="eas-kpi-row"&gt;' +
                            kpiTileHtml('#1976d2', 'fa-th-large',   total,  'Total Applications') +
                            kpiTileHtml('#c62828', 'fa-pie-chart',  null,   'Business Criticality Breakdown',                            null, critPie) +
                            kpiTileHtml('#607d8b', 'fa-pie-chart',  null,   'Data Sensitivity Breakdown',                                null, sensPie) +
                            kpiTileHtml('#c62828', 'fa-user-times', null,   'No ITSP Assigned',   noItspPercent, null, { count: noItspCount,        denom: total }) +
                            kpiTileHtml('#246d27', 'fa-shield',     null,   'SSO Protected',      ssoPercent,    null, { count: ssoProtectedCount, denom: total }) +
                            '&lt;/div&gt;' +

                            /* ── Row 2: Security Risk Indicators ── */
                            '&lt;h3 class="eas-section-heading"&gt;Security Risk Indicators&lt;/h3&gt;' +
                            '&lt;div class="eas-kpi-row"&gt;' +
                            kpiTileHtml('#b71c1c', 'fa-exclamation-triangle', null,
                                'Critical, No ITSP',
                                critNoItspPct, null, { count: critNoItsp, denom: total }) +
                            kpiTileHtml('#b71c1c', 'fa-database', null,
                                'High Sensitivity, No ITSP',
                                highSensNoItspPct, null, { count: highSensNoItsp, denom: total }) +
                            kpiTileHtml('#b71c1c', 'fa-fire', null,
                                'Critical + High Sensitivity, No ITSP',
                                critHighSensNoItspPct, null, { count: critHighSensNoItsp, denom: total }) +
                            kpiTileHtml('#b71c1c', 'fa-unlock', null,
                                'No SSO + No ITSP',
                                noSsoNoItspPct, null, { count: noSsoNoItsp, denom: total }) +
                            kpiTileHtml('#b71c1c', 'fa-warning', null,
                                'Critical + High Sensitivity, No ITSP, No SSO',
                                critHighSensNoItspNoSsoPct, null, { count: critHighSensNoItspNoSso, denom: total }) +
                            '&lt;/div&gt;';
                    }
                </script>
            </head>
            <body>
                <xsl:call-template name="Heading"/>

                <main class="eas-dash-wrapper">

                    <!-- Page header -->
                    <div class="eas-dash-header">
                        <h1>Application Atlas &#8212; Risk KPI Dashboard</h1>
                        <p class="eas-dash-subtitle">
                            High-level KPIs and security risk indicators across the application portfolio.
                        </p>
                    </div>

                    <!-- ITSP filter bar -->
                    <div class="eas-filter-bar" role="search" aria-label="Filter by ITSP unit">
                        <label for="filter-itsp" class="eas-filter-label">
                            <i class="fa fa-filter" aria-hidden="true"></i>
                            ITSP Unit
                        </label>
                        <select id="filter-itsp" class="eas-filter-select">
                            <option value="">All ITSP Units</option>
                        </select>
                        <button id="filter-clear-btn" class="eas-filter-clear-btn" type="button" style="display:none" aria-label="Clear ITSP filter">
                            <i class="fa fa-times" aria-hidden="true"></i> Clear
                        </button>
                        <span id="filter-status" class="eas-filter-status" aria-live="polite" aria-atomic="true"></span>
                    </div>

                    <!-- WCAG 4.1.3 (Level AA): aria-live="polite" announces dynamically loaded KPI content to screen readers -->
                    <section id="kpiSection" aria-label="Key Performance Indicators" aria-live="polite">
                        <div class="eas-loading">
                            <!-- WCAG 1.1.1 (Level A): aria-hidden prevents screen reader from announcing decorative spinner icon -->
                            <i class="fa fa-spinner fa-pulse fa-2x" aria-hidden="true"></i>
                            &#160;Loading portfolio data&#8230;
                        </div>
                    </section>

                </main>

                <xsl:call-template name="Footer"/>
            </body>
        </html>
    </xsl:template>

</xsl:stylesheet>
