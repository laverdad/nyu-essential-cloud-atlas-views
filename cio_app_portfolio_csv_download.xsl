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

    <xsl:template match="knowledge_base">
        <xsl:call-template name="docType"/>
        <html>
            <head>
                <xsl:call-template name="commonHeadContent"/>
                <xsl:call-template name="RenderModalReportContent">
                    <xsl:with-param name="essModalClassNames" select="$linkClasses"/>
                </xsl:call-template>

                <title>Application Portfolio — CSV Export</title>

                <style>
                    .eas-export-wrapper {
                        max-width: 640px;
                        margin: 100px auto 40px auto;
                        font-family: 'Open Sans', Helvetica, Arial, sans-serif;
                        text-align: center;
                        padding: 40px;
                        background: #fff;
                        border-radius: 10px;
                        box-shadow: 0 2px 12px rgba(0,0,0,0.09);
                    }
                    .eas-export-icon { font-size: 48px; color: #337ab7; margin-bottom: 16px; }
                    .eas-export-wrapper h2 { font-size: 22px; font-weight: 600; color: #2c3e50; margin: 0 0 10px 0; }
                    .eas-export-wrapper p  { font-size: 14px; color: #455a64; margin: 0 0 8px 0; line-height: 1.6; }
                    .eas-export-wrapper ul {
                        text-align: left;
                        display: inline-block;
                        margin: 12px 0 20px 0;
                        padding: 0;
                        list-style: none;
                        font-size: 13px;
                        color: #455a64;
                    }
                    .eas-export-wrapper ul li::before { content: "✓ "; color: #337ab7; font-weight: 700; }
                    #statusMsg { font-size: 14px; font-weight: 600; margin-top: 20px; }
                    #statusMsg.loading { color: #337ab7; }
                    #statusMsg.done    { color: #2e7d32; }
                    #statusMsg.error   { color: #c62828; }
                    .eas-retry-btn {
                        display: none;
                        margin-top: 16px;
                        padding: 9px 20px;
                        background: #337ab7;
                        color: #fff;
                        border: none;
                        border-radius: 6px;
                        font-size: 14px;
                        cursor: pointer;
                    }
                    .eas-retry-btn:hover { background: #286090; }
                </style>

                <!-- v2.0 PATTERN: template call first, then XML-encoded JS -->
                <script type="text/javascript">
                    <xsl:call-template name="RenderViewerAPIJSFunction"/>

                    /* ── Application Security Classifications Mapping ────── */
                    var appSecMapping = {
                        <xsl:for-each select="/node()/simple_instance[(type = 'Application_Provider' or type = 'Composite_Application_Provider') and own_slot_value[slot_reference='al_security_classifications']]">
                            "<xsl:value-of select="name"/>": [
                                <xsl:for-each select="own_slot_value[slot_reference='al_security_classifications']/value">
                                    "<xsl:value-of select="."/>"<xsl:if test="position() != last()">,</xsl:if>
                                </xsl:for-each>
                            ]<xsl:if test="position() != last()">,</xsl:if>
                        </xsl:for-each>
                    };

                    /* ── Security Classifications Map ────────────────────── */
                    var secClassLookup = {
                        <xsl:for-each select="/node()/simple_instance[type='Security_Classification']">
                            "<xsl:value-of select="name"/>": "<xsl:call-template name="RenderMultiLangInstanceName"><xsl:with-param name="isForJSONAPI" select="true()"/><xsl:with-param name="theSubjectInstance" select="."/></xsl:call-template>"<xsl:if test="not(position() = last())">,</xsl:if>
                        </xsl:for-each>
                    };

                    /* ── Helpers ─────────────────────────────────────────── */
                    function safeStr(val) {
                        if (val == null) { return ''; }
                        return String(val).trim();
                    }

                    function setStatus(msg, cls) {
                        var el = document.getElementById('statusMsg');
                        if (!el) { return; }
                        el.textContent = msg;
                        el.className = cls || '';
                    }

                    /* ── API handles ─────────────────────────────────────── */
                    let busCapAppMartApps, orgSummary;

                    /* ── View model ──────────────────────────────────────── */
                    var viewModel = { applications: [] };

                    /* ── Entry point ─────────────────────────────────────── */
                    $(document).ready(function () {
                        var apiList = ['busCapAppMartApps', 'orgSummary'];

                        async function executeFetchAndRender() {
                            try {
                                setStatus('Loading portfolio data\u2026', 'loading');
                                var responses = await fetchAndRenderData(apiList);
                                ({ busCapAppMartApps, orgSummary } = responses);
                                buildViewModel();
                                exportCsv();
                                setStatus('\u2713 Download started. Your CSV file is ready.', 'done');
                                document.getElementById('retryBtn').style.display = 'inline-block';
                            } catch (err) {
                                console.error('[CSV Export] Error:', err);
                                setStatus('Error loading data. Check the browser console for details.', 'error');
                                document.getElementById('retryBtn').style.display = 'inline-block';
                            }
                        }

                        document.getElementById('retryBtn').addEventListener('click', function () {
                            document.getElementById('retryBtn').style.display = 'none';
                            executeFetchAndRender();
                        });

                        executeFetchAndRender();
                    });

                    /* ════════════════════════════════════════════════════════
                       BUILD VIEW MODEL
                    ════════════════════════════════════════════════════════ */
                    function buildViewModel() {

                        /* 1. A2R index */
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

                        /* 2. Criticality and lifecycle indices */
                        var criticalityIndex = {};
                        var lifecycleIndex = {};
                        if (busCapAppMartApps &amp;&amp; busCapAppMartApps.filters) {
                            var critFilter = null;
                            for (var fi = 0; fi &lt; busCapAppMartApps.filters.length; fi++) {
                                if (busCapAppMartApps.filters[fi].slotName === 'ap_business_criticality') {
                                    critFilter = busCapAppMartApps.filters[fi];
                                }
                                if (busCapAppMartApps.filters[fi].slotName === 'ap_lifecycle_status' || busCapAppMartApps.filters[fi].slotName === 'lifecycle_status_application_provider') {
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

                        /* 3. SSO-protected app ID set */
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
                                        if (entryName.indexOf(SSO_TERMS[ti]) &gt;= 0) { ssoAppIds[appId] = true; break; }
                                    }
                                    if (ssoAppIds[appId]) { break; }
                                }
                            });
                        }

                        /* 4. Map each application */
                        var apps = (busCapAppMartApps &amp;&amp; busCapAppMartApps.applications)
                            ? busCapAppMartApps.applications : [];

                        viewModel.applications = apps.map(function (app) {
                            var appId = (app.id || '').trim();

                            var sA2Rs = app.sA2R || [];
                            var buParts = [], itspParts = [], personParts = [];
                            for (var si = 0; si &lt; sA2Rs.length; si++) {
                                var a2rEntry = a2rIndex[(sA2Rs[si] || '').trim()];
                                if (a2rEntry &amp;&amp; a2rEntry.actor) {
                                    var label = a2rEntry.actor;
                                    if (a2rEntry.role) { label += ' (' + a2rEntry.role + ')'; }
                                    if (a2rEntry.type === 'Group_Actor') {
                                        buParts.push(label);
                                        if (a2rEntry.role &amp;&amp; a2rEntry.role.indexOf('ITSP') &gt;= 0) { itspParts.push(a2rEntry.actor); }
                                    } else if (a2rEntry.type === 'Individual_Actor') {
                                        personParts.push(label);
                                    }
                                }
                            }

                            var critIds   = app.ap_business_criticality || [];
                            var firstCrit = critIds.length &gt; 0 ? critIds[0].trim() : null;
                            var businessCriticality = firstCrit
                                ? (criticalityIndex[firstCrit] || app.criticality || 'Unclassified')
                                : (app.criticality || 'Unclassified');

                            var lifecycleStatus = 'Active';
                            var lcIds = app.lifecycle_status_application_provider || app.ap_lifecycle_status || app.ap_disposition_lifecycle_status || [];
                            var lcLabel = lcIds.length &gt; 0 ? lifecycleIndex[lcIds[0]] : null;
                            if (!lcLabel &amp;&amp; app.lifecycle) { lcLabel = lifecycleIndex[app.lifecycle] || app.lifecycle; }
                            if (lcLabel) { lifecycleStatus = lcLabel; }

                            var appSecClasses = appSecMapping[appId] || app.securityClassifications || [];
                            var dataSensitivity = 'Unclassified';
                            for (var ci = 0; ci &lt; appSecClasses.length; ci++) {
                                var classId   = safeStr(appSecClasses[ci]);
                                var cn        = (secClassLookup[classId] || classId).toLowerCase();
                                if (cn.indexOf('high') &gt;= 0 || cn.indexOf('restricted') &gt;= 0 || cn.indexOf('confidential') &gt;= 0 || cn.indexOf('secret') &gt;= 0) { dataSensitivity = 'High'; break; }
                                if (cn.indexOf('medium') &gt;= 0 || cn.indexOf('moderate') &gt;= 0) { dataSensitivity = 'Moderate'; break; }
                                if (cn.indexOf('low') &gt;= 0 || cn.indexOf('public') &gt;= 0 || cn.indexOf('open') &gt;= 0) { dataSensitivity = 'Low'; break; }
                            }

                            return {
                                id:                  appId,
                                name:                app.name || 'Unnamed Application',
                                description:         safeStr(app.description || app.ap_description || ''),
                                businessUnit:        buParts.length    &gt; 0 ? buParts.join(', ')    : 'Unassigned',
                                stakeholderPeople:   personParts.length &gt; 0 ? personParts.join(', ') : 'None',
                                itspUnit:            itspParts.length  &gt; 0 ? itspParts.join(', ')  : 'None',
                                businessCriticality: businessCriticality,
                                dataSensitivity:     dataSensitivity,
                                ssoProtected:        ssoAppIds[appId] === true,
                                lifecycleStatus:     lifecycleStatus
                            };
                        });
                    }

                    /* ════════════════════════════════════════════════════════
                       CSV EXPORT — all applications, sorted by name
                    ════════════════════════════════════════════════════════ */
                    function exportCsv() {
                        var sorted = viewModel.applications.slice().sort(function (a, b) {
                            return a.name.toLowerCase() &lt; b.name.toLowerCase() ? -1 : a.name.toLowerCase() &gt; b.name.toLowerCase() ? 1 : 0;
                        });

                        var headers = ['Application Name', 'Description', 'Business Units', 'People', 'ITSP', 'Business Criticality', 'Data Sensitivity', 'SSO Protected', 'Lifecycle Status'];

                        var rows = [headers];
                        for (var i = 0; i &lt; sorted.length; i++) {
                            var a = sorted[i];
                            rows.push([
                                '"' + a.name.replace(/"/g, '""') + '"',
                                '"' + a.description.replace(/"/g, '""') + '"',
                                '"' + a.businessUnit.replace(/"/g, '""') + '"',
                                '"' + a.stakeholderPeople.replace(/"/g, '""') + '"',
                                '"' + a.itspUnit.replace(/"/g, '""') + '"',
                                '"' + a.businessCriticality.replace(/"/g, '""') + '"',
                                '"' + a.dataSensitivity.replace(/"/g, '""') + '"',
                                a.ssoProtected ? 'Yes' : 'No',
                                '"' + a.lifecycleStatus.replace(/"/g, '""') + '"'
                            ]);
                        }

                        var csv  = rows.map(function (r) { return r.join(','); }).join('\n');
                        var blob = new Blob([csv], { type: 'text/csv' });
                        var url  = URL.createObjectURL(blob);
                        var link = document.createElement('a');
                        link.href     = url;
                        link.download = 'application_portfolio.csv';
                        link.click();
                        URL.revokeObjectURL(url);
                    }
                </script>
            </head>
            <body>
                <xsl:call-template name="Heading"/>

                <main style="padding: 40px 20px;">
                    <div class="eas-export-wrapper">
                        <div class="eas-export-icon"><i class="fa fa-file-text-o"></i></div>
                        <h2>Application Portfolio — CSV Export</h2>
                        <p>
                            This page automatically downloads a CSV file containing the full
                            application portfolio register. No filters are applied — all
                            applications are included, sorted alphabetically by name.
                        </p>
                        <p>The CSV includes the following columns:</p>
                        <ul>
                            <li>Application Name</li>
                            <li>Description</li>
                            <li>Business Units</li>
                            <li>People (individual stakeholders)</li>
                            <li>ITSP (IT Service Provider)</li>
                            <li>Business Criticality</li>
                            <li>Data Sensitivity</li>
                            <li>SSO Protected</li>
                            <li>Lifecycle Status</li>
                        </ul>
                        <div id="statusMsg" class="loading">
                            <i class="fa fa-spinner fa-pulse"></i>&#160;Loading portfolio data&#8230;
                        </div>
                        <br/>
                        <button id="retryBtn" class="eas-retry-btn">
                            <i class="fa fa-download"></i>&#160;Download Again
                        </button>
                    </div>
                </main>

                <xsl:call-template name="Footer"/>
            </body>
        </html>
    </xsl:template>

</xsl:stylesheet>
