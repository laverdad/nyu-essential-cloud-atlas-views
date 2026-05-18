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
    xmlns:costfn="http://nyu.local/xsl/costfn"
    exclude-result-prefixes="jsesc costfn">

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

    <!-- OWASP A03 — escape arbitrary text for safe insertion into a JS double-quoted string literal -->
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

    <!-- ═══════════════════════════════════════════════════════════════════
         costfn:is-current — date-range filter for cost components.

         Rules (all relative to today):
           • No dates at all           → always include
           • Start only                → include if start ≤ today
           • End only                  → effective start = end − 5 years;
                                         include if effectiveStart ≤ today ≤ end
           • Both present              → include if start ≤ today ≤ end

         Dates are validated with a regex before xs:date() to avoid Saxon
         casting errors on blank or non-date values.
    ═══════════════════════════════════════════════════════════════════ -->
    <xsl:function name="costfn:is-current" as="xs:boolean">
        <xsl:param name="comp" as="element()"/>
        <xsl:variable name="startStr" select="string($comp/own_slot_value[slot_reference='cc_cost_start_date_iso_8601']/value[1])"/>
        <xsl:variable name="endStr"   select="string($comp/own_slot_value[slot_reference='cc_cost_end_date_iso_8601']/value[1])"/>
        <xsl:variable name="hasStart" select="matches($startStr, '^\d{4}-\d{2}-\d{2}')"/>
        <xsl:variable name="hasEnd"   select="matches($endStr,   '^\d{4}-\d{2}-\d{2}')"/>
        <xsl:variable name="today"    select="current-date()"/>
        <xsl:sequence select="
            if      (not($hasStart) and not($hasEnd)) then true()
            else if ($hasStart      and not($hasEnd)) then xs:date($startStr) le $today
            else if (not($hasStart) and $hasEnd)      then ($today ge xs:date($endStr) - xs:yearMonthDuration('P5Y'))
                                                           and ($today le xs:date($endStr))
            else    (xs:date($startStr) le $today     and xs:date($endStr) ge $today)
        "/>
    </xsl:function>

    <xsl:template match="knowledge_base">
        <xsl:call-template name="docType"/>
        <html lang="en">
            <head>
                <xsl:call-template name="commonHeadContent"/>
                <xsl:call-template name="RenderModalReportContent">
                    <xsl:with-param name="essModalClassNames" select="$linkClasses"/>
                </xsl:call-template>

                <title>Application Summary</title>

                <style>
                    /* ── Layout ─────────────────────────────────────────── */
                    .eas-sum-wrapper {
                        padding: 20px;
                        max-width: 1200px;
                        margin: 10px auto 40px auto;
                        font-family: 'Open Sans', Helvetica, Arial, sans-serif;
                        color: #333;
                    }
                    .eas-back-link {
                        display: inline-block;
                        margin-bottom: 18px;
                        color: #337ab7;
                        text-decoration: none;
                        font-size: 14px;
                        font-weight: 500;
                    }
                    .eas-back-link:hover { text-decoration: underline; }
                    .eas-back-link i { margin-right: 6px; }

                    /* ── App header card ────────────────────────────────── */
                    .eas-app-header {
                        background: #ffffff;
                        border-radius: 8px;
                        padding: 28px 32px;
                        box-shadow: 0 2px 8px rgba(0,0,0,0.08);
                        margin-bottom: 24px;
                        border-top: 4px solid #2c3e50;
                    }
                    .eas-app-name {
                        margin: 0 0 6px 0;
                        font-size: 28px;
                        font-weight: 700;
                        color: #2c3e50;
                        line-height: 1.2;
                    }
                    .eas-app-lifecycle {
                        display: inline-flex;
                        align-items: center;
                        gap: 8px;
                        font-size: 12px;
                        color: #455a64;
                        font-weight: 600;
                        text-transform: uppercase;
                        letter-spacing: 0.05em;
                        margin-bottom: 16px;
                    }
                    .eas-app-desc {
                        margin: 0;
                        color: #444;
                        font-size: 15px;
                        line-height: 1.6;
                    }
                    .eas-app-desc-empty { color: #555f69; font-style: italic; }
                    .eas-app-purpose {
                        margin: 0 0 8px 0;
                        color: #2c3e50;
                        font-size: 15px;
                        line-height: 1.6;
                    }
                    .eas-app-purpose strong { color: #455a64; margin-right: 4px; }

                    /* ── Hero tiles ─────────────────────────────────────── */
                    .eas-hero-row {
                        display: flex;
                        gap: 16px;
                        margin-bottom: 24px;
                        flex-wrap: wrap;
                    }
                    .eas-hero-tile {
                        flex: 1;
                        min-width: 160px;
                        background: #ffffff;
                        border-radius: 8px;
                        padding: 20px 16px;
                        text-align: center;
                        box-shadow: 0 2px 8px rgba(0,0,0,0.08);
                    }
                    .eas-hero-icon {
                        font-size: 26px;
                        color: #607d8b;
                        margin-bottom: 10px;
                    }
                    .eas-hero-value {
                        margin-bottom: 10px;
                        min-height: 26px;
                    }
                    .eas-hero-cost-value {
                        font-size: 22px;
                        font-weight: 700;
                        color: #2c3e50;
                        font-variant-numeric: tabular-nums;
                        white-space: nowrap;
                        line-height: 1.2;
                        margin-bottom: 10px;
                        min-height: 26px;
                    }
                    .eas-hero-label {
                        font-size: 11px;
                        color: #455a64;
                        font-weight: 700;
                        text-transform: uppercase;
                        letter-spacing: 0.06em;
                    }

                    /* ── Content cards ──────────────────────────────────── */
                    .eas-cards-row {
                        display: grid;
                        grid-template-columns: 1fr 1fr 1fr;
                        gap: 20px;
                    }
                    @media (max-width: 1000px) {
                        .eas-cards-row { grid-template-columns: 1fr 1fr; }
                    }
                    @media (max-width: 640px) {
                        .eas-cards-row { grid-template-columns: 1fr; }
                    }
                    .eas-card {
                        background: #ffffff;
                        border-radius: 8px;
                        padding: 24px 28px;
                        box-shadow: 0 2px 8px rgba(0,0,0,0.08);
                    }
                    .eas-card-title {
                        margin: 0 0 18px 0;
                        font-size: 14px;
                        font-weight: 700;
                        color: #2c3e50;
                        text-transform: uppercase;
                        letter-spacing: 0.06em;
                        padding-bottom: 10px;
                        border-bottom: 2px solid #ecf0f1;
                    }
                    .eas-card-title i {
                        margin-right: 8px;
                        color: #607d8b;
                    }
                    .eas-card-section {
                        margin-bottom: 18px;
                    }
                    .eas-card-section:last-child { margin-bottom: 0; }
                    .eas-card-section h4 {
                        margin: 0 0 8px 0;
                        font-size: 11px;
                        font-weight: 700;
                        color: #455a64;
                        text-transform: uppercase;
                        letter-spacing: 0.06em;
                    }
                    .eas-card-section ul {
                        margin: 0;
                        padding-left: 18px;
                        font-size: 14px;
                        color: #333;
                        line-height: 1.7;
                    }
                    .eas-card-section p {
                        margin: 0;
                        font-size: 14px;
                        color: #333;
                    }
                    .eas-role {
                        font-size: 12px;
                        color: #666;
                        font-style: italic;
                    }
                    .eas-none {
                        font-size: 13px;
                        color: #555f69;
                        font-style: italic;
                    }
                    .eas-none-warning {
                        color: #c62828;
                        font-weight: 600;
                        font-style: normal;
                    }
                    .eas-detail-label {
                        margin-top: 10px !important;
                        font-size: 11px !important;
                        color: #455a64 !important;
                        font-weight: 700;
                        text-transform: uppercase;
                        letter-spacing: 0.04em;
                    }
                    .eas-cost-breakdown {
                        font-size: 13px;
                        color: #455a64;
                        margin-top: 4px;
                        font-style: italic;
                    }

                    /* ── Badges (match v19 palette) ─────────────────────── */
                    .eas-badge {
                        display: inline-block;
                        padding: 4px 12px;
                        border-radius: 12px;
                        font-size: 12px;
                        font-weight: 600;
                        color: #fff;
                        white-space: nowrap;
                    }
                    .badge-crit-mission,
                    .badge-crit-critical { background: #c62828; }
                    .badge-crit-medium   { background: #7a5500; }
                    .badge-crit-low,
                    .badge-crit-notcrit  { background: #246d27; }
                    .badge-crit-none     { background: #555555; }
                    .badge-sens-high     { background: #c62828; }
                    .badge-sens-moderate { background: #7a5500; }
                    .badge-sens-low      { background: #246d27; }
                    .badge-sens-none     { background: #555555; }
                    .badge-sso-yes       { background: #2e7d32; }
                    .badge-sso-no        { background: #ecf0f1; color: #495057; }
                    .badge-itsp-yes      { background: #1976d2; }
                    .badge-itsp-none     { background: #fdecea; color: #c62828; font-weight: 700; border: 1px solid #f5c6cb; }
                    /* Integration Complexity badges */
                    .badge-intcx-none { background: #555555; }
                    .badge-intcx-low  { background: #246d27; }
                    .badge-intcx-mod  { background: #7a5500; }
                    .badge-intcx-high { background: #c62828; }
                    /* User Base badges */
                    .badge-ubase-team   { background: #00796b; }
                    .badge-ubase-school { background: #00838f; }
                    .badge-ubase-campus { background: #0277bd; }
                    .badge-ubase-univ   { background: #1565c0; }
                    .badge-ubase-public { background: #4527a0; }
                    /* User population tag chips */
                    .eas-pop-chip {
                        display: inline-block;
                        padding: 3px 10px;
                        border-radius: 10px;
                        font-size: 12px;
                        font-weight: 600;
                        background: #455a64;
                        color: #fff;
                        margin: 2px 3px 2px 0;
                    }
                    /* Lifecycle Status badges (match v19) */
                    .badge-lc-active  { background: #246d27; }
                    .badge-lc-dev     { background: #1565c0; }
                    .badge-lc-sunset  { background: #7a5500; }
                    .badge-lc-retired { background: #555555; }
                    .badge-lc-hold    { background: #5d4037; color: #fff; }
                    .badge-lc-other   { background: #455a64; }

                    /* ── Loading / error ────────────────────────────────── */
                    .eas-loading {
                        text-align: center;
                        padding: 60px;
                        color: #455a64;
                        font-size: 16px;
                    }
                    .eas-not-found {
                        background: #fff;
                        border-radius: 8px;
                        padding: 40px;
                        text-align: center;
                        color: #c62828;
                        font-size: 16px;
                        font-weight: 600;
                        box-shadow: 0 2px 8px rgba(0,0,0,0.08);
                    }

                    /* ── WCAG 2.1: visible focus indicators (2.4.7) ─────── */
                    .eas-back-link:focus-visible,
                    .eas-card a:focus-visible {
                        outline: 3px solid #ffbf47;
                        outline-offset: 2px;
                        text-decoration: underline;
                    }

                    /* ── WCAG 2.1: screen-reader-only utility ───────────── */
                    .sr-only {
                        position: absolute;
                        width: 1px;
                        height: 1px;
                        padding: 0;
                        margin: -1px;
                        overflow: hidden;
                        clip: rect(0,0,0,0);
                        white-space: nowrap;
                        border: 0;
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

                    /* ── Supplier Name Index: Supplier instance ID → display name ── */
                    var supplierNameIndex = {
                        <xsl:for-each select="/node()/simple_instance[type='Supplier']">
                            <xsl:variable name="renderedSup">
                                <xsl:call-template name="RenderMultiLangInstanceName">
                                    <xsl:with-param name="isForJSONAPI" select="true()"/>
                                    <xsl:with-param name="theSubjectInstance" select="."/>
                                </xsl:call-template>
                            </xsl:variable>
                            "<xsl:value-of select="jsesc:str(name)"/>": "<xsl:value-of select="jsesc:str(string($renderedSup))"/>"<xsl:if test="not(position() = last())">,</xsl:if>
                        </xsl:for-each>
                    };

                    /* ── App→Supplier Mapping: app instance ID → [supplier IDs] ── */
                    var appSupplierMapping = {
                        <xsl:for-each select="/node()/simple_instance[(type='Application_Provider' or type='Composite_Application_Provider') and own_slot_value[slot_reference='ap_supplier']]">
                            "<xsl:value-of select="jsesc:str(name)"/>": [<xsl:for-each select="own_slot_value[slot_reference='ap_supplier']/value">"<xsl:value-of select="jsesc:str(.)"/>"<xsl:if test="position() != last()">,</xsl:if></xsl:for-each>]<xsl:if test="position() != last()">,</xsl:if>
                        </xsl:for-each>
                    };

                    /* ── Default currency symbol (Report_Constant → currency_symbol) ── */
                    <xsl:variable name="defaultCurrencyConstant" select="/node()/simple_instance[(type='Report_Constant') and (own_slot_value[slot_reference='name']/value = 'Default Currency')]"/>
                    <xsl:variable name="defaultCurrency" select="/node()/simple_instance[name = $defaultCurrencyConstant/own_slot_value[slot_reference='report_constant_ea_elements']/value]"/>
                    <xsl:variable name="defaultCurrencySymbol" select="string($defaultCurrency/own_slot_value[slot_reference='currency_symbol']/value)"/>
                    var defaultCurrencySymbol = "<xsl:value-of select="jsesc:str(if (string-length($defaultCurrencySymbol) > 0) then $defaultCurrencySymbol else '$')"/>";

                    /* ── App→Cost Mapping: scoped to the single app being summarised ──
                       This view only ever reads appCostMapping[targetAppId], so we skip
                       the all-apps loop and compute one entry from $param1 (the PMA URL
                       param). Same JS contract as before; consumers fall back to 0 when
                       an app has no cost data. */
                    var appCostMapping = {
                        <xsl:if test="string-length($param1) &gt; 0">
                            <xsl:variable name="appCosts" select="/node()/simple_instance[type='Cost'][(own_slot_value[slot_reference='costs_for_element']/value = $param1) or (own_slot_value[slot_reference='cost_for_elements']/value = $param1)]"/>
                            <xsl:if test="$appCosts">
                                <xsl:variable name="compIds" select="$appCosts/own_slot_value[slot_reference='cost_components']/value"/>
                                <xsl:variable name="appCostComps" select="/node()/simple_instance[name = $compIds]"/>
                                <xsl:variable name="currentComps" select="$appCostComps[costfn:is-current(.)]"/>
                                <xsl:variable name="totalCost" select="sum($currentComps/own_slot_value[slot_reference='cc_cost_amount']/value[. &gt; 0])"/>
                                <xsl:if test="$totalCost &gt; 0">"<xsl:value-of select="jsesc:str($param1)"/>": <xsl:value-of select="$totalCost"/>,
                                </xsl:if>
                            </xsl:if>
                        </xsl:if>
                        "_eas_cost_sentinel_": 0
                    };

                    /* ── Per-app reference-list resolutions ─────────────────────
                       Four new fields, all scoped to $param1 (PMA). Each is a list
                       of instance IDs on the application; resolved server-side to
                       the referenced instances' name (and URL where applicable). */

                    /* Regulations — drill through the join instance (Regulated_Component_Regulation
                       or similar) referenced by ea_subject_to_regulations. The join's own name
                       is a composed string; the slot regulated_component_regulation points to
                       the underlying Regulation whose plain name we want. Falls back to the
                       join name if the drill-down slot is empty. */
                    var appRegulations = [
                        <xsl:if test="string-length($param1) &gt; 0">
                            <xsl:variable name="appNode" select="/node()/simple_instance[name = $param1]"/>
                            <xsl:variable name="joinIds" select="$appNode/own_slot_value[slot_reference='ea_subject_to_regulations']/value"/>
                            <xsl:variable name="joins" select="/node()/simple_instance[name = $joinIds]"/>
                            <xsl:variable name="regIds" select="$joins/own_slot_value[slot_reference='regulated_component_regulation']/value"/>
                            <xsl:variable name="regs" select="/node()/simple_instance[name = $regIds]"/>
                            <xsl:choose>
                                <xsl:when test="$regs">
                                    <xsl:for-each select="$regs">
                                        "<xsl:value-of select="jsesc:str(string(own_slot_value[slot_reference='name']/value))"/>"<xsl:if test="position() != last()">,</xsl:if>
                                    </xsl:for-each>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:for-each select="$joins">
                                        "<xsl:value-of select="jsesc:str(string(own_slot_value[slot_reference='name']/value))"/>"<xsl:if test="position() != last()">,</xsl:if>
                                    </xsl:for-each>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:if>
                    ];

                    /* External Reference Links (external_reference_links → External_Reference)
                       Each entry resolves the URL from external_reference_url. The link
                       label uses the URL itself (the instance `name` is typically a generic
                       word like "URL" so it isn't surfaced). */
                    var appExtRefLinks = [
                        <xsl:if test="string-length($param1) &gt; 0">
                            <xsl:variable name="appNode2" select="/node()/simple_instance[name = $param1]"/>
                            <xsl:variable name="refIds" select="$appNode2/own_slot_value[slot_reference='external_reference_links']/value"/>
                            <xsl:for-each select="/node()/simple_instance[name = $refIds]">
                                { "url": "<xsl:value-of select="jsesc:str(string(own_slot_value[slot_reference='external_reference_url']/value))"/>" }<xsl:if test="position() != last()">,</xsl:if>
                            </xsl:for-each>
                        </xsl:if>
                    ];

                    /* Purpose (application_provider_purpose → Application_Provider_Purpose) */
                    var appPurposes = [
                        <xsl:if test="string-length($param1) &gt; 0">
                            <xsl:variable name="appNode3" select="/node()/simple_instance[name = $param1]"/>
                            <xsl:variable name="purIds" select="$appNode3/own_slot_value[slot_reference='application_provider_purpose']/value"/>
                            <xsl:for-each select="/node()/simple_instance[name = $purIds]">
                                "<xsl:value-of select="jsesc:str(string(own_slot_value[slot_reference='name']/value))"/>"<xsl:if test="position() != last()">,</xsl:if>
                            </xsl:for-each>
                        </xsl:if>
                    ];

                    /* Services Provided — drill through Application_Service_Provision to the
                       underlying Application_Service. The provides_application_services slot
                       references Provision instances whose own `name` is a composed string
                       like "X as Y". Resolving via application_service_for_provision yields
                       just the service name ("Y"). Service IDs are collected once and the
                       underlying Application_Service instances are resolved in a single
                       look-up so commas separate correctly. */
                    var appServices = [
                        <xsl:if test="string-length($param1) &gt; 0">
                            <xsl:variable name="appNode4" select="/node()/simple_instance[name = $param1]"/>
                            <xsl:variable name="provIds" select="$appNode4/own_slot_value[slot_reference='provides_application_services']/value"/>
                            <xsl:variable name="provisions" select="/node()/simple_instance[name = $provIds]"/>
                            <xsl:variable name="svcIds" select="$provisions/own_slot_value[slot_reference='implementing_application_service']/value"/>
                            <xsl:variable name="svcInstances" select="/node()/simple_instance[name = $svcIds]"/>
                            <xsl:choose>
                                <xsl:when test="$svcInstances">
                                    <xsl:for-each select="$svcInstances">
                                        "<xsl:value-of select="jsesc:str(string(own_slot_value[slot_reference='name']/value))"/>"<xsl:if test="position() != last()">,</xsl:if>
                                    </xsl:for-each>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:for-each select="$provisions">
                                        "<xsl:value-of select="jsesc:str(string(own_slot_value[slot_reference='name']/value))"/>"<xsl:if test="position() != last()">,</xsl:if>
                                    </xsl:for-each>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:if>
                    ];

                    /* ── Helpers ─────────────────────────────────────────── */
                    function safeStr(val) {
                        if (val == null) { return ''; }
                        return String(val).trim();
                    }

                    function escapeHtml(s) {
                        return String(s == null ? '' : s)
                            .replace(/&amp;/g, '&amp;amp;')
                            .replace(/"/g, '&amp;quot;')
                            .replace(/'/g, '&amp;#39;')
                            .replace(/&lt;/g, '&amp;lt;')
                            .replace(/&gt;/g, '&amp;gt;');
                    }

                    /* URL sanitiser for hrefs sourced from data. Allows http(s), mailto,
                       and protocol-relative URLs; rejects javascript:, data:, file:, etc.
                       Bare values like "www.google.com" are auto-prefixed with https://. */
                    function safeUrl(u) {
                        if (!u) { return null; }
                        var s = String(u).trim();
                        if (!s) { return null; }
                        if (/^https?:\/\//i.test(s))               { return s; }
                        if (/^mailto:/i.test(s))                   { return s; }
                        if (/^\/\//.test(s))                       { return s; }
                        if (/^[a-zA-Z][a-zA-Z0-9+.\-]*:/.test(s))  { return null; }
                        return 'https://' + s;
                    }

                    function isCritical(app) {
                        var v = (app.businessCriticality || '').toLowerCase();
                        return v.indexOf('mission') &gt;= 0 || (v.indexOf('critical') &gt;= 0 &amp;&amp; v.indexOf('not') &lt; 0);
                    }

                    /* Format a numeric cost as currency-prefixed thousand-separated string. */
                    function formatCost(n) {
                        var num = Number(n);
                        if (!num || isNaN(num) || num &lt;= 0) { return ''; }
                        return defaultCurrencySymbol + num.toLocaleString('en-US', { maximumFractionDigits: 0 });
                    }

                    /* ── Badge helpers ───────────────────────────────────── */
                    function critBadge(val) {
                        var v = (val || '').toLowerCase();
                        var cls = 'badge-crit-none';
                        if (v.indexOf('mission') &gt;= 0)                                      { cls = 'badge-crit-mission'; }
                        else if (v.indexOf('critical') &gt;= 0 &amp;&amp; v.indexOf('not') &lt; 0) { cls = 'badge-crit-critical'; }
                        else if (v === 'medium')                                             { cls = 'badge-crit-medium'; }
                        else if (v.indexOf('not') &gt;= 0 || v === 'low')                      { cls = 'badge-crit-notcrit'; }
                        return '&lt;span class="eas-badge ' + cls + '"&gt;' + escapeHtml(val) + '&lt;/span&gt;';
                    }

                    function sensBadge(val) {
                        var cls = val === 'High'     ? 'badge-sens-high'     :
                                  val === 'Moderate' ? 'badge-sens-moderate' :
                                  val === 'Low'      ? 'badge-sens-low'      : 'badge-sens-none';
                        return '&lt;span class="eas-badge ' + cls + '"&gt;' + escapeHtml(val) + '&lt;/span&gt;';
                    }

                    function ssoBadge(val) {
                        return val
                            ? '&lt;span class="eas-badge badge-sso-yes"&gt;&lt;i class="fa fa-check" aria-hidden="true"&gt;&lt;/i&gt; Yes&lt;/span&gt;'
                            : '&lt;span class="eas-badge badge-sso-no"&gt;No&lt;/span&gt;';
                    }

                    function itspHeroBadge(itspList) {
                        if (itspList.length === 0) {
                            return '&lt;span class="eas-badge badge-itsp-none"&gt;None&lt;/span&gt;';
                        }
                        var label = escapeHtml(itspList[0]);
                        if (itspList.length &gt; 1) {
                            label += ' +' + (itspList.length - 1);
                        }
                        return '&lt;span class="eas-badge badge-itsp-yes"&gt;' + label + '&lt;/span&gt;';
                    }

                    function intComplexityBadge(val) {
                        var v = (val || '').toLowerCase();
                        var cls = v.indexOf('high')     &gt;= 0 ? 'badge-intcx-high' :
                                  v.indexOf('moderate') &gt;= 0 ? 'badge-intcx-mod'  :
                                  v.indexOf('low')      &gt;= 0 ? 'badge-intcx-low'  : 'badge-intcx-none';
                        return '&lt;span class="eas-badge ' + cls + '"&gt;' + escapeHtml(val) + '&lt;/span&gt;';
                    }

                    function userBaseBadge(val) {
                        var v = (val || '').toLowerCase();
                        var cls = v.indexOf('team')   &gt;= 0 ? 'badge-ubase-team'   :
                                  v.indexOf('school') &gt;= 0 ? 'badge-ubase-school' :
                                  v.indexOf('campus') &gt;= 0 ? 'badge-ubase-campus' :
                                  v.indexOf('univ')   &gt;= 0 ? 'badge-ubase-univ'   :
                                  v.indexOf('public') &gt;= 0 ? 'badge-ubase-public' : 'badge-crit-none';
                        return '&lt;span class="eas-badge ' + cls + '"&gt;' + escapeHtml(val) + '&lt;/span&gt;';
                    }

                    /* Lifecycle Status badge — mirrors lcStatusBadge() in v19. */
                    function lcStatusBadge(val) {
                        var v = (val || '').toLowerCase();
                        var cls = (v.indexOf('active') &gt;= 0 || v === 'production')             ? 'badge-lc-active'  :
                                  (v.indexOf('develop') &gt;= 0 || v.indexOf('plan') &gt;= 0)       ? 'badge-lc-dev'     :
                                  (v.indexOf('sunset') &gt;= 0)                                   ? 'badge-lc-sunset'  :
                                  (v.indexOf('retir') &gt;= 0)                                    ? 'badge-lc-retired' :
                                  (v.indexOf('hold') &gt;= 0)                                     ? 'badge-lc-hold'    : 'badge-lc-other';
                        return '&lt;span class="eas-badge ' + cls + '"&gt;' + escapeHtml(val) + '&lt;/span&gt;';
                    }

                    /* ── API handles &amp; view model ───────────────────────── */
                    let busCapAppMartApps, orgSummary;
                    var viewModel = { app: null };

                    var urlParams   = new URLSearchParams(window.location.search);
                    var targetAppId = (urlParams.get('PMA') || '').trim();

                    /* ── Entry point ─────────────────────────────────────── */
                    $(document).ready(function () {
                        if (!targetAppId) {
                            var nfEl = document.getElementById('appContent');
                            nfEl.innerHTML =
                                '&lt;div class="eas-not-found" role="alert"&gt;No application ID supplied in URL (missing PMA parameter).&lt;/div&gt;';
                            nfEl.setAttribute('aria-busy', 'false');
                            return;
                        }

                        var apiList = ['busCapAppMartApps', 'orgSummary'];

                        async function executeFetchAndRender() {
                            try {
                                var responses = await fetchAndRenderData(apiList);
                                ({ busCapAppMartApps, orgSummary } = responses);
                                buildViewModel();
                                renderView();
                            } catch (err) {
                                console.error('[App Summary] Error loading data:', err);
                                var errEl = document.getElementById('appContent');
                                errEl.innerHTML =
                                    '&lt;div class="eas-not-found" role="alert"&gt;Error loading data. Check the browser console.&lt;/div&gt;';
                                errEl.setAttribute('aria-busy', 'false');
                            }
                        }

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

                        /* 2. Criticality, lifecycle &amp; new enum indices */
                        var criticalityIndex          = {};
                        var lifecycleIndex             = {};
                        var integrationComplexityIndex = {};
                        var userBaseIndex              = {};
                        var userPopulationIndex        = {};
                        if (busCapAppMartApps &amp;&amp; busCapAppMartApps.filters) {
                            var critFilter = null;
                            for (var fi = 0; fi &lt; busCapAppMartApps.filters.length; fi++) {
                                var f = busCapAppMartApps.filters[fi];
                                if (f.slotName === 'ap_business_criticality') { critFilter = f; }
                                if (f.slotName === 'lifecycle_status_application_provider') {
                                    if (f.values) {
                                        f.values.forEach(function (v) {
                                            if (v.id) { lifecycleIndex[v.id.trim()] = v.enum_name || v.name || 'Unknown'; }
                                        });
                                    }
                                }
                                if (f.slotName === 'Integration Complexity' &amp;&amp; f.values) {
                                    f.values.forEach(function (v) {
                                        if (v.id) { integrationComplexityIndex[v.id.trim()] = v.enum_name || v.name || 'Unknown'; }
                                    });
                                }
                                if (f.slotName === 'User Base' &amp;&amp; f.values) {
                                    f.values.forEach(function (v) {
                                        if (v.id) { userBaseIndex[v.id.trim()] = v.enum_name || v.name || 'Unknown'; }
                                    });
                                }
                                if (f.slotName === 'User Population' &amp;&amp; f.values) {
                                    f.values.forEach(function (v) {
                                        if (v.id) { userPopulationIndex[v.id.trim()] = v.enum_name || v.name || 'Unknown'; }
                                    });
                                }
                            }
                            if (critFilter &amp;&amp; critFilter.values) {
                                critFilter.values.forEach(function (v) {
                                    if (v.id) { criticalityIndex[v.id.trim()] = v.enum_name || v.name || 'Unknown'; }
                                });
                            }
                        }

                        /* 3. Find the target raw app by ID */
                        var apps = (busCapAppMartApps &amp;&amp; busCapAppMartApps.applications)
                            ? busCapAppMartApps.applications : [];
                        var rawApp = null;
                        for (var ai = 0; ai &lt; apps.length; ai++) {
                            if ((apps[ai].id || '').trim() === targetAppId) {
                                rawApp = apps[ai];
                                break;
                            }
                        }
                        if (!rawApp) { viewModel.app = null; return; }

                        /* 4. Enrich with arrays for detail display */
                        viewModel.app = enrichApp(rawApp, a2rIndex, criticalityIndex, lifecycleIndex,
                                                  integrationComplexityIndex, userBaseIndex, userPopulationIndex);
                    }

                    function enrichApp(rawApp, a2rIndex, criticalityIndex, lifecycleIndex,
                                       integrationComplexityIndex, userBaseIndex, userPopulationIndex) {
                        var appId = (rawApp.id || '').trim();

                        /* Stakeholders: split into business units, people, ITSP */
                        var sA2Rs         = rawApp.sA2R || [];
                        var businessUnits = []; /* {name, role} */
                        var stakeholders  = []; /* {name, role} */
                        var itspList      = []; /* [name] */
                        for (var si = 0; si &lt; sA2Rs.length; si++) {
                            var a2rEntry = a2rIndex[(sA2Rs[si] || '').trim()];
                            if (!a2rEntry || !a2rEntry.actor) { continue; }
                            if (a2rEntry.type === 'Group_Actor') {
                                businessUnits.push({ name: a2rEntry.actor, role: a2rEntry.role || '' });
                                if (a2rEntry.role &amp;&amp; a2rEntry.role.indexOf('ITSP') &gt;= 0) {
                                    itspList.push(a2rEntry.actor);
                                }
                            } else if (a2rEntry.type === 'Individual_Actor') {
                                stakeholders.push({ name: a2rEntry.actor, role: a2rEntry.role || '' });
                            }
                        }

                        /* Business criticality */
                        var critIds   = rawApp.ap_business_criticality || [];
                        var firstCrit = critIds.length &gt; 0 ? critIds[0].trim() : null;
                        var businessCriticality = firstCrit
                            ? (criticalityIndex[firstCrit] || rawApp.criticality || 'Unclassified')
                            : (rawApp.criticality || 'Unclassified');

                        /* Lifecycle status */
                        var lifecycleStatus = 'Active';
                        var lcIds   = rawApp.lifecycle_status_application_provider || [];
                        var lcLabel = lcIds.length &gt; 0 ? lifecycleIndex[lcIds[0]] : null;
                        if (!lcLabel &amp;&amp; rawApp.lifecycle) { lcLabel = lifecycleIndex[rawApp.lifecycle] || rawApp.lifecycle; }
                        if (lcLabel) { lifecycleStatus = lcLabel; }

                        /* Data sensitivity: capture actual classification labels */
                        var appSecClasses        = appSecMapping[appId] || rawApp.securityClassifications || [];
                        var classificationLabels = [];
                        var dataSensitivity      = 'Unclassified';
                        var sensitivitySet       = false;
                        for (var ci = 0; ci &lt; appSecClasses.length; ci++) {
                            var classId      = safeStr(appSecClasses[ci]);
                            var classNameStr = secClassLookup[classId] || classId;
                            if (classNameStr) { classificationLabels.push(classNameStr); }
                            if (!sensitivitySet) {
                                var cn = classNameStr.toLowerCase();
                                if (cn.indexOf('high') &gt;= 0 || cn.indexOf('restricted') &gt;= 0 || cn.indexOf('confidential') &gt;= 0 || cn.indexOf('secret') &gt;= 0) {
                                    dataSensitivity = 'High'; sensitivitySet = true;
                                } else if (cn.indexOf('medium') &gt;= 0 || cn.indexOf('moderate') &gt;= 0) {
                                    dataSensitivity = 'Moderate'; sensitivitySet = true;
                                } else if (cn.indexOf('low') &gt;= 0 || cn.indexOf('public') &gt;= 0 || cn.indexOf('open') &gt;= 0) {
                                    dataSensitivity = 'Low'; sensitivitySet = true;
                                }
                            }
                        }

                        /* SSO: capture matching interface names (original case) */
                        var SSO_TERMS     = ['oauth2', 'saml2', 'pam', 'entra'];
                        var ssoInterfaces = [];
                        var allIface      = (rawApp.inIList || []).concat(rawApp.outIList || []);
                        for (var ii = 0; ii &lt; allIface.length; ii++) {
                            var entry     = allIface[ii];
                            var entryName = safeStr(entry &amp;&amp; typeof entry === 'object' ? entry.name : entry);
                            var en        = entryName.toLowerCase();
                            for (var ti = 0; ti &lt; SSO_TERMS.length; ti++) {
                                if (en.indexOf(SSO_TERMS[ti]) &gt;= 0) {
                                    ssoInterfaces.push(entryName);
                                    break;
                                }
                            }
                        }
                        var ssoProtected = ssoInterfaces.length &gt; 0;

                        var intCxIds = rawApp['Integration Complexity'] || [];
                        var integrationComplexity = intCxIds.length &gt; 0
                            ? (integrationComplexityIndex[intCxIds[0].trim()] || 'Unknown')
                            : 'Unknown';

                        var userBaseIds = rawApp['User Base'] || [];
                        var userBase = userBaseIds.length &gt; 0
                            ? (userBaseIndex[userBaseIds[0].trim()] || 'Unknown')
                            : 'Unknown';

                        var userPopIds = rawApp['User Population'] || [];
                        var userPopulation = [];
                        for (var pi = 0; pi &lt; userPopIds.length; pi++) {
                            var lbl = userPopulationIndex[userPopIds[pi].trim()];
                            if (lbl) { userPopulation.push(lbl); }
                        }

                        /* Supplier — resolved from appSupplierMapping (XSL-emitted, built from
                           the ap_supplier slot on Application_Provider instances). */
                        var appSupIds    = appSupplierMapping[appId] || [];
                        var supplierList = [];
                        for (var spi = 0; spi &lt; appSupIds.length; spi++) {
                            var sName = supplierNameIndex[appSupIds[spi]];
                            if (sName) { supplierList.push(sName); }
                        }

                        /* Annual Cost — pre-computed server-side with date-range filter. */
                        var costNum       = Number(appCostMapping[appId]) || 0;
                        var costFormatted = formatCost(costNum);

                        return {
                            id:                      appId,
                            name:                    rawApp.name || 'Unnamed Application',
                            description:             safeStr(rawApp.description || rawApp.ap_description || ''),
                            businessUnits:           businessUnits,
                            stakeholders:            stakeholders,
                            itspList:                itspList,
                            businessCriticality:     businessCriticality,
                            dataSensitivity:         dataSensitivity,
                            classificationLabels:    classificationLabels,
                            ssoProtected:            ssoProtected,
                            ssoInterfaces:           ssoInterfaces,
                            lifecycleStatus:         lifecycleStatus,
                            integrationComplexity:   integrationComplexity,
                            userBase:                userBase,
                            userPopulation:          userPopulation,
                            supplierList:            supplierList,
                            costNum:                 costNum,
                            costFormatted:           costFormatted,
                            regulations:             appRegulations,
                            externalLinks:           appExtRefLinks,
                            purposes:                appPurposes,
                            services:                appServices
                        };
                    }

                    /* ════════════════════════════════════════════════════════
                       RENDER
                    ════════════════════════════════════════════════════════ */
                    function renderView() {
                        var contentEl = document.getElementById('appContent');
                        if (!viewModel.app) {
                            contentEl.innerHTML =
                                '&lt;div class="eas-not-found" role="alert"&gt;Application not found for ID: ' + escapeHtml(targetAppId) + '&lt;/div&gt;';
                            contentEl.setAttribute('aria-busy', 'false');
                            return;
                        }
                        var app = viewModel.app;
                        document.title = app.name + ' — Application Summary';

                        var html = '';

                        /* ── Header card ── */
                        html += '&lt;div class="eas-app-header"&gt;';
                        html +=   '&lt;h1 class="eas-app-name"&gt;' + escapeHtml(app.name) + '&lt;/h1&gt;';
                        html +=   '&lt;div class="eas-app-lifecycle"&gt;' +
                                  '&lt;span&gt;Lifecycle:&lt;/span&gt;' +
                                  lcStatusBadge(app.lifecycleStatus) +
                                  '&lt;/div&gt;';
                        if (app.purposes &amp;&amp; app.purposes.length &gt; 0) {
                            html += '&lt;p class="eas-app-purpose"&gt;&lt;strong&gt;Purpose:&lt;/strong&gt; ' +
                                    escapeHtml(app.purposes.join('; ')) + '&lt;/p&gt;';
                        }
                        html +=   '&lt;p class="eas-app-desc"&gt;' +
                                  (app.description
                                    ? escapeHtml(app.description)
                                    : '&lt;span class="eas-app-desc-empty"&gt;No description provided.&lt;/span&gt;') +
                                  '&lt;/p&gt;';
                        html += '&lt;/div&gt;';

                        /* ── Hero tiles ── */
                        html += '&lt;div class="eas-hero-row"&gt;';
                        html +=   heroTile('fa-exclamation-circle', 'Business Criticality', critBadge(app.businessCriticality));
                        html +=   heroTile('fa-database',           'Data Sensitivity',     sensBadge(app.dataSensitivity));
                        html +=   heroTile('fa-shield',             'SSO Protected',        ssoBadge(app.ssoProtected));
                        html +=   heroTile('fa-user-md',            'ITSP',                 itspHeroBadge(app.itspList));
                        html +=   costHeroTile(app.costFormatted);
                        html += '&lt;/div&gt;';

                        /* ── Content cards ── */
                        html += '&lt;div class="eas-cards-row"&gt;';
                        html +=   renderOwnershipCard(app);
                        html +=   renderSecurityCard(app);
                        html +=   renderUsageCard(app);
                        html +=   renderServicesCard(app);
                        html +=   renderReferencesCard(app);
                        html += '&lt;/div&gt;';

                        contentEl.innerHTML = html;
                        contentEl.setAttribute('aria-busy', 'false');
                    }

                    function heroTile(icon, label, valueHtml) {
                        return '&lt;div class="eas-hero-tile" role="group" aria-label="' + label + '"&gt;' +
                               '&lt;div class="eas-hero-icon" aria-hidden="true"&gt;&lt;i class="fa ' + icon + '"&gt;&lt;/i&gt;&lt;/div&gt;' +
                               '&lt;div class="eas-hero-value"&gt;' + valueHtml + '&lt;/div&gt;' +
                               '&lt;div class="eas-hero-label"&gt;' + label + '&lt;/div&gt;' +
                               '&lt;/div&gt;';
                    }

                    function costHeroTile(costFormatted) {
                        var displayVal = costFormatted
                            ? '&lt;div class="eas-hero-cost-value" aria-label="Annual cost: ' + escapeHtml(costFormatted) + '"&gt;' + escapeHtml(costFormatted) + '&lt;/div&gt;'
                            : '&lt;div class="eas-hero-cost-value"&gt;&lt;span class="eas-none"&gt;Not recorded&lt;/span&gt;&lt;/div&gt;';
                        return '&lt;div class="eas-hero-tile" role="group" aria-label="Annual Cost"&gt;' +
                               '&lt;div class="eas-hero-icon" aria-hidden="true"&gt;&lt;i class="fa fa-usd" style="color:#607d8b"&gt;&lt;/i&gt;&lt;/div&gt;' +
                               displayVal +
                               '&lt;div class="eas-hero-label"&gt;Annual Cost&lt;/div&gt;' +
                               '&lt;/div&gt;';
                    }

                    function renderOwnershipCard(app) {
                        var html = '&lt;div class="eas-card"&gt;';
                        html += '&lt;h2 class="eas-card-title"&gt;&lt;i class="fa fa-users" aria-hidden="true"&gt;&lt;/i&gt;Ownership&lt;/h2&gt;';

                        /* Supplier */
                        html += '&lt;div class="eas-card-section"&gt;&lt;h4&gt;Supplier&lt;/h4&gt;';
                        if (app.supplierList.length &gt; 0) {
                            html += '&lt;ul&gt;';
                            for (var sp = 0; sp &lt; app.supplierList.length; sp++) {
                                html += '&lt;li&gt;' + escapeHtml(app.supplierList[sp]) + '&lt;/li&gt;';
                            }
                            html += '&lt;/ul&gt;';
                        } else {
                            html += '&lt;p class="eas-none"&gt;Not recorded&lt;/p&gt;';
                        }
                        html += '&lt;/div&gt;';

                        /* Business Units */
                        html += '&lt;div class="eas-card-section"&gt;&lt;h4&gt;Business Units&lt;/h4&gt;';
                        if (app.businessUnits.length &gt; 0) {
                            html += '&lt;ul&gt;';
                            for (var i = 0; i &lt; app.businessUnits.length; i++) {
                                var bu = app.businessUnits[i];
                                html += '&lt;li&gt;' + escapeHtml(bu.name) +
                                        (bu.role ? ' &lt;span class="eas-role"&gt;(' + escapeHtml(bu.role) + ')&lt;/span&gt;' : '') +
                                        '&lt;/li&gt;';
                            }
                            html += '&lt;/ul&gt;';
                        } else {
                            html += '&lt;p class="eas-none"&gt;None assigned&lt;/p&gt;';
                        }
                        html += '&lt;/div&gt;';

                        /* People */
                        html += '&lt;div class="eas-card-section"&gt;&lt;h4&gt;People&lt;/h4&gt;';
                        if (app.stakeholders.length &gt; 0) {
                            html += '&lt;ul&gt;';
                            for (var p = 0; p &lt; app.stakeholders.length; p++) {
                                var person = app.stakeholders[p];
                                html += '&lt;li&gt;' + escapeHtml(person.name) +
                                        (person.role ? ' &lt;span class="eas-role"&gt;(' + escapeHtml(person.role) + ')&lt;/span&gt;' : '') +
                                        '&lt;/li&gt;';
                            }
                            html += '&lt;/ul&gt;';
                        } else {
                            html += '&lt;p class="eas-none"&gt;None assigned&lt;/p&gt;';
                        }
                        html += '&lt;/div&gt;';

                        /* ITSP */
                        html += '&lt;div class="eas-card-section"&gt;&lt;h4&gt;IT Service Provider (ITSP)&lt;/h4&gt;';
                        if (app.itspList.length &gt; 0) {
                            html += '&lt;ul&gt;';
                            for (var t = 0; t &lt; app.itspList.length; t++) {
                                html += '&lt;li&gt;' + escapeHtml(app.itspList[t]) + '&lt;/li&gt;';
                            }
                            html += '&lt;/ul&gt;';
                        } else {
                            html += '&lt;p class="eas-none eas-none-warning"&gt;&lt;i class="fa fa-exclamation-triangle" aria-hidden="true"&gt;&lt;/i&gt; No ITSP assigned&lt;/p&gt;';
                        }
                        html += '&lt;/div&gt;';

                        html += '&lt;/div&gt;';
                        return html;
                    }

                    function renderSecurityCard(app) {
                        var html = '&lt;div class="eas-card"&gt;';
                        html += '&lt;h2 class="eas-card-title"&gt;&lt;i class="fa fa-lock" aria-hidden="true"&gt;&lt;/i&gt;Security &amp;amp; Classification&lt;/h2&gt;';

                        /* Business Criticality */
                        html += '&lt;div class="eas-card-section"&gt;&lt;h4&gt;Business Criticality&lt;/h4&gt;';
                        html += '&lt;p&gt;' + critBadge(app.businessCriticality) + '&lt;/p&gt;';
                        html += '&lt;/div&gt;';

                        /* Data Sensitivity */
                        html += '&lt;div class="eas-card-section"&gt;&lt;h4&gt;Data Sensitivity&lt;/h4&gt;';
                        html += '&lt;p&gt;' + sensBadge(app.dataSensitivity) + '&lt;/p&gt;';
                        html += '&lt;/div&gt;';

                        /* Integration Complexity */
                        html += '&lt;div class="eas-card-section"&gt;&lt;h4&gt;Integration Complexity&lt;/h4&gt;';
                        html += '&lt;p&gt;' + (app.integrationComplexity &amp;&amp; app.integrationComplexity !== 'Unknown'
                            ? intComplexityBadge(app.integrationComplexity)
                            : '&lt;span class="eas-none"&gt;Not recorded&lt;/span&gt;') + '&lt;/p&gt;';
                        html += '&lt;/div&gt;';

                        /* SSO */
                        html += '&lt;div class="eas-card-section"&gt;&lt;h4&gt;Single Sign-On (SSO)&lt;/h4&gt;';
                        html += '&lt;p&gt;' + ssoBadge(app.ssoProtected) + '&lt;/p&gt;';
                        if (app.ssoInterfaces.length &gt; 0) {
                            html += '&lt;p class="eas-detail-label"&gt;Protected via interfaces&lt;/p&gt;';
                            html += '&lt;ul&gt;';
                            for (var ii = 0; ii &lt; app.ssoInterfaces.length; ii++) {
                                html += '&lt;li&gt;' + escapeHtml(app.ssoInterfaces[ii]) + '&lt;/li&gt;';
                            }
                            html += '&lt;/ul&gt;';
                        } else if (!app.ssoProtected) {
                            html += '&lt;p class="eas-none eas-none-warning"&gt;&lt;i class="fa fa-exclamation-triangle" aria-hidden="true"&gt;&lt;/i&gt; No SSO protection detected&lt;/p&gt;';
                        }
                        html += '&lt;/div&gt;';

                        /* Regulations */
                        html += '&lt;div class="eas-card-section"&gt;&lt;h4&gt;Subject to Regulations&lt;/h4&gt;';
                        if (app.regulations &amp;&amp; app.regulations.length &gt; 0) {
                            html += '&lt;ul&gt;';
                            for (var ri = 0; ri &lt; app.regulations.length; ri++) {
                                html += '&lt;li&gt;' + escapeHtml(app.regulations[ri]) + '&lt;/li&gt;';
                            }
                            html += '&lt;/ul&gt;';
                        } else {
                            html += '&lt;p class="eas-none"&gt;None recorded&lt;/p&gt;';
                        }
                        html += '&lt;/div&gt;';

                        html += '&lt;/div&gt;';
                        return html;
                    }

                    function renderUsageCard(app) {
                        var html = '&lt;div class="eas-card"&gt;';
                        html += '&lt;h2 class="eas-card-title"&gt;&lt;i class="fa fa-bar-chart" aria-hidden="true"&gt;&lt;/i&gt;Usage Profile&lt;/h2&gt;';

                        /* User Base */
                        html += '&lt;div class="eas-card-section"&gt;&lt;h4&gt;User Base&lt;/h4&gt;';
                        html += '&lt;p&gt;' + (app.userBase &amp;&amp; app.userBase !== 'Unknown'
                            ? userBaseBadge(app.userBase)
                            : '&lt;span class="eas-none"&gt;Not recorded&lt;/span&gt;') + '&lt;/p&gt;';
                        html += '&lt;/div&gt;';

                        /* User Population */
                        html += '&lt;div class="eas-card-section"&gt;&lt;h4&gt;User Population&lt;/h4&gt;';
                        if (app.userPopulation.length &gt; 0) {
                            html += '&lt;p&gt;';
                            for (var i = 0; i &lt; app.userPopulation.length; i++) {
                                html += '&lt;span class="eas-pop-chip"&gt;' + escapeHtml(app.userPopulation[i]) + '&lt;/span&gt;';
                            }
                            html += '&lt;/p&gt;';
                        } else {
                            html += '&lt;p class="eas-none"&gt;Not recorded&lt;/p&gt;';
                        }
                        html += '&lt;/div&gt;';

                        /* Annual Cost (detail) */
                        html += '&lt;div class="eas-card-section"&gt;&lt;h4&gt;Annual Cost&lt;/h4&gt;';
                        if (app.costFormatted) {
                            html += '&lt;p style="font-size:16px; font-weight:700; font-variant-numeric:tabular-nums; color:#2c3e50;"&gt;' +
                                    escapeHtml(app.costFormatted) + '&lt;/p&gt;';
                            html += '&lt;p class="eas-cost-breakdown"&gt;Current costs only (date-filtered)&lt;/p&gt;';
                        } else {
                            html += '&lt;p class="eas-none"&gt;Not recorded&lt;/p&gt;';
                        }
                        html += '&lt;/div&gt;';

                        html += '&lt;/div&gt;';
                        return html;
                    }

                    function renderServicesCard(app) {
                        var html = '&lt;div class="eas-card"&gt;';
                        html += '&lt;h2 class="eas-card-title"&gt;&lt;i class="fa fa-cogs" aria-hidden="true"&gt;&lt;/i&gt;Services Provided&lt;/h2&gt;';
                        html += '&lt;div class="eas-card-section"&gt;';
                        if (app.services &amp;&amp; app.services.length &gt; 0) {
                            html += '&lt;ul&gt;';
                            for (var si = 0; si &lt; app.services.length; si++) {
                                html += '&lt;li&gt;' + escapeHtml(app.services[si]) + '&lt;/li&gt;';
                            }
                            html += '&lt;/ul&gt;';
                        } else {
                            html += '&lt;p class="eas-none"&gt;None recorded&lt;/p&gt;';
                        }
                        html += '&lt;/div&gt;';
                        html += '&lt;/div&gt;';
                        return html;
                    }

                    /* External Reference Links — render each URL as a clickable link.
                       target=_blank with rel=noopener for safety since URLs come from data. */
                    function renderReferencesCard(app) {
                        var html = '&lt;div class="eas-card"&gt;';
                        html += '&lt;h2 class="eas-card-title"&gt;&lt;i class="fa fa-external-link" aria-hidden="true"&gt;&lt;/i&gt;External References&lt;/h2&gt;';
                        html += '&lt;div class="eas-card-section"&gt;';
                        if (app.externalLinks &amp;&amp; app.externalLinks.length &gt; 0) {
                            html += '&lt;ul&gt;';
                            for (var li = 0; li &lt; app.externalLinks.length; li++) {
                                var raw  = safeStr(app.externalLinks[li].url);
                                var safe = safeUrl(raw);
                                if (safe) {
                                    /* href uses the sanitised URL so disallowed schemes
                                       (javascript:, data:, ...) cannot fire; the visible
                                       label preserves what was originally entered. */
                                    html += '&lt;li&gt;&lt;a href="' + escapeHtml(safe) + '" target="_blank" rel="noopener noreferrer"&gt;' +
                                            escapeHtml(raw) + '&lt;/a&gt;&lt;/li&gt;';
                                }
                            }
                            html += '&lt;/ul&gt;';
                        } else {
                            html += '&lt;p class="eas-none"&gt;None recorded&lt;/p&gt;';
                        }
                        html += '&lt;/div&gt;';
                        html += '&lt;/div&gt;';
                        return html;
                    }
                </script>
            </head>
            <body>
                <xsl:call-template name="Heading"/>

                <main class="eas-sum-wrapper">

                    <a class="eas-back-link" href="report?XML=reportXML.xml&amp;XSL=user/nyu_app_dash_views/cio_app_portfolio_table_charts_v20.xsl&amp;cl=en-gb">
                        <i class="fa fa-arrow-left" aria-hidden="true"></i>&#160;Back to Application Atlas
                    </a>

                    <div id="appContent" aria-live="polite" aria-busy="true">
                        <div class="eas-loading" role="status">
                            <i class="fa fa-spinner fa-pulse fa-2x" aria-hidden="true"></i>
                            &#160;Loading application details&#8230;
                        </div>
                    </div>

                </main>

                <xsl:call-template name="Footer"/>
            </body>
        </html>
    </xsl:template>

</xsl:stylesheet>
