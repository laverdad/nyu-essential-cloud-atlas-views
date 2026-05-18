<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0"
    xpath-default-namespace="http://protege.stanford.edu/xml"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xalan="http://xml.apache.org/xslt"
    xmlns:pro="http://protege.stanford.edu/xml"
    xmlns:eas="http://www.enterprise-architecture.org/essential"
    xmlns:functx="http://www.functx.com"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:ess="http://www.enterprise-architecture.org/essential/errorview">

    <xsl:import href="../../common/core_js_functions.xsl"/>

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

    <xsl:template match="knowledge_base">
        <xsl:call-template name="docType"/>
        <html>
            <head>
                <xsl:call-template name="commonHeadContent"/>
                <xsl:call-template name="RenderModalReportContent">
                    <xsl:with-param name="essModalClassNames" select="$linkClasses"/>
                </xsl:call-template>

                <title>Applications Recovery Planning Register</title>

                <style>
                    .eas-tbl-wrapper {
                        padding: 20px;
                        max-width: 1500px;
                        margin: 80px auto 40px auto;
                        font-family: 'Open Sans', Helvetica, Arial, sans-serif;
                    }
                    .eas-tbl-header h2 {
                        margin: 0 0 4px 0;
                        font-size: 24px;
                        font-weight: 600;
                        color: #2c3e50;
                    }
                    .eas-tbl-subtitle { margin: 0 0 24px 0; color: #455a64; font-size: 14px; }

                    .eas-kpi-row { display: flex; gap: 16px; margin-bottom: 24px; flex-wrap: wrap; }
                    .eas-kpi-tile {
                        flex: 1; min-width: 180px; background: #fff;
                        border-radius: 8px; padding: 16px 20px; text-align: center;
                        box-shadow: 0 2px 8px rgba(0,0,0,0.08);
                    }
                    .eas-kpi-value { font-size: 32px; font-weight: 700; color: #2c3e50; line-height: 1; }
                    .eas-kpi-label { font-size: 12px; color: #455a64; margin-top: 6px; font-weight: 700; }

                    .eas-tbl-toolbar {
                        display: flex; justify-content: space-between; align-items: center;
                        margin-bottom: 14px; gap: 12px; flex-wrap: wrap;
                    }
                    .eas-tbl-search {
                        flex: 1; max-width: 360px; padding: 8px 12px;
                        border: 1px solid #ddd; border-radius: 6px; font-size: 14px; outline: none;
                    }
                    .eas-tbl-search:focus { border-color: #337ab7; box-shadow: 0 0 0 2px rgba(51,122,183,0.2); }
                    .eas-tbl-count { font-size: 13px; color: #455a64; white-space: nowrap; }
                    .eas-export-btn {
                        padding: 8px 16px; background: #337ab7; color: #fff;
                        border: none; border-radius: 6px; font-size: 13px; cursor: pointer;
                    }
                    .eas-export-btn:hover { background: #286090; }

                    .eas-tbl-card {
                        background: #fff; border-radius: 8px;
                        box-shadow: 0 2px 8px rgba(0,0,0,0.08); overflow-x: auto;
                    }
                    .eas-app-table { width: 100%; border-collapse: collapse; font-size: 13px; }
                    .eas-app-table thead th {
                        background: #2c3e50; color: #fff; padding: 11px 14px;
                        text-align: left; font-weight: 600; white-space: nowrap;
                        position: sticky; top: 0; z-index: 1; cursor: pointer; user-select: none;
                    }
                    .eas-app-table thead th:hover { background: #3d5166; }
                    .eas-app-table thead th .sort-icon { margin-left: 6px; opacity: 0.5; font-size: 11px; }
                    .eas-app-table tbody tr { border-bottom: 1px solid #f0f0f0; }
                    .eas-app-table tbody tr:hover { background: #f8fafc; }
                    .eas-app-table tbody td { padding: 9px 14px; vertical-align: middle; }
                    .eas-app-table tbody td.app-name a { color: #337ab7; text-decoration: none; font-weight: 500; }
                    .eas-app-table tbody td.app-name a:hover { text-decoration: underline; }
                    .eas-missing { color: #bdc3c7; font-style: italic; }

                    .eas-badge {
                        display: inline-block; padding: 3px 10px; border-radius: 12px;
                        font-size: 12px; font-weight: 600; color: #fff; white-space: nowrap;
                    }
                    .badge-crit-high   { background: #c62828; }
                    .badge-crit-medium { background: #9e6d00; }
                    .badge-crit-low    { background: #246d27; }
                    .badge-crit-none   { background: #777; }
                    .badge-lc-prod     { background: #246d27; }
                    .badge-lc-sunset   { background: #9e6d00; }
                    .badge-lc-retired  { background: #777; }
                    .badge-lc-other    { background: #1976d2; }

                    .eas-loading { text-align: center; padding: 60px; color: #455a64; font-size: 16px; }
                </style>

                <script type="text/javascript">
                    <xsl:call-template name="RenderViewerAPIJSFunction"/>

                    function safeStr(v) { return v == null ? '' : String(v).trim(); }
                    function esc(s) {
                        return String(s == null ? '' : s)
                            .replace(/&amp;/g, '&amp;amp;')
                            .replace(/"/g, '&amp;quot;')
                            .replace(/&lt;/g, '&amp;lt;')
                            .replace(/&gt;/g, '&amp;gt;');
                    }
                    function missing() { return '&lt;span class="eas-missing"&gt;&#8212;&lt;/span&gt;'; }

                    let busCapAppMartApps;

                    var viewModel = { applications: [], lookups: {} };
                    var sortCol = 'name';
                    var sortDir = 'asc';

                    $(document).ready(function () {
                        var apiList = ['busCapAppMartApps'];

                        async function executeFetchAndRender() {
                            try {
                                var responses = await fetchAndRenderData(apiList);
                                ({ busCapAppMartApps } = responses);
                                console.log('busCapAppMartApps loaded:',
                                    busCapAppMartApps &amp;&amp; busCapAppMartApps.applications
                                        ? busCapAppMartApps.applications.length : 0, 'applications');
                                buildViewModel();
                                renderView();
                            } catch (err) {
                                console.error('[Recovery Register] Error:', err);
                                document.getElementById('appTableBody').innerHTML =
                                    '&lt;tr&gt;&lt;td colspan="7" class="eas-loading"&gt;Error loading data. See console.&lt;/td&gt;&lt;/tr&gt;';
                            }
                        }

                        executeFetchAndRender();
                    });

                    function buildEnumLookup(filters) {
                        var lookup = {};
                        if (!filters) return lookup;
                        for (var i = 0; i &lt; filters.length; i++) {
                            var f = filters[i];
                            if (!f || !f.values) continue;
                            for (var j = 0; j &lt; f.values.length; j++) {
                                var v = f.values[j];
                                if (v &amp;&amp; v.id) {
                                    lookup[safeStr(v.id)] = v.enum_name || v.name || v.label || v.id;
                                }
                            }
                        }
                        return lookup;
                    }

                    function resolveIds(ids, lookup) {
                        if (!ids || !ids.length) return '';
                        var out = [];
                        for (var i = 0; i &lt; ids.length; i++) {
                            var id = safeStr(ids[i]);
                            if (!id) continue;
                            out.push(lookup[id] || id);
                        }
                        return out.join(', ');
                    }

                    function buildViewModel() {
                        var lookup = buildEnumLookup(busCapAppMartApps &amp;&amp; busCapAppMartApps.filters);
                        viewModel.lookups = lookup;

                        var apps = (busCapAppMartApps &amp;&amp; busCapAppMartApps.applications)
                            ? busCapAppMartApps.applications : [];

                        viewModel.applications = apps.map(function (app) {
                            var lcIds = app.lifecycle_status_application_provider || [];
                            var lcLabel = resolveIds(lcIds, lookup);
                            if (!lcLabel &amp;&amp; app.lifecycle) {
                                lcLabel = lookup[safeStr(app.lifecycle)] || '';
                            }

                            return {
                                id:           safeStr(app.id),
                                name:         app.name || 'Unnamed',
                                lifecycle:    lcLabel,
                                criticality:  resolveIds(app.ap_business_criticality || [], lookup),
                                rto:          resolveIds(app.ea_recovery_time_objective || [], lookup),
                                rpo:          resolveIds(app.ea_recovery_point_objective || [], lookup),
                                drModel:      resolveIds(app.ap_disaster_recovery_failover_model || [], lookup),
                                type:         safeStr(app.type || app.className)
                            };
                        });
                    }

                    function critBadge(val) {
                        if (!val) return '&lt;span class="eas-badge badge-crit-none"&gt;Not set&lt;/span&gt;';
                        var v = val.toLowerCase();
                        var cls = 'badge-crit-none';
                        if (v.indexOf('mission') &gt;= 0 || (v.indexOf('critical') &gt;= 0 &amp;&amp; v.indexOf('not') &lt; 0) || v.indexOf('high') &gt;= 0) {
                            cls = 'badge-crit-high';
                        } else if (v.indexOf('medium') &gt;= 0 || v.indexOf('moderate') &gt;= 0) {
                            cls = 'badge-crit-medium';
                        } else if (v.indexOf('low') &gt;= 0 || v.indexOf('not') &gt;= 0) {
                            cls = 'badge-crit-low';
                        }
                        return '&lt;span class="eas-badge ' + cls + '"&gt;' + esc(val) + '&lt;/span&gt;';
                    }

                    function lcBadge(val) {
                        if (!val) return '&lt;span class="eas-badge badge-lc-other"&gt;Unknown&lt;/span&gt;';
                        var v = val.toLowerCase();
                        var cls = 'badge-lc-other';
                        if (v.indexOf('production') &gt;= 0 || v.indexOf('active') &gt;= 0) cls = 'badge-lc-prod';
                        else if (v.indexOf('sunset') &gt;= 0) cls = 'badge-lc-sunset';
                        else if (v.indexOf('retired') &gt;= 0 || v.indexOf('decom') &gt;= 0) cls = 'badge-lc-retired';
                        return '&lt;span class="eas-badge ' + cls + '"&gt;' + esc(val) + '&lt;/span&gt;';
                    }

                    function sortApps(apps, col, dir) {
                        return apps.slice().sort(function (a, b) {
                            var av = (a[col] || '').toLowerCase();
                            var bv = (b[col] || '').toLowerCase();
                            if (av &lt; bv) return dir === 'asc' ? -1 : 1;
                            if (av &gt; bv) return dir === 'asc' ? 1 : -1;
                            return 0;
                        });
                    }

                    function filterApps(apps, term) {
                        if (!term || !term.trim()) return apps;
                        var t = term.toLowerCase();
                        return apps.filter(function (a) {
                            return (a.name || '').toLowerCase().indexOf(t) &gt;= 0
                                || (a.lifecycle || '').toLowerCase().indexOf(t) &gt;= 0
                                || (a.criticality || '').toLowerCase().indexOf(t) &gt;= 0
                                || (a.rto || '').toLowerCase().indexOf(t) &gt;= 0
                                || (a.rpo || '').toLowerCase().indexOf(t) &gt;= 0
                                || (a.drModel || '').toLowerCase().indexOf(t) &gt;= 0;
                        });
                    }

                    function renderKpiTiles(apps) {
                        var total = apps.length;
                        var withRto = apps.filter(function (a) { return !!a.rto; }).length;
                        var withRpo = apps.filter(function (a) { return !!a.rpo; }).length;
                        var withDr  = apps.filter(function (a) { return !!a.drModel; }).length;

                        document.getElementById('kpiTiles').innerHTML =
                            '&lt;div class="eas-kpi-row"&gt;' +
                                '&lt;div class="eas-kpi-tile" style="border-top:4px solid #1976d2"&gt;' +
                                    '&lt;div class="eas-kpi-value"&gt;' + total + '&lt;/div&gt;' +
                                    '&lt;div class="eas-kpi-label"&gt;Applications&lt;/div&gt;' +
                                '&lt;/div&gt;' +
                                '&lt;div class="eas-kpi-tile" style="border-top:4px solid #c62828"&gt;' +
                                    '&lt;div class="eas-kpi-value"&gt;' + withRto + '&lt;/div&gt;' +
                                    '&lt;div class="eas-kpi-label"&gt;With RTO&lt;/div&gt;' +
                                '&lt;/div&gt;' +
                                '&lt;div class="eas-kpi-tile" style="border-top:4px solid #9e6d00"&gt;' +
                                    '&lt;div class="eas-kpi-value"&gt;' + withRpo + '&lt;/div&gt;' +
                                    '&lt;div class="eas-kpi-label"&gt;With RPO&lt;/div&gt;' +
                                '&lt;/div&gt;' +
                                '&lt;div class="eas-kpi-tile" style="border-top:4px solid #246d27"&gt;' +
                                    '&lt;div class="eas-kpi-value"&gt;' + withDr + '&lt;/div&gt;' +
                                    '&lt;div class="eas-kpi-label"&gt;With DR / Failover&lt;/div&gt;' +
                                '&lt;/div&gt;' +
                            '&lt;/div&gt;';
                    }

                    function renderTable(apps) {
                        var term = document.getElementById('appSearch') ? document.getElementById('appSearch').value : '';
                        var filtered = filterApps(apps, term);
                        var sorted = sortApps(filtered, sortCol, sortDir);

                        renderKpiTiles(filtered);

                        var countEl = document.getElementById('rowCount');
                        if (countEl) {
                            countEl.textContent = 'Showing ' + sorted.length + ' of ' + viewModel.applications.length + ' applications';
                        }

                        var ths = document.querySelectorAll('.eas-app-table thead th[data-col]');
                        for (var ti = 0; ti &lt; ths.length; ti++) {
                            var th = ths[ti];
                            var icon = th.querySelector('.sort-icon');
                            if (th.getAttribute('data-col') === sortCol) {
                                if (icon) icon.className = 'sort-icon fa fa-sort-' + (sortDir === 'asc' ? 'asc' : 'desc');
                            } else {
                                if (icon) icon.className = 'sort-icon fa fa-sort';
                            }
                        }

                        var tbody = document.getElementById('appTableBody');
                        if (!tbody) return;

                        if (sorted.length === 0) {
                            tbody.innerHTML = '&lt;tr&gt;&lt;td colspan="7" class="eas-loading"&gt;No applications match.&lt;/td&gt;&lt;/tr&gt;';
                            return;
                        }

                        var rows = '';
                        for (var i = 0; i &lt; sorted.length; i++) {
                            var a = sorted[i];
                            var href = 'report?XML=reportXML.xml&amp;PMA=' + encodeURIComponent(a.id) + '&amp;cl=en-gb';
                            var linkCls = a.type === 'Composite_Application_Provider'
                                ? 'context-menu-compositeAppProviderGenMenu'
                                : 'context-menu-appProviderGenMenu';

                            rows +=
                                '&lt;tr&gt;' +
                                    '&lt;td class="app-name"&gt;&lt;a href="' + href + '" class="' + linkCls + '" id="' + esc(a.id) + '"&gt;' + esc(a.name) + '&lt;/a&gt;&lt;/td&gt;' +
                                    '&lt;td&gt;' + (a.lifecycle ? lcBadge(a.lifecycle) : missing()) + '&lt;/td&gt;' +
                                    '&lt;td&gt;' + critBadge(a.criticality) + '&lt;/td&gt;' +
                                    '&lt;td&gt;' + (a.rto ? esc(a.rto) : missing()) + '&lt;/td&gt;' +
                                    '&lt;td&gt;' + (a.rpo ? esc(a.rpo) : missing()) + '&lt;/td&gt;' +
                                    '&lt;td&gt;' + (a.drModel ? esc(a.drModel) : missing()) + '&lt;/td&gt;' +
                                '&lt;/tr&gt;';
                        }
                        tbody.innerHTML = rows;
                    }

                    function renderView() {
                        renderTable(viewModel.applications);
                        bindControls();
                    }

                    function bindControls() {
                        var search = document.getElementById('appSearch');
                        if (search) {
                            search.addEventListener('input', function () { renderTable(viewModel.applications); });
                        }

                        var ths = document.querySelectorAll('.eas-app-table thead th[data-col]');
                        for (var ti = 0; ti &lt; ths.length; ti++) {
                            ths[ti].addEventListener('click', function () {
                                var col = this.getAttribute('data-col');
                                if (sortCol === col) {
                                    sortDir = sortDir === 'asc' ? 'desc' : 'asc';
                                } else {
                                    sortCol = col;
                                    sortDir = 'asc';
                                }
                                renderTable(viewModel.applications);
                            });
                        }

                        var exp = document.getElementById('exportCsvBtn');
                        if (exp) exp.addEventListener('click', exportCsv);
                    }

                    function exportCsv() {
                        var term = document.getElementById('appSearch') ? document.getElementById('appSearch').value : '';
                        var sorted = sortApps(filterApps(viewModel.applications, term), sortCol, sortDir);
                        var headers = ['Application', 'Lifecycle', 'Business Criticality', 'RTO', 'RPO', 'DR / Failover Model'];
                        var rows = [headers];
                        for (var i = 0; i &lt; sorted.length; i++) {
                            var a = sorted[i];
                            rows.push([
                                '"' + (a.name || '').replace(/"/g, '""') + '"',
                                '"' + (a.lifecycle || '').replace(/"/g, '""') + '"',
                                '"' + (a.criticality || '').replace(/"/g, '""') + '"',
                                '"' + (a.rto || '').replace(/"/g, '""') + '"',
                                '"' + (a.rpo || '').replace(/"/g, '""') + '"',
                                '"' + (a.drModel || '').replace(/"/g, '""') + '"'
                            ]);
                        }
                        var csv = rows.map(function (r) { return r.join(','); }).join('\n');
                        var blob = new Blob([csv], { type: 'text/csv' });
                        var url = URL.createObjectURL(blob);
                        var a = document.createElement('a');
                        a.href = url;
                        a.download = 'applications_recovery_planning.csv';
                        a.click();
                        URL.revokeObjectURL(url);
                    }
                </script>
            </head>
            <body>
                <xsl:call-template name="Heading"/>

                <main class="eas-tbl-wrapper">
                    <div class="eas-tbl-header">
                        <h2>Applications Recovery Planning Register</h2>
                        <p class="eas-tbl-subtitle">
                            Recovery Time / Point Objectives and disaster-recovery posture for every application.
                        </p>
                    </div>

                    <section id="kpi-section">
                        <div id="kpiTiles">
                            <div class="eas-loading">
                                <i class="fa fa-spinner fa-pulse fa-2x"></i>&#160;Loading&#8230;
                            </div>
                        </div>
                    </section>

                    <div class="eas-tbl-toolbar">
                        <input id="appSearch" class="eas-tbl-search" type="text"
                               placeholder="Search applications, RTO, RPO, DR model&#8230;"/>
                        <span id="rowCount" class="eas-tbl-count"></span>
                        <button id="exportCsvBtn" class="eas-export-btn">
                            <i class="fa fa-download"></i>&#160;Export CSV
                        </button>
                    </div>

                    <div class="eas-tbl-card">
                        <table class="eas-app-table">
                            <thead>
                                <tr>
                                    <th data-col="name"        style="min-width:220px">Application <i class="sort-icon fa fa-sort"></i></th>
                                    <th data-col="lifecycle"   style="min-width:130px">Lifecycle <i class="sort-icon fa fa-sort"></i></th>
                                    <th data-col="criticality" style="min-width:140px">Business Criticality <i class="sort-icon fa fa-sort"></i></th>
                                    <th data-col="rto"         style="min-width:110px">RTO <i class="sort-icon fa fa-sort"></i></th>
                                    <th data-col="rpo"         style="min-width:110px">RPO <i class="sort-icon fa fa-sort"></i></th>
                                    <th data-col="drModel"     style="min-width:180px">DR / Failover Model <i class="sort-icon fa fa-sort"></i></th>
                                </tr>
                            </thead>
                            <tbody id="appTableBody">
                                <tr>
                                    <td colspan="6" class="eas-loading">
                                        <i class="fa fa-spinner fa-pulse"></i>&#160;Loading&#8230;
                                    </td>
                                </tr>
                            </tbody>
                        </table>
                    </div>
                </main>

                <xsl:call-template name="Footer"/>
            </body>
        </html>
    </xsl:template>
</xsl:stylesheet>
