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

    <!-- ── Cost lookup keys ────────────────────────────────────────────────
         Replace per-app linear scans with O(1) key() lookups. Two keys cover
         both slot spellings used across deployments; a third resolves cost
         component IDs to their simple_instance elements. -->
    <xsl:key name="costByElem"    match="simple_instance[type='Cost']" use="own_slot_value[slot_reference='costs_for_element']/value"/>
    <xsl:key name="costByElemAlt" match="simple_instance[type='Cost']" use="own_slot_value[slot_reference='cost_for_elements']/value"/>
    <xsl:key name="instById"      match="simple_instance"               use="name"/>

    <!-- OWASP A03 — escape arbitrary text for safe insertion into a JS double-quoted string literal.
         JS literals emitted by this stylesheet always use double quotes, so apostrophes pass through. -->
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
        <html lang="en">
            <head>
                <xsl:call-template name="commonHeadContent"/>
                <xsl:call-template name="RenderModalReportContent">
                    <xsl:with-param name="essModalClassNames" select="$linkClasses"/>
                </xsl:call-template>

                <title>Application Atlas</title>

                <style>
                    /* ── Layout ─────────────────────────────────────────── */
                    .eas-tbl-wrapper {
                        padding: 16px 20px;
                        max-width: none;
                        margin: 10px 0 40px 0;
                        font-family: 'Open Sans', Helvetica, Arial, sans-serif;
                    }
                    .eas-tbl-header { margin-bottom: 24px; }
                    .eas-tbl-header h2 {
                        margin: 0 0 4px 0;
                        font-size: 24px;
                        font-weight: 600;
                        color: #2c3e50;
                    }
                    .eas-tbl-subtitle { margin: 0; color: #455a64; font-size: 14px; }

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
                    @media (max-width: 767px),
                           (pointer: coarse) and (orientation: landscape) and (max-height: 500px) {
                        .eas-kpi-hide-mobile { display: none; }
                    }

                    /* Pie chart override for KPI tiles */
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

                    /* ── Column Dropdown ────────────────────────────────── */
                    .eas-col-menu-item {
                        display: block;
                        padding: 6px 16px;
                        font-size: 13px;
                        color: #333;
                        cursor: pointer;
                        user-select: none;
                    }
                    .eas-col-menu-item:hover { background: #f8fafc; }
                    .eas-col-menu-item input { margin-right: 8px; cursor: pointer; }

                    /* ── Table toolbar ──────────────────────────────────── */
                    .eas-tbl-toolbar {
                        display: flex;
                        align-items: center;
                        justify-content: space-between;
                        margin-bottom: 16px;
                        gap: 12px;
                        flex-wrap: wrap;
                    }
                    .eas-tbl-search {
                        flex: 1;
                        max-width: 360px;
                        padding: 8px 12px;
                        border: 1px solid #757575;
                        border-radius: 6px;
                        font-size: 14px;
                        outline: none;
                    }
                    .eas-tbl-search:focus { border-color: #337ab7; box-shadow: 0 0 0 2px rgba(51,122,183,0.2); }
                    .eas-tbl-count { font-size: 13px; color: #455a64; white-space: nowrap; }
                    .eas-export-btn {
                        padding: 8px 16px;
                        background: #337ab7;
                        color: #fff;
                        border: none;
                        border-radius: 6px;
                        font-size: 13px;
                        cursor: pointer;
                        white-space: nowrap;
                    }
                    .eas-export-btn:hover { background: #286090; }

                    /* ── Left filter panel ──────────────────────────────── */
                    .eas-layout-row {
                        display: flex;
                        gap: 20px;
                        align-items: flex-start;
                        transition: gap 0.22s ease;
                    }
                    .eas-layout-row:has(.eas-filter-panel.collapsed) { gap: 8px; }
                    .eas-filter-panel {
                        width: 220px;
                        flex-shrink: 0;
                        background: #fff;
                        border-radius: 8px;
                        box-shadow: 0 2px 8px rgba(0,0,0,0.08);
                        padding: 18px 16px;
                        transition: width 0.22s ease, padding 0.22s ease;
                        overflow: hidden;
                        position: relative;
                    }
                    .eas-filter-panel.collapsed {
                        width: 36px;
                        padding: 10px 6px;
                    }

                    /* Toggle button — always visible */
                    .eas-filter-toggle-btn {
                        display: flex;
                        align-items: center;
                        justify-content: center;
                        width: 24px;
                        height: 24px;
                        background: #ecf0f1;
                        border: 1px solid #888;
                        border-radius: 4px;
                        cursor: pointer;
                        font-size: 13px;
                        color: #455a64;
                        flex-shrink: 0;
                        margin-left: auto;
                        margin-bottom: 10px;
                        padding: 0;
                        line-height: 1;
                    }
                    .eas-filter-toggle-btn:hover { background: #dde3e8; color: #2c3e50; }
                    .eas-filter-panel.collapsed .eas-filter-toggle-btn {
                        margin-left: 0;
                        margin-bottom: 0;
                    }

                    /* Header row: icon+label left, toggle button right */
                    .eas-filter-panel-header {
                        display: flex;
                        align-items: center;
                        margin-bottom: 14px;
                        padding-bottom: 8px;
                        border-bottom: 2px solid #ecf0f1;
                        gap: 6px;
                        white-space: nowrap;
                    }
                    .eas-filter-panel.collapsed .eas-filter-panel-header {
                        border-bottom: none;
                        margin-bottom: 0;
                        padding-bottom: 0;
                        flex-direction: column;
                        align-items: center;
                        gap: 0;
                    }
                    .eas-filter-panel-title {
                        margin: 0;
                        font-size: 12px;
                        font-weight: 700;
                        color: #455a64;
                        text-transform: uppercase;
                        letter-spacing: 0.07em;
                        flex: 1;
                        overflow: hidden;
                    }
                    .eas-filter-panel.collapsed .eas-filter-panel-title { display: none; }

                    /* Body: all filters + clear button */
                    .eas-filter-panel-body {
                        overflow: hidden;
                        opacity: 1;
                        visibility: visible;
                        transition: opacity 0.15s ease, visibility 0s linear 0s;
                    }
                    .eas-filter-panel.collapsed .eas-filter-panel-body {
                        opacity: 0;
                        pointer-events: none;
                        height: 0;
                        visibility: hidden;
                        transition: opacity 0.15s ease, visibility 0s linear 0.15s;
                    }

                    .eas-filter-group {
                        margin-bottom: 12px;
                    }
                    .eas-filter-group label {
                        display: block;
                        font-size: 11px;
                        font-weight: 700;
                        color: #455a64;
                        text-transform: uppercase;
                        letter-spacing: 0.04em;
                        margin-bottom: 4px;
                    }
                    .eas-filter-input {
                        width: 100%;
                        padding: 6px 8px;
                        border: 1px solid #757575;
                        border-radius: 4px;
                        font-size: 12px;
                        box-sizing: border-box;
                        font-weight: normal;
                        outline: none;
                        color: #333;
                        background: #fff;
                    }
                    .eas-filter-input:focus { border-color: #337ab7; box-shadow: 0 0 0 2px rgba(51,122,183,0.2); }
                    .eas-filter-select { cursor: pointer; }

                    /* Multi-select checkbox filter (lifecycle status, etc.) */
                    .eas-filter-checkbox-group {
                        display: flex;
                        flex-direction: column;
                        gap: 2px;
                        max-height: 220px;
                        overflow-y: auto;
                        padding: 6px 8px;
                        border: 1px solid #757575;
                        border-radius: 4px;
                        background: #fff;
                    }
                    .eas-filter-checkbox-item {
                        display: flex;
                        align-items: center;
                        gap: 6px;
                        font-size: 12px;
                        color: #333;
                        font-weight: normal;
                        margin: 0;
                        padding: 2px 0;
                        cursor: pointer;
                        text-transform: none;
                        letter-spacing: normal;
                    }
                    .eas-filter-checkbox-item input {
                        margin: 0;
                        cursor: pointer;
                        flex-shrink: 0;
                    }
                    .eas-filter-checkbox-item.is-excluded-by-default {
                        color: #6c757d;
                    }
                    .eas-filter-checkbox-actions {
                        display: flex;
                        gap: 6px;
                        margin-top: 4px;
                    }
                    .eas-filter-checkbox-actions button {
                        flex: 1;
                        padding: 4px 6px;
                        background: #f8fafc;
                        color: #455a64;
                        border: 1px solid #757575;
                        border-radius: 4px;
                        font-size: 11px;
                        font-weight: 600;
                        cursor: pointer;
                    }
                    .eas-filter-checkbox-actions button:hover { background: #ecf0f1; color: #2c3e50; }
                    .eas-filter-checkbox-actions button:focus-visible {
                        outline: 3px solid #ffbf47;
                        outline-offset: 2px;
                    }
                    .eas-filter-clear-btn {
                        width: 100%;
                        margin-top: 6px;
                        padding: 7px 0;
                        background: #f8fafc;
                        color: #455a64;
                        border: 1px solid #757575;
                        border-radius: 4px;
                        font-size: 12px;
                        font-weight: 600;
                        cursor: pointer;
                        text-align: center;
                    }
                    .eas-filter-clear-btn:hover { background: #ecf0f1; color: #2c3e50; }

                    /* ── Table section ──────────────────────────────────── */
                    .eas-table-section { flex: 1; min-width: 0; }

                    /* ── Bottom custom scrollbar (sticky to viewport bottom) ─ */
                    .eas-tbl-scroll-bottom {
                        overflow: hidden;
                        height: 16px;
                        margin-top: 4px;
                        border-radius: 4px;
                        background: #ecf0f1;
                        position: sticky;
                        bottom: 0;
                        z-index: 5;
                        cursor: pointer;
                        box-shadow: 0 -2px 6px rgba(0,0,0,0.08);
                    }
                    .eas-tbl-scroll-thumb {
                        position: absolute;
                        top: 3px;
                        left: 0;
                        height: 10px;
                        background: #607d8b;
                        border-radius: 5px;
                        cursor: grab;
                        min-width: 24px;
                        user-select: none;
                        transition: background 0.15s;
                    }
                    .eas-tbl-scroll-thumb:hover { background: #455a64; }
                    .eas-tbl-scroll-thumb.dragging { background: #455a64; cursor: grabbing; }
                    @media (pointer: coarse) { .eas-tbl-scroll-bottom { display: none; } }

                    /* ── Hide native horizontal scrollbar (custom one is below) ─ */
                    .eas-tbl-card::-webkit-scrollbar {
                        height: 0;
                        -webkit-appearance: none;
                    }
                    /* Firefox */
                    .eas-tbl-card {
                        scrollbar-width: none;
                    }
                    /* On touch devices, show native scrollbar since custom is hidden */
                    @media (pointer: coarse) {
                        .eas-tbl-card::-webkit-scrollbar { height: 14px; }
                        .eas-tbl-card::-webkit-scrollbar-track { background: #ecf0f1; border-radius: 4px; }
                        .eas-tbl-card::-webkit-scrollbar-thumb { background: #607d8b; border-radius: 4px; border: 2px solid #ecf0f1; }
                        .eas-tbl-card { scrollbar-width: thin; scrollbar-color: #607d8b #ecf0f1; }
                    }

                    .eas-tbl-card {
                        background: #fff;
                        border-radius: 8px;
                        box-shadow: 0 2px 8px rgba(0,0,0,0.08);
                        overflow-x: scroll;
                        scrollbar-gutter: stable;
                    }
                    .eas-app-table {
                        width: 100%;
                        border-collapse: collapse;
                        font-size: 13px;
                    }
                    .eas-app-table thead th {
                        background: #2c3e50;
                        color: #fff;
                        padding: 10px 10px;
                        text-align: left;
                        font-weight: 600;
                        white-space: nowrap;
                        cursor: pointer;
                        user-select: none;
                        position: sticky;
                        top: 0;
                        z-index: 1;
                    }
                    .eas-app-table thead th:hover { background: #3d5166; }
                    .eas-app-table thead th .sort-icon {
                        margin-left: 6px;
                        opacity: 0.5;
                        font-size: 11px;
                    }
                    .eas-app-table thead th.sort-asc .sort-icon,
                    .eas-app-table thead th.sort-desc .sort-icon { opacity: 1; }
                    .eas-app-table tbody tr { border-bottom: 1px solid #f0f0f0; }
                    .eas-app-table tbody tr:hover { background: #f8fafc; }
                    .eas-app-table tbody td { padding: 8px 10px; vertical-align: middle; }
                    .eas-app-table tbody td.app-name a { color: #337ab7; text-decoration: none; font-weight: 500; }
                    .eas-app-table tbody td.app-name a:hover { text-decoration: underline; }
                    .eas-app-table tbody td.app-desc {
                        max-width: 220px;
                        color: #444;
                        white-space: normal;
                        word-wrap: break-word;
                    }
                    .eas-app-table tbody td.app-supplier {
                        max-width: 160px;
                        white-space: normal;
                        word-wrap: break-word;
                    }
                    .eas-app-table .no-results td {
                        text-align: center;
                        padding: 40px;
                        color: #455a64;
                        font-style: italic;
                    }

                    /* ── Badges ─────────────────────────────────────────── */
                    .eas-badge {
                        display: inline-block;
                        padding: 3px 10px;
                        border-radius: 12px;
                        font-size: 12px;
                        font-weight: 600;
                        color: #fff;
                        white-space: nowrap;
                    }
                    .badge-crit-mission  { background: #c62828; }
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
                    /* Integration Complexity badges */
                    .badge-intcx-none { background: #555555; }
                    .badge-intcx-low  { background: #246d27; }
                    .badge-intcx-mod  { background: #7a5500; }
                    .badge-intcx-high { background: #c62828; }

                    /* Lifecycle Status badges */
                    .badge-lc-active  { background: #246d27; }
                    .badge-lc-dev     { background: #1565c0; }
                    .badge-lc-sunset  { background: #7a5500; }
                    .badge-lc-retired { background: #555555; }
                    .badge-lc-hold    { background: #5d4037; color: #fff; }
                    .badge-lc-other   { background: #455a64; }

                    /* ── Loading ────────────────────────────────────────── */
                    .eas-loading { text-align: center; padding: 60px; color: #455a64; font-size: 16px; }

                    /* ── WCAG 2.1: visible focus indicators (2.4.7) ─────── */
                    .eas-app-table thead th:focus-visible,
                    .eas-pie-chart:focus-visible,
                    .eas-tbl-search:focus-visible,
                    .eas-filter-input:focus-visible,
                    .eas-export-btn:focus-visible,
                    .eas-filter-clear-btn:focus-visible,
                    #colToggleBtn:focus-visible,
                    .eas-col-menu-item input:focus-visible,
                    .eas-filter-checkbox-item input:focus-visible,
                    .eas-filter-toggle-btn:focus-visible {
                        outline: 3px solid #ffbf47;
                        outline-offset: 2px;
                    }
                    .eas-app-table tbody td.app-name a:focus-visible {
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

                    /* ── WCAG 2.1: em-dash placeholder readable (1.4.3) ── */
                    .eas-empty-cell { color: #6c757d; }

                    /* ── Cost column: right-align with tabular-figure numerals ── */
                    .eas-app-table td.eas-cost-cell,
                    .eas-app-table th[data-col="cost"] {
                        text-align: right;
                        font-variant-numeric: tabular-nums;
                        white-space: nowrap;
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

                    /* ── Security Classifications Map ────────────────────── */
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

                    /* ── App→Supplier Mapping: app instance ID → [supplier IDs] ──
                       Mirrors appSecMapping; resolved at runtime in buildViewModel. */
                    var appSupplierMapping = {
                        <xsl:for-each select="/node()/simple_instance[(type='Application_Provider' or type='Composite_Application_Provider') and own_slot_value[slot_reference='ap_supplier']]">
                            "<xsl:value-of select="jsesc:str(name)"/>": [<xsl:for-each select="own_slot_value[slot_reference='ap_supplier']/value">"<xsl:value-of select="jsesc:str(.)"/>"<xsl:if test="position() != last()">,</xsl:if></xsl:for-each>]<xsl:if test="position() != last()">,</xsl:if>
                        </xsl:for-each>
                    };

                    /* ── Default currency symbol (Report_Constant 'Default Currency' → currency_symbol) ── */
                    <xsl:variable name="defaultCurrencyConstant" select="/node()/simple_instance[(type='Report_Constant') and (own_slot_value[slot_reference='name']/value = 'Default Currency')]"/>
                    <xsl:variable name="defaultCurrency" select="/node()/simple_instance[name = $defaultCurrencyConstant/own_slot_value[slot_reference='report_constant_ea_elements']/value]"/>
                    <xsl:variable name="defaultCurrencySymbol" select="string($defaultCurrency/own_slot_value[slot_reference='currency_symbol']/value)"/>
                    var defaultCurrencySymbol = "<xsl:value-of select="jsesc:str(if (string-length($defaultCurrencySymbol) > 0) then $defaultCurrencySymbol else '$')"/>";

                    /* ── App→Cost Mapping: app instance ID → total cost (numeric) ──
                       Sums cc_cost_amount across all Cost_Components reachable from
                       Cost instances whose costs_for_element/cost_for_elements slot references the app.
                       Tries both slot spellings since deployments vary.
                       Computed server-side using xsl:key indexes to avoid per-app linear scans. */
                    var appCostMapping = {
                        <xsl:for-each select="/node()/simple_instance[(type='Application_Provider' or type='Composite_Application_Provider')]">
                            <xsl:variable name="appName" select="name"/>
                            <!-- Costs referencing this app, via either slot spelling -->
                            <xsl:variable name="appCosts" select="key('costByElem', $appName) | key('costByElemAlt', $appName)"/>
                            <xsl:if test="$appCosts">
                                <xsl:variable name="compIds" select="$appCosts/own_slot_value[slot_reference='cost_components']/value"/>
                                <xsl:variable name="appCostComps" select="key('instById', $compIds)"/>
                                <xsl:variable name="currentComps" select="$appCostComps[costfn:is-current(.)]"/>
                                <xsl:variable name="totalCost" select="sum($currentComps/own_slot_value[slot_reference='cc_cost_amount']/value[. > 0])"/>
                                <xsl:if test="$totalCost > 0">"<xsl:value-of select="jsesc:str($appName)"/>": <xsl:value-of select="$totalCost"/>,
                                </xsl:if>
                            </xsl:if>
                        </xsl:for-each>
                        "_eas_cost_sentinel_": 0
                    };

                    /* ── Helpers ─────────────────────────────────────────── */
                    function safeStr(val) {
                        if (val == null) { return ''; }
                        return String(val).trim();
                    }

                    /* OWASP A03 — HTML escape for innerHTML interpolation */
                    function escapeHtml(s) {
                        return String(s == null ? '' : s)
                            .replace(/&amp;/g, '&amp;amp;')
                            .replace(/"/g, '&amp;quot;')
                            .replace(/'/g, '&amp;#39;')
                            .replace(/&lt;/g, '&amp;lt;')
                            .replace(/&gt;/g, '&amp;gt;');
                    }

                    /* Format a numeric cost as currency-prefixed thousand-separated string. */
                    function formatCost(n) {
                        var num = Number(n);
                        if (!num || isNaN(num) || num &lt;= 0) { return ''; }
                        return defaultCurrencySymbol + num.toLocaleString('en-US', { maximumFractionDigits: 0 });
                    }

                    /* OWASP A03 — defuse CSV/spreadsheet formula injection */
                    function csvSafe(s) {
                        var v = String(s == null ? '' : s);
                        if (/^[=+\-@\t\r]/.test(v)) { v = "'" + v; }
                        return '"' + v.replace(/"/g, '""') + '"';
                    }

                    /* ── API handles ─────────────────────────────────────── */
                    let busCapAppMartApps, orgSummary;

                    /* ── View model ──────────────────────────────────────── */
                    var viewModel = {
                        summary: {
                            totalApplications:    0,
                            highCriticalityCount: 0,
                            highSensitivityCount: 0,
                            ssoProtectedCount:    0
                        },
                        applications: []
                    };

                    /* ── Sort state ──────────────────────────────────────── */
                    var sortCol = 'name';
                    var sortDir = 'asc';

                    /* ── Cached DOM refs (populated after DOMReady) ──────── */
                    /* Perf: avoid getElementById/querySelector per render. */
                    var dom = {};
                    var thByCol = {};            /* col → &lt;th&gt; element */
                    var filterGroupByCol = {};   /* col → filter-panel group element */
                    var filterInputs = [];       /* cached NodeList for col filters */
                    var lifecycleCheckboxes = []; /* populated after populateLifecycleFilter() */
                    function cacheDomRefs() {
                        dom.appSearch     = document.getElementById('appSearch');
                        dom.kpiTiles      = document.getElementById('kpiTiles');
                        dom.tbody         = document.getElementById('appTableBody');
                        dom.rowCount      = document.getElementById('rowCount');
                        dom.colMenu       = document.getElementById('colToggleMenu');
                        dom.lifecycleContainer = document.getElementById('lifecycleCheckboxes');
                        var ths = document.querySelectorAll('.eas-app-table thead th[data-col]');
                        for (var i = 0; i &lt; ths.length; i++) {
                            thByCol[ths[i].getAttribute('data-col')] = ths[i];
                        }
                        var groups = document.querySelectorAll('.eas-filter-panel div[data-filter-group]');
                        for (var g = 0; g &lt; groups.length; g++) {
                            filterGroupByCol[groups[g].getAttribute('data-filter-group')] = groups[g];
                        }
                        filterInputs = document.querySelectorAll('.eas-filter-input');
                    }

                    /* ── Entry point ─────────────────────────────────────── */
                    $(document).ready(function () {
                        var apiList = ['busCapAppMartApps', 'orgSummary'];

                        async function executeFetchAndRender() {
                            try {
                                var responses = await fetchAndRenderData(apiList);
                                ({ busCapAppMartApps, orgSummary } = responses);
                                buildViewModel();
                                renderView();
                                var kpiEl = document.getElementById('kpiTiles');
                                if (kpiEl) { kpiEl.setAttribute('aria-busy', 'false'); }
                            } catch (err) {
                                console.error('[CIO Table] Error loading data:', err);
                                document.getElementById('kpiTiles').innerHTML =
                                    '&lt;div class="alert alert-danger" role="alert"&gt;' +
                                    '&lt;strong&gt;Error loading data.&lt;/strong&gt; Check the browser console.&lt;/div&gt;';
                                document.getElementById('kpiTiles').setAttribute('aria-busy', 'false');
                            }
                        }

                        executeFetchAndRender();
                    });

                    /* ════════════════════════════════════════════════════════
                       BUILD VIEW MODEL
                    ════════════════════════════════════════════════════════ */
                    function buildViewModel() {

                        /* 1. A2R index: { a2rId -> { actor, type, role } } */
                        var a2rIndex = {};
                        if (orgSummary &amp;&amp; orgSummary.a2rs) {
                            orgSummary.a2rs.forEach(function (a2r) {
                                if (a2r.id) {
                                    a2rIndex[a2r.id.trim()] = {
                                        actor: a2r.actor    || '',
                                        type:  a2r.type     || '',
                                        role:  a2r.role     || a2r.roleName || a2r.role_name || ''
                                    };
                                }
                            });
                        }

                        /* 2. Business criticality, lifecycle, and new enum indexes: { enumValueId -> enum_name } */
                        var criticalityIndex = {};
                        var lifecycleIndex = {};
                        var integrationComplexityIndex = {};
                        var userBaseIndex = {};
                        var userPopulationIndex = {};
                        if (busCapAppMartApps &amp;&amp; busCapAppMartApps.filters) {
                            var critFilter = null;
                            for (var fi = 0; fi &lt; busCapAppMartApps.filters.length; fi++) {
                                var f = busCapAppMartApps.filters[fi];
                                if (f.slotName === 'ap_business_criticality') {
                                    critFilter = f;
                                }
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

                        /* 3. SSO-protected app ID set */
                        var SSO_TERMS = ['oauth2', 'saml2', 'pam', 'entra'];
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

                            var sA2Rs = app.sA2R || [];
                            var buParts = [];
                            var itspParts = [];
                            var personParts = [];
                            for (var si = 0; si &lt; sA2Rs.length; si++) {
                                var a2rEntry = a2rIndex[(sA2Rs[si] || '').trim()];
                                if (a2rEntry &amp;&amp; a2rEntry.actor) {
                                    var label = a2rEntry.actor;
                                    if (a2rEntry.role) { label += ' (' + a2rEntry.role + ')'; }

                                    if (a2rEntry.type === 'Group_Actor') {
                                        buParts.push(label);
                                        if (a2rEntry.role &amp;&amp; a2rEntry.role.indexOf('ITSP') &gt;= 0) {
                                            itspParts.push(a2rEntry.actor);
                                        }
                                    } else if (a2rEntry.type === 'Individual_Actor') {
                                        personParts.push(label);
                                    }
                                }
                            }
                            var businessUnit      = buParts.length    &gt; 0 ? buParts.join(', ')    : 'Unassigned';
                            var itspUnit          = itspParts.length  &gt; 0 ? itspParts.join(', ')  : 'None';
                            var stakeholderPeople = personParts.length &gt; 0 ? personParts.join(', ') : 'None';

                            var critIds   = app.ap_business_criticality || [];
                            var firstCrit = critIds.length &gt; 0 ? critIds[0].trim() : null;
                            var businessCriticality = firstCrit
                                ? (criticalityIndex[firstCrit] || app.criticality || 'Unclassified')
                                : (app.criticality || 'Unclassified');

                            var lifecycleStatus = 'Active';
                            var lcIds = app.lifecycle_status_application_provider || [];
                            var lcLabel = null;
                            if (lcIds.length &gt; 0) {
                                lcLabel = lifecycleIndex[lcIds[0]];
                            }
                            if (!lcLabel &amp;&amp; app.lifecycle) {
                                lcLabel = lifecycleIndex[app.lifecycle] || app.lifecycle;
                            }
                            if (lcLabel) {
                                lifecycleStatus = lcLabel;
                            }

                            var appSecClasses = appSecMapping[appId] || app.securityClassifications || [];
                            var dataSensitivity = 'Unclassified';
                            for (var ci = 0; ci &lt; appSecClasses.length; ci++) {
                                var classId = safeStr(appSecClasses[ci]);
                                var classNameStr = secClassLookup[classId] || classId;
                                var cn = classNameStr.toLowerCase();
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

                            var ssoProtected = ssoAppIds[appId] === true;

                            var intCxIds = app['Integration Complexity'] || [];
                            var integrationComplexity = intCxIds.length &gt; 0
                                ? (integrationComplexityIndex[intCxIds[0].trim()] || 'Unknown')
                                : 'Unknown';

                            var userBaseIds = app['User Base'] || [];
                            var userBase = userBaseIds.length &gt; 0
                                ? (userBaseIndex[userBaseIds[0].trim()] || 'Unknown')
                                : 'Unknown';

                            var userPopIds = app['User Population'] || [];
                            var userPopParts = [];
                            for (var pi = 0; pi &lt; userPopIds.length; pi++) {
                                var lbl = userPopulationIndex[userPopIds[pi].trim()];
                                if (lbl) { userPopParts.push(lbl); }
                            }
                            var userPopulation = userPopParts.length &gt; 0 ? userPopParts.join(', ') : '';

                            /* Supplier — resolved from appSupplierMapping (XSL-emitted, built from
                               the ap_supplier slot) via supplierNameIndex (Supplier instances). */
                            var appSupIds = appSupplierMapping[appId] || [];
                            var supplierParts = [];
                            for (var spi = 0; spi &lt; appSupIds.length; spi++) {
                                var sName = supplierNameIndex[appSupIds[spi]];
                                if (sName) { supplierParts.push(sName); }
                            }
                            var supplier = supplierParts.join(', ');

                            /* Cost — total numeric, pre-summed at XSL render time. */
                            var costNum = Number(appCostMapping[appId]) || 0;
                            var costFormatted = formatCost(costNum);

                            /* Perf: pre-compute lowercased forms so filter/sort/search
                               does not call .toLowerCase() per row per keystroke. */
                            var nameVal = app.name || 'Unnamed Application';
                            var descVal = safeStr(app.description || app.ap_description || '');
                            return {
                                id:                      appId,
                                name:                    nameVal,
                                description:             descVal,
                                businessUnit:            businessUnit,
                                stakeholderPeople:       stakeholderPeople,
                                itspUnit:                itspUnit,
                                businessCriticality:     businessCriticality,
                                dataSensitivity:         dataSensitivity,
                                ssoProtected:            ssoProtected,
                                lifecycleStatus:         lifecycleStatus,
                                integrationComplexity:   integrationComplexity,
                                userBase:                userBase,
                                userPopulation:          userPopulation,
                                supplier:                supplier,
                                cost:                    costNum,
                                costFormatted:           costFormatted,
                                _nameLc:                 nameVal.toLowerCase(),
                                _descLc:                 descVal.toLowerCase(),
                                _buLc:                   businessUnit.toLowerCase(),
                                _peopleLc:               stakeholderPeople.toLowerCase(),
                                _itspLc:                 itspUnit.toLowerCase(),
                                _critLc:                 businessCriticality.toLowerCase(),
                                _sensLc:                 dataSensitivity.toLowerCase(),
                                _ssoLc:                  ssoProtected ? 'yes' : 'no',
                                _lcStatusLc:             lifecycleStatus.toLowerCase(),
                                _intCxLc:                integrationComplexity.toLowerCase(),
                                _ubLc:                   userBase.toLowerCase(),
                                _upLc:                   userPopulation.toLowerCase(),
                                _supplierLc:             supplier.toLowerCase(),
                                _costLc:                 costFormatted.toLowerCase()
                            };
                        });
                    }

                    /* Perf: map the public column name to the cached lowercased field. */
                    var COL_LC = {
                        name:                  '_nameLc',
                        description:           '_descLc',
                        businessUnit:          '_buLc',
                        stakeholderPeople:     '_peopleLc',
                        itspUnit:              '_itspLc',
                        businessCriticality:   '_critLc',
                        dataSensitivity:       '_sensLc',
                        ssoProtected:          '_ssoLc',
                        lifecycleStatus:       '_lcStatusLc',
                        integrationComplexity: '_intCxLc',
                        userBase:              '_ubLc',
                        userPopulation:        '_upLc',
                        supplier:              '_supplierLc',
                        cost:                  '_costLc'
                    };

                    /* ════════════════════════════════════════════════════════
                       RENDER
                    ════════════════════════════════════════════════════════ */
                    function renderView() {
                        cacheDomRefs();
                        populateItspFilter();
                        populateLifecycleFilter();
                        renderTable(viewModel.applications);
                        bindControls();
                    }

                    /* ── Populate Lifecycle Status checkbox filter ─────────────
                       Builds one checkbox per distinct lifecycle status found in
                       the data. Default state: every status checked EXCEPT those
                       containing "sunset" or "retired". Sunset/retired statuses
                       are sorted to the bottom of the list. */
                    function populateLifecycleFilter() {
                        var container = dom.lifecycleContainer;
                        if (!container) { return; }

                        var statusSet = {};
                        viewModel.applications.forEach(function (a) {
                            var s = a.lifecycleStatus || '';
                            if (s) { statusSet[s] = true; }
                        });

                        var statuses = Object.keys(statusSet).sort(function (a, b) {
                            var aLc = a.toLowerCase(), bLc = b.toLowerCase();
                            var aExc = aLc.indexOf('sunset') &gt;= 0 || aLc.indexOf('retired') &gt;= 0;
                            var bExc = bLc.indexOf('sunset') &gt;= 0 || bLc.indexOf('retired') &gt;= 0;
                            if (aExc !== bExc) { return aExc ? 1 : -1; }
                            return aLc.localeCompare(bLc);
                        });

                        var frag = document.createDocumentFragment();
                        statuses.forEach(function (s) {
                            var sLc = s.toLowerCase();
                            var isExcByDefault = sLc.indexOf('sunset') &gt;= 0 || sLc.indexOf('retired') &gt;= 0;
                            var lbl = document.createElement('label');
                            lbl.className = 'eas-filter-checkbox-item' + (isExcByDefault ? ' is-excluded-by-default' : '');
                            var cb = document.createElement('input');
                            cb.type = 'checkbox';
                            cb.value = s;
                            cb.checked = !isExcByDefault;
                            cb.setAttribute('data-lifecycle-checkbox', '');
                            cb.setAttribute('data-default-checked', String(!isExcByDefault));
                            lbl.appendChild(cb);
                            lbl.appendChild(document.createTextNode(' ' + s));
                            frag.appendChild(lbl);
                        });
                        container.appendChild(frag);
                        lifecycleCheckboxes = container.querySelectorAll('input[data-lifecycle-checkbox]');
                    }

                    /* ── Populate ITSP filter dropdown from data ─────────── */
                    function populateItspFilter() {
                        var select = document.getElementById('filter-itsp');
                        if (!select) { return; }

                        var itspSet = {};
                        var hasNone = false;
                        viewModel.applications.forEach(function (a) {
                            var val = a.itspUnit || '';
                            if (val === 'None' || val === '') { hasNone = true; return; }
                            var parts = val.split(',');
                            for (var i = 0; i &lt; parts.length; i++) {
                                var name = parts[i].trim();
                                if (name) { itspSet[name] = true; }
                            }
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
                            noneOpt.value = 'none';
                            noneOpt.textContent = 'None (unassigned)';
                            frag.appendChild(noneOpt);
                        }
                        select.appendChild(frag);
                    }

                    /* ── KPI tiles ─────────────────────────────────────────── */
                    function kpiTileHtml(color, icon, value, label, percentStr, multiPieObj, extraClass, pctMeta) {
                        var valHtml;
                        if (multiPieObj !== undefined &amp;&amp; multiPieObj !== null) {
                            var fullLabel = (label + ': ' + (multiPieObj.tooltip || '')).replace(/"/g, '&amp;quot;');
                            var titleAttr = ' aria-label="' + fullLabel + '" title="' + fullLabel + '"';
                            valHtml = '&lt;div class="eas-pie-chart" style="background: conic-gradient(' + multiPieObj.gradient + ');" role="img"' + titleAttr + '&gt;&lt;/div&gt;';
                            if (multiPieObj.subtitleHtml) {
                                valHtml += '&lt;div style="font-size:11px; color:#555; line-height:1.5; margin-bottom:8px;" aria-hidden="true"&gt;' + multiPieObj.subtitleHtml + '&lt;/div&gt;';
                            }
                        } else if (percentStr !== undefined &amp;&amp; percentStr !== null) {
                            var p = parseFloat(percentStr);
                            /* Single-percentage tile: when pctMeta {count, denom} is supplied,
                               render a colour-coded "count of denom (pct%)" subtitle in the
                               same visual rhythm as the multi-segment pies, and use the same
                               format for the accessible name and tooltip. */
                            var ariaText, subtitleHtml = '';
                            if (pctMeta &amp;&amp; typeof pctMeta.count === 'number' &amp;&amp; typeof pctMeta.denom === 'number') {
                                ariaText = (label + ': ' + pctMeta.count + ' of ' + pctMeta.denom + ' (' + p + '%)').replace(/"/g, '&amp;quot;');
                                subtitleHtml = '&lt;div aria-hidden="true" style="font-size:11px; color:#555; line-height:1.5; margin-bottom:8px;"&gt;' +
                                    '&lt;span style="white-space:nowrap"&gt;' +
                                    '&lt;span style="color:' + color + ';font-weight:600"&gt;' + pctMeta.count + '&lt;/span&gt;' +
                                    ' of ' + pctMeta.denom + ' (' + p + '%)' +
                                    '&lt;/span&gt;&lt;/div&gt;';
                            } else {
                                ariaText = (label + ': ' + p + '%').replace(/"/g, '&amp;quot;');
                            }
                            valHtml = '&lt;div class="eas-pie-chart" style="background: conic-gradient(' + color + ' ' + p + '%, #ecf0f1 0);" role="img" aria-label="' + ariaText + '" title="' + ariaText + '"&gt;&lt;/div&gt;' + subtitleHtml;
                        } else {
                            valHtml = '&lt;div class="eas-kpi-value"&gt;' + value + '&lt;/div&gt;';
                        }

                        return '&lt;div class="eas-kpi-tile' + (extraClass ? ' ' + extraClass : '') + '" style="border-top:4px solid ' + color + '"&gt;' +
                               '&lt;div class="eas-kpi-icon" aria-hidden="true"&gt;&lt;i class="fa ' + icon + '" style="color:' + color + '"&gt;&lt;/i&gt;&lt;/div&gt;' +
                               valHtml +
                               '&lt;div class="eas-kpi-label"&gt;' + label + '&lt;/div&gt;' +
                               '&lt;/div&gt;';
                    }

                    /* Perf: shared pie builder. rawSegs entries carry counts; this turns
                       them into percentages and emits the conic-gradient strings.
                       Legend, tooltip, and a11y readout all show "label: count (pct%)". */
                    function buildPie(rawSegs, total) {
                        if (!total) { return null; }
                        var segs = [];
                        for (var i = 0; i &lt; rawSegs.length; i++) {
                            var r = rawSegs[i];
                            if (r.count &gt; 0) {
                                segs.push({ c: r.c, v: (r.count / total) * 100, n: r.count, l: r.l, s: r.s });
                            }
                        }
                        if (segs.length === 0) { return null; }
                        var grad = [], tt = [], subs = [];
                        var curDeg = 0;
                        var sep = segs.length &gt; 1 ? 0.8 : 0;
                        for (var j = 0; j &lt; segs.length; j++) {
                            var seg = segs[j];
                            var end = curDeg + seg.v;
                            grad.push(seg.c + ' ' + curDeg + '% ' + (end - sep) + '%');
                            if (sep &gt; 0) { grad.push('#fff ' + (end - sep) + '% ' + end + '%'); }
                            var pct = Math.round(seg.v);
                            var amount = seg.n + ' (' + pct + '%)';
                            tt.push(seg.l + ': ' + amount);
                            subs.push('&lt;span style="white-space:nowrap"&gt;&lt;span style="color:' + (seg.c === '#757575' ? '#555' : seg.c) + ';font-weight:600"&gt;' + seg.s + ':&lt;/span&gt; ' + amount + '&lt;/span&gt;');
                            curDeg = end;
                        }
                        return { gradient: grad.join(', '), tooltip: tt.join(' | '), subtitleHtml: subs.join(' | ') };
                    }

                    function renderKpiTiles(apps) {
                        var _apps = apps || viewModel.applications;

                        /* Perf: single pass replaces 8 separate Array.filter() walks. */
                        var total = _apps.length;
                        var critHigh = 0, critLow = 0;
                        var sensHigh = 0, sensModerate = 0, sensLow = 0, sensUnclass = 0;
                        var noItspCount = 0, ssoProtectedCount = 0;
                        for (var i = 0; i &lt; total; i++) {
                            var a = _apps[i];
                            var v = a._critLc;
                            if (v.indexOf('mission') &gt;= 0 || (v.indexOf('critical') &gt;= 0 &amp;&amp; v.indexOf('not') &lt; 0)) {
                                critHigh++;
                            } else if (v.indexOf('not') &gt;= 0 || v === 'low' || v === 'medium') {
                                critLow++;
                            }
                            switch (a.dataSensitivity) {
                                case 'High':         sensHigh++;     break;
                                case 'Moderate':     sensModerate++; break;
                                case 'Low':          sensLow++;      break;
                                case 'Unclassified': sensUnclass++;  break;
                            }
                            if (a.itspUnit === 'None') { noItspCount++; }
                            if (a.ssoProtected) { ssoProtectedCount++; }
                        }
                        var critUnclass = total - (critHigh + critLow);

                        var s = {
                            totalApplications: total,
                            critHigh: critHigh, critLow: critLow, critUnclass: critUnclass,
                            sensHigh: sensHigh, sensModerate: sensModerate, sensLow: sensLow, sensUnclass: sensUnclass,
                            noItspCount: noItspCount, ssoProtectedCount: ssoProtectedCount
                        };

                        var ssoPercent = total &gt; 0 ? Math.round((ssoProtectedCount / total) * 100) : 0;
                        var noItspPercent = total &gt; 0 ? Math.round((noItspCount / total) * 100) : 0;

                        var critPie = buildPie([
                            { c: '#c62828', count: critHigh,    l: 'Critical',     s: 'Critical' },
                            { c: '#246d27', count: critLow,     l: 'Not Critical', s: 'Not Critical' },
                            { c: '#757575', count: critUnclass, l: 'Unclassified', s: 'Unclassified' }
                        ], total);

                        var sensPie = buildPie([
                            { c: '#c62828', count: sensHigh,     l: 'High',         s: 'High' },
                            { c: '#7a5500', count: sensModerate, l: 'Moderate',     s: 'Mod' },
                            { c: '#246d27', count: sensLow,      l: 'Low',          s: 'Low' },
                            { c: '#757575', count: sensUnclass,  l: 'Unclassified', s: 'Unclassified' }
                        ], total);

                        document.getElementById('kpiTiles').innerHTML =
                            '&lt;div class="eas-kpi-row"&gt;' +
                            kpiTileHtml('#1976d2', 'fa-th-large',          s.totalApplications,   'Total Applications') +
                            kpiTileHtml('#c62828', 'fa-pie-chart',         null,
                                'Business Criticality Breakdown', null, critPie) +
                            kpiTileHtml('#607d8b', 'fa-pie-chart',         null,
                                'Data Sensitivity Breakdown', null, sensPie) +
                            kpiTileHtml('#c62828', 'fa-user-times',        null,
                                'No ITSP Assigned', noItspPercent, null, 'eas-kpi-hide-mobile',
                                { count: s.noItspCount, denom: s.totalApplications }) +
                            kpiTileHtml('#246d27', 'fa-shield',            null,
                                'SSO Protected', ssoPercent, null, null,
                                { count: s.ssoProtectedCount, denom: s.totalApplications }) +
                            '&lt;/div&gt;';
                    }

                    /* ── Badge helpers ─────────────────────────────────────── */
                    function critBadge(val) {
                        var v = val.toLowerCase();
                        var cls = 'badge-crit-none';
                        if (v.indexOf('mission') &gt;= 0)                            { cls = 'badge-crit-mission'; }
                        else if (v.indexOf('critical') &gt;= 0 &amp;&amp; v.indexOf('not') &lt; 0) { cls = 'badge-crit-critical'; }
                        else if (v === 'medium')                                   { cls = 'badge-crit-medium'; }
                        else if (v.indexOf('not') &gt;= 0 || v === 'low')            { cls = 'badge-crit-notcrit'; }
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

                    function intComplexityBadge(val) {
                        var v = val.toLowerCase();
                        var cls = v.indexOf('high')     &gt;= 0 ? 'badge-intcx-high' :
                                  v.indexOf('moderate') &gt;= 0 ? 'badge-intcx-mod'  :
                                  v.indexOf('low')      &gt;= 0 ? 'badge-intcx-low'  :
                                  v === 'none'                ? 'badge-intcx-none' : 'badge-intcx-none';
                        return '&lt;span class="eas-badge ' + cls + '"&gt;' + escapeHtml(val) + '&lt;/span&gt;';
                    }

                    function lcStatusBadge(val) {
                        var v = val.toLowerCase();
                        var cls = (v.indexOf('active') &gt;= 0 || v === 'production') ? 'badge-lc-active' :
                                  (v.indexOf('develop') &gt;= 0 || v.indexOf('plan') &gt;= 0) ? 'badge-lc-dev'    :
                                  (v.indexOf('sunset') &gt;= 0)                              ? 'badge-lc-sunset' :
                                  (v.indexOf('retir') &gt;= 0)                               ? 'badge-lc-retired' :
                                  (v.indexOf('hold') &gt;= 0)                                ? 'badge-lc-hold'   : 'badge-lc-other';
                        return '&lt;span class="eas-badge ' + cls + '"&gt;' + escapeHtml(val) + '&lt;/span&gt;';
                    }


                    /* ── Sort ──────────────────────────────────────────────── */
                    /* Perf: read pre-lowercased field via COL_LC; comparator does no work per call. */
                    function sortApps(apps, col, dir) {
                        var lcKey = (col === 'ssoProtected' || col === 'cost') ? null : (COL_LC[col] || null);
                        var asc = dir === 'asc' ? 1 : -1;
                        return apps.slice().sort(function (a, b) {
                            var av, bv;
                            if (col === 'ssoProtected') {
                                av = a.ssoProtected ? 1 : 0;
                                bv = b.ssoProtected ? 1 : 0;
                            } else if (col === 'cost') {
                                av = Number(a.cost) || 0;
                                bv = Number(b.cost) || 0;
                            } else if (lcKey) {
                                av = a[lcKey] || '';
                                bv = b[lcKey] || '';
                            } else {
                                av = (a[col] || '').toString().toLowerCase();
                                bv = (b[col] || '').toString().toLowerCase();
                            }
                            if (av &lt; bv) { return -asc; }
                            if (av &gt; bv) { return  asc; }
                            return 0;
                        });
                    }

                    /* ── Visible Columns Helper ────────────────────────────── */
                    function getVisibleColumns() {
                        var visibleCols = { name: true, description: true, businessUnit: true, stakeholderPeople: true, itspUnit: true, businessCriticality: true, dataSensitivity: true, ssoProtected: true, lifecycleStatus: false, integrationComplexity: true, userBase: true, userPopulation: true, supplier: false, cost: false };
                        var colMenu = document.getElementById('colToggleMenu');
                        if (colMenu) {
                            var cbs = colMenu.querySelectorAll('input[type="checkbox"]');
                            for (var c = 0; c &lt; cbs.length; c++) {
                                visibleCols[cbs[c].value] = cbs[c].checked;
                            }
                        }
                        return visibleCols;
                    }

                    /* ── Table render ──────────────────────────────────────── */
                    function renderTable(apps) {
                        /* Perf: compute visibleCols once and pass through to filterApps. */
                        var visibleCols = getVisibleColumns();

                        var term     = dom.appSearch ? dom.appSearch.value : '';
                        var filtered = filterApps(apps, term, visibleCols);
                        var sorted   = sortApps(filtered, sortCol, sortDir);

                        /* Update KPIs based on the filtered results */
                        renderKpiTiles(filtered);

                        /* Update column sort indicators (iterate cached th map only) */
                        for (var col0 in thByCol) {
                            if (!thByCol.hasOwnProperty(col0)) { continue; }
                            var th = thByCol[col0];
                            th.classList.remove('sort-asc', 'sort-desc');
                            var icon = th.querySelector('.sort-icon');
                            if (col0 === sortCol) {
                                th.classList.add(sortDir === 'asc' ? 'sort-asc' : 'sort-desc');
                                th.setAttribute('aria-sort', sortDir === 'asc' ? 'ascending' : 'descending');
                                if (icon) { icon.className = 'sort-icon fa fa-sort-' + (sortDir === 'asc' ? 'asc' : 'desc'); }
                            } else {
                                th.setAttribute('aria-sort', 'none');
                                if (icon) { icon.className = 'sort-icon fa fa-sort'; }
                            }
                        }

                        /* Update row count */
                        if (dom.rowCount) {
                            dom.rowCount.textContent = 'Showing ' + sorted.length + ' of ' + viewModel.applications.length + ' applications';
                        }

                        /* Sync column header and filter panel group visibility (cached maps) */
                        var visCount = 0;
                        for (var col in visibleCols) {
                            if (!visibleCols.hasOwnProperty(col)) { continue; }
                            var show = visibleCols[col];
                            if (show) { visCount++; }
                            var thEl = thByCol[col];
                            if (thEl) { thEl.style.display = show ? '' : 'none'; }
                            var fg = filterGroupByCol[col];
                            if (fg) { fg.style.display = show ? '' : 'none'; }
                        }

                        /* Build rows */
                        var tbody = dom.tbody;
                        if (!tbody) { return; }

                        if (sorted.length === 0) {
                            tbody.innerHTML = '&lt;tr class="no-results"&gt;&lt;td colspan="' + visCount + '"&gt;No applications match your search.&lt;/td&gt;&lt;/tr&gt;';
                            return;
                        }

                        var rows = '';
                        for (var ri = 0; ri &lt; sorted.length; ri++) {
                            var app = sorted[ri];
                            var descEscaped = app.description
                                .replace(/&amp;/g, '&amp;amp;')
                                .replace(/"/g, '&amp;quot;')
                                .replace(/&lt;/g, '&amp;lt;')
                                .replace(/&gt;/g, '&amp;gt;');

                            var idUrl  = encodeURIComponent(app.id);
                            var idAttr = escapeHtml(app.id);
                            var nameEsc = escapeHtml(app.name);
                            var rowHtml = '&lt;tr&gt;';
                            if (visibleCols.name) rowHtml += '&lt;td class="app-name"&gt;&lt;strong&gt;&lt;a href="report?XML=reportXML.xml&amp;XSL=user/nyu_app_dash_views/cio_app_provider_summary_v8.xsl&amp;PMA=' + idUrl + '&amp;cl=en-gb" class="context-menu-appProviderGenMenu context-menu-compositeAppProviderGenMenu" id="' + idAttr + '"&gt;' + nameEsc + '&lt;/a&gt;&lt;/strong&gt;&lt;/td&gt;';
                            if (visibleCols.description) rowHtml += '&lt;td class="app-desc" title="' + descEscaped + '"&gt;' + (app.description ? escapeHtml(app.description) : '&lt;span class="eas-empty-cell" aria-label="No description"&gt;—&lt;/span&gt;') + '&lt;/td&gt;';
                            if (visibleCols.businessUnit) rowHtml += '&lt;td&gt;' + (app.businessUnit ? escapeHtml(app.businessUnit) : '&lt;span class="eas-empty-cell" aria-label="No business unit"&gt;—&lt;/span&gt;') + '&lt;/td&gt;';
                            if (visibleCols.stakeholderPeople) rowHtml += '&lt;td&gt;' + (app.stakeholderPeople ? escapeHtml(app.stakeholderPeople) : '&lt;span class="eas-empty-cell" aria-label="No people"&gt;—&lt;/span&gt;') + '&lt;/td&gt;';
                            if (visibleCols.itspUnit) rowHtml += '&lt;td&gt;' + (app.itspUnit ? escapeHtml(app.itspUnit) : '&lt;span class="eas-empty-cell" aria-label="No ITSP"&gt;—&lt;/span&gt;') + '&lt;/td&gt;';
                            if (visibleCols.businessCriticality) rowHtml += '&lt;td&gt;' + critBadge(app.businessCriticality) + '&lt;/td&gt;';
                            if (visibleCols.dataSensitivity) rowHtml += '&lt;td&gt;' + sensBadge(app.dataSensitivity) + '&lt;/td&gt;';
                            if (visibleCols.ssoProtected) rowHtml += '&lt;td&gt;' + ssoBadge(app.ssoProtected) + '&lt;/td&gt;';
                            if (visibleCols.lifecycleStatus) rowHtml += '&lt;td&gt;' + lcStatusBadge(app.lifecycleStatus) + '&lt;/td&gt;';
                            if (visibleCols.integrationComplexity) rowHtml += '&lt;td&gt;' + (app.integrationComplexity &amp;&amp; app.integrationComplexity !== 'Unknown' ? intComplexityBadge(app.integrationComplexity) : '&lt;span class="eas-empty-cell" aria-label="Not set"&gt;—&lt;/span&gt;') + '&lt;/td&gt;';
                            if (visibleCols.userBase) rowHtml += '&lt;td&gt;' + (app.userBase &amp;&amp; app.userBase !== 'Unknown' ? escapeHtml(app.userBase) : '&lt;span class="eas-empty-cell" aria-label="Not set"&gt;—&lt;/span&gt;') + '&lt;/td&gt;';
                            if (visibleCols.userPopulation) rowHtml += '&lt;td&gt;' + (app.userPopulation ? escapeHtml(app.userPopulation) : '&lt;span class="eas-empty-cell" aria-label="Not set"&gt;—&lt;/span&gt;') + '&lt;/td&gt;';
                            if (visibleCols.supplier) rowHtml += '&lt;td class="app-supplier"&gt;' + (app.supplier ? escapeHtml(app.supplier) : '&lt;span class="eas-empty-cell" aria-label="Not set"&gt;—&lt;/span&gt;') + '&lt;/td&gt;';
                            if (visibleCols.cost) rowHtml += '&lt;td class="eas-cost-cell"&gt;' + (app.costFormatted ? escapeHtml(app.costFormatted) : '&lt;span class="eas-empty-cell" aria-label="No cost data"&gt;—&lt;/span&gt;') + '&lt;/td&gt;';
                            rowHtml += '&lt;/tr&gt;';
                            rows += rowHtml;
                        }
                        tbody.innerHTML = rows;
                        syncTableScrollWidth();
                    }

                    /* ── Filter ────────────────────────────────────────────── */
                    /* Perf:
                       - visibleCols passed in by renderTable so we don't re-query the DOM.
                       - filterInputs is the cached NodeList; no querySelectorAll per render.
                       - per-row work uses the pre-lowercased _xxLc fields (no String/toLowerCase). */
                    function filterApps(apps, term, visibleCols) {
                        if (!visibleCols) { visibleCols = getVisibleColumns(); }

                        /* Lifecycle status: read the checkbox group state.
                           Build a lowercased allow-set; if no boxes are checked, treat as
                           "all allowed" (show everything) — same UX convention as empty
                           text filters meaning "no filter applied". */
                        var allowedLcSet = {};
                        var anyLcChecked = false;
                        var allLcChecked = true;
                        for (var li = 0; li &lt; lifecycleCheckboxes.length; li++) {
                            if (lifecycleCheckboxes[li].checked) {
                                allowedLcSet[lifecycleCheckboxes[li].value.toLowerCase()] = true;
                                anyLcChecked = true;
                            } else {
                                allLcChecked = false;
                            }
                        }
                        var lcFilterActive = anyLcChecked &amp;&amp; !allLcChecked;

                        /* Build (col, lcKey, term) triples once */
                        var colFilters = [];
                        for (var i = 0; i &lt; filterInputs.length; i++) {
                            var raw = filterInputs[i].value;
                            if (!raw) { continue; }
                            var val = raw.trim().toLowerCase();
                            if (!val) { continue; }
                            var colAttr = filterInputs[i].getAttribute('data-filter-col');
                            if (!colAttr || !visibleCols[colAttr]) { continue; }
                            colFilters.push({
                                col:    colAttr,
                                lcKey:  COL_LC[colAttr],
                                term:   val,
                                isCritShortcut: (colAttr === 'businessCriticality' &amp;&amp; val === 'critical')
                            });
                        }

                        var hasTerm = !!(term &amp;&amp; term.trim());
                        var t = hasTerm ? term.toLowerCase() : '';

                        /* Pre-build the list of lc-keys that participate in the global search.
                           Only visible columns count, and we look them up once. */
                        var searchKeys = [];
                        if (hasTerm) {
                            var keys = ['name','description','businessUnit','stakeholderPeople','itspUnit',
                                        'businessCriticality','dataSensitivity','ssoProtected',
                                        'lifecycleStatus','integrationComplexity','userBase','userPopulation',
                                        'supplier','cost'];
                            for (var k = 0; k &lt; keys.length; k++) {
                                if (visibleCols[keys[k]]) { searchKeys.push(COL_LC[keys[k]]); }
                            }
                        }

                        var out = [];
                        for (var ai = 0; ai &lt; apps.length; ai++) {
                            var a = apps[ai];

                            if (lcFilterActive) {
                                if (!allowedLcSet[a._lcStatusLc]) { continue; }
                            }

                            var skip = false;
                            for (var ci = 0; ci &lt; colFilters.length; ci++) {
                                var f = colFilters[ci];
                                var cell = a[f.lcKey] || '';
                                if (f.isCritShortcut) {
                                    if (!(cell.indexOf('critical') &gt;= 0 &amp;&amp; cell.indexOf('not') &lt; 0)) { skip = true; break; }
                                } else if (cell.indexOf(f.term) &lt; 0) {
                                    skip = true; break;
                                }
                            }
                            if (skip) { continue; }

                            if (hasTerm) {
                                var match = false;
                                for (var sk = 0; sk &lt; searchKeys.length; sk++) {
                                    var v = a[searchKeys[sk]];
                                    if (v &amp;&amp; v.indexOf(t) &gt;= 0) { match = true; break; }
                                }
                                if (!match) { continue; }
                            }

                            out.push(a);
                        }
                        return out;
                    }

                    /* ── Wire controls ─────────────────────────────────────── */
                    /* Perf: debounce typed-input renders to coalesce keystrokes. */
                    function debounce(fn, ms) {
                        var t = null;
                        return function () {
                            if (t) { clearTimeout(t); }
                            t = setTimeout(function () { t = null; fn(); }, ms);
                        };
                    }
                    var rerender = function () { renderTable(viewModel.applications); };
                    var rerenderDebounced = debounce(rerender, 150);

                    function bindControls() {
                        /* Global search */
                        if (dom.appSearch) {
                            dom.appSearch.addEventListener('input', rerenderDebounced);
                        }

                        /* Lifecycle checkbox group — per-checkbox change re-renders */
                        for (var lci = 0; lci &lt; lifecycleCheckboxes.length; lci++) {
                            lifecycleCheckboxes[lci].addEventListener('change', rerender);
                        }

                        /* Lifecycle quick-action buttons */
                        function setLifecycleAll(state) {
                            for (var i = 0; i &lt; lifecycleCheckboxes.length; i++) {
                                lifecycleCheckboxes[i].checked = state;
                            }
                            rerender();
                        }
                        function setLifecycleDefault() {
                            for (var i = 0; i &lt; lifecycleCheckboxes.length; i++) {
                                lifecycleCheckboxes[i].checked = lifecycleCheckboxes[i].getAttribute('data-default-checked') === 'true';
                            }
                            rerender();
                        }
                        var btnAll  = document.getElementById('lifecycleCheckAll');
                        var btnNone = document.getElementById('lifecycleCheckNone');
                        var btnDef  = document.getElementById('lifecycleCheckDefault');
                        if (btnAll)  { btnAll.addEventListener('click',  function () { setLifecycleAll(true);  }); }
                        if (btnNone) { btnNone.addEventListener('click', function () { setLifecycleAll(false); }); }
                        if (btnDef)  { btnDef.addEventListener('click',  setLifecycleDefault); }

                        /* Column toggle dropdown */
                        var colBtn  = document.getElementById('colToggleBtn');
                        var colMenu = dom.colMenu;
                        if (colBtn &amp;&amp; colMenu) {
                            colBtn.addEventListener('click', function(e) {
                                e.stopPropagation();
                                var isOpen = colMenu.style.display !== 'none';
                                colMenu.style.display = isOpen ? 'none' : 'block';
                                colBtn.setAttribute('aria-expanded', isOpen ? 'false' : 'true');
                            });
                            document.addEventListener('click', function(e) {
                                if (!colBtn.contains(e.target) &amp;&amp; !colMenu.contains(e.target)) {
                                    colMenu.style.display = 'none';
                                    colBtn.setAttribute('aria-expanded', 'false');
                                }
                            });
                            document.addEventListener('keydown', function(e) {
                                if (e.key === 'Escape' &amp;&amp; colMenu.style.display !== 'none') {
                                    colMenu.style.display = 'none';
                                    colBtn.setAttribute('aria-expanded', 'false');
                                    colBtn.focus();
                                }
                            });
                            var cbs = colMenu.querySelectorAll('input[type="checkbox"]');
                            for (var i = 0; i &lt; cbs.length; i++) {
                                cbs[i].addEventListener('change', rerender);
                            }
                        }

                        /* Panel filter inputs (cached NodeList; debounce text-typed inputs) */
                        for (var fi = 0; fi &lt; filterInputs.length; fi++) {
                            var inp = filterInputs[fi];
                            var handler = (inp.tagName === 'SELECT') ? rerender : rerenderDebounced;
                            inp.addEventListener('input', handler);
                            if (inp.tagName === 'SELECT') {
                                inp.addEventListener('change', handler);
                            }
                        }

                        /* Clear filters button — reset text/select inputs, restore lifecycle defaults */
                        var clearBtn = document.getElementById('clearFiltersBtn');
                        if (clearBtn) {
                            clearBtn.addEventListener('click', function () {
                                for (var i = 0; i &lt; filterInputs.length; i++) { filterInputs[i].value = ''; }
                                for (var j = 0; j &lt; lifecycleCheckboxes.length; j++) {
                                    lifecycleCheckboxes[j].checked = lifecycleCheckboxes[j].getAttribute('data-default-checked') === 'true';
                                }
                                rerender();
                            });
                        }

                        /* Column headers — sort on click (use cached thByCol) */
                        var thHandler = function (e) {
                            if (e.type === 'keydown' &amp;&amp; e.key !== 'Enter' &amp;&amp; e.key !== ' ') return;
                            if (e.type === 'keydown') e.preventDefault();
                            var col = this.getAttribute('data-col');
                            if (sortCol === col) {
                                sortDir = sortDir === 'asc' ? 'desc' : 'asc';
                            } else {
                                sortCol = col;
                                sortDir = 'asc';
                            }
                            rerender();
                        };
                        for (var c in thByCol) {
                            if (!thByCol.hasOwnProperty(c)) { continue; }
                            thByCol[c].addEventListener('click',   thHandler);
                            thByCol[c].addEventListener('keydown', thHandler);
                        }

                        /* Export CSV */
                        var exportBtn = document.getElementById('exportCsvBtn');
                        if (exportBtn) {
                            exportBtn.addEventListener('click', function () { exportCsv(); });
                        }

                        /* Custom bottom scrollbar — thumb drag and track click */
                        var scrollBar = document.getElementById('tblScrollBottom');
                        var thumb  = document.getElementById('tblScrollThumb');
                        var cardEl = document.getElementById('tblCard');
                        if (scrollBar &amp;&amp; thumb &amp;&amp; cardEl) {
                            /* Card scroll → update thumb position */
                            cardEl.addEventListener('scroll', syncTableScrollWidth);
                            window.addEventListener('resize', syncTableScrollWidth);
                            /* Filter panel toggle, column visibility, or any other layout change */
                            if (typeof ResizeObserver !== 'undefined') {
                                new ResizeObserver(syncTableScrollWidth).observe(cardEl);
                            }
                            syncTableScrollWidth();

                            /* Thumb drag — pointer capture keeps events on thumb even off-element */
                            var dragStartX, dragStartScrollLeft;

                            thumb.addEventListener('pointerdown', function (e) {
                                dragStartX = e.clientX;
                                dragStartScrollLeft = cardEl.scrollLeft;
                                thumb.classList.add('dragging');
                                thumb.setPointerCapture(e.pointerId);
                                e.preventDefault();
                            });
                            thumb.addEventListener('pointermove', function (e) {
                                if (!thumb.hasPointerCapture(e.pointerId)) { return; }
                                var dx = e.clientX - dragStartX;
                                var scrollableW = cardEl.scrollWidth - cardEl.clientWidth;
                                var trackW = scrollBar.clientWidth;
                                var thumbW = thumb.offsetWidth;
                                if (trackW &lt;= thumbW) { return; }
                                cardEl.scrollLeft = dragStartScrollLeft + dx * (scrollableW / (trackW - thumbW));
                            });
                            thumb.addEventListener('pointerup', function (e) {
                                thumb.classList.remove('dragging');
                                thumb.releasePointerCapture(e.pointerId);
                            });
                            thumb.addEventListener('pointercancel', function () {
                                thumb.classList.remove('dragging');
                            });

                            /* Track click → jump to position */
                            scrollBar.addEventListener('click', function (e) {
                                if (e.target === thumb || thumb.contains(e.target)) { return; }
                                var rect = scrollBar.getBoundingClientRect();
                                var ratio = (e.clientX - rect.left) / scrollBar.clientWidth;
                                cardEl.scrollLeft = ratio * (cardEl.scrollWidth - cardEl.clientWidth);
                            });
                        }

                        /* Filter panel collapse/expand */
                        var filterPanel     = document.getElementById('filterPanel');
                        var filterToggleBtn = document.getElementById('filterToggleBtn');
                        var filterIcon      = filterToggleBtn ? filterToggleBtn.querySelector('i') : null;
                        var filterSrText    = filterToggleBtn ? filterToggleBtn.querySelector('.sr-only') : null;

                        function applyFilterPanelState(collapsed, animate) {
                            if (!filterPanel || !filterToggleBtn) { return; }
                            if (!animate) { filterPanel.style.transition = 'none'; }
                            if (collapsed) {
                                filterPanel.classList.add('collapsed');
                                filterToggleBtn.setAttribute('aria-expanded', 'false');
                                filterToggleBtn.title = 'Expand filters';
                                if (filterIcon)   { filterIcon.className = 'fa fa-chevron-right'; }
                                if (filterSrText) { filterSrText.textContent = 'Expand filter panel'; }
                            } else {
                                filterPanel.classList.remove('collapsed');
                                filterToggleBtn.setAttribute('aria-expanded', 'true');
                                filterToggleBtn.title = 'Collapse filters';
                                if (filterIcon)   { filterIcon.className = 'fa fa-chevron-left'; }
                                if (filterSrText) { filterSrText.textContent = 'Collapse filter panel'; }
                            }
                            if (!animate) {
                                /* Force reflow then re-enable transition */
                                filterPanel.offsetWidth; // eslint-disable-line no-unused-expressions
                                filterPanel.style.transition = '';
                            }
                        }

                        /* Restore saved state; default to collapsed on mobile if no preference saved */
                        var savedPref = localStorage.getItem('easFilterPanelCollapsed');
                        var savedCollapsed = savedPref !== null ? (savedPref === 'true') : (window.innerWidth &lt; 768);
                        applyFilterPanelState(savedCollapsed, false);

                        if (filterToggleBtn) {
                            filterToggleBtn.addEventListener('click', function () {
                                var isCollapsed = filterPanel.classList.contains('collapsed');
                                applyFilterPanelState(!isCollapsed, true);
                                localStorage.setItem('easFilterPanelCollapsed', String(!isCollapsed));
                            });
                        }
                    }

                    /* ── Custom bottom scrollbar: position thumb ────────────── */
                    function syncTableScrollWidth() {
                        var scrollBar = document.getElementById('tblScrollBottom');
                        var thumb  = document.getElementById('tblScrollThumb');
                        var card   = document.getElementById('tblCard');
                        if (!scrollBar || !thumb || !card) { return; }
                        var ratio = card.clientWidth / card.scrollWidth;
                        if (ratio >= 1) { thumb.style.display = 'none'; return; }
                        thumb.style.display = '';
                        var trackW  = scrollBar.clientWidth;
                        var thumbW  = Math.max(24, ratio * trackW);
                        var maxLeft = trackW - thumbW;
                        var scrollableW = card.scrollWidth - card.clientWidth;
                        var pos = scrollableW > 0 ? (card.scrollLeft / scrollableW) * maxLeft : 0;
                        thumb.style.width = thumbW + 'px';
                        thumb.style.left  = pos + 'px';
                    }

                    /* ── CSV export ────────────────────────────────────────── */
                    function exportCsv() {
                        var visibleCols = getVisibleColumns();
                        var term     = dom.appSearch ? dom.appSearch.value : '';
                        var filtered = filterApps(viewModel.applications, term, visibleCols);
                        var sorted   = sortApps(filtered, sortCol, sortDir);

                        var headers = [];
                        if (visibleCols.name) headers.push('Application Name');
                        if (visibleCols.description) headers.push('Description');
                        if (visibleCols.businessUnit) headers.push('Business Units');
                        if (visibleCols.stakeholderPeople) headers.push('People');
                        if (visibleCols.itspUnit) headers.push('ITSP');
                        if (visibleCols.businessCriticality) headers.push('Business Criticality');
                        if (visibleCols.dataSensitivity) headers.push('Data Sensitivity');
                        if (visibleCols.ssoProtected) headers.push('SSO Protected');
                        if (visibleCols.lifecycleStatus) headers.push('Lifecycle Status');
                        if (visibleCols.integrationComplexity) headers.push('Integration Complexity');
                        if (visibleCols.userBase) headers.push('User Base');
                        if (visibleCols.userPopulation) headers.push('User Population');
                        if (visibleCols.supplier) headers.push('Supplier');
                        if (visibleCols.cost) headers.push('Annual Cost');

                        var rows = [headers];
                        for (var i = 0; i &lt; sorted.length; i++) {
                            var a = sorted[i];
                            var row = [];
                            if (visibleCols.name) row.push(csvSafe(a.name));
                            if (visibleCols.description) row.push(csvSafe(a.description || ''));
                            if (visibleCols.businessUnit) row.push(csvSafe(a.businessUnit));
                            if (visibleCols.stakeholderPeople) row.push(csvSafe(a.stakeholderPeople || ''));
                            if (visibleCols.itspUnit) row.push(csvSafe(a.itspUnit));
                            if (visibleCols.businessCriticality) row.push(csvSafe(a.businessCriticality));
                            if (visibleCols.dataSensitivity) row.push(csvSafe(a.dataSensitivity));
                            if (visibleCols.ssoProtected) row.push(a.ssoProtected ? 'Yes' : 'No');
                            if (visibleCols.lifecycleStatus) row.push(csvSafe(a.lifecycleStatus || ''));
                            if (visibleCols.integrationComplexity) row.push(csvSafe(a.integrationComplexity !== 'Unknown' ? a.integrationComplexity : ''));
                            if (visibleCols.userBase) row.push(csvSafe(a.userBase !== 'Unknown' ? a.userBase : ''));
                            if (visibleCols.userPopulation) row.push(csvSafe(a.userPopulation || ''));
                            if (visibleCols.supplier) row.push(csvSafe(a.supplier || ''));
                            if (visibleCols.cost) row.push(a.cost &gt; 0 ? a.cost : '');
                            rows.push(row);
                        }

                        var csv  = rows.map(function (r) { return r.join(','); }).join('\n');
                        var blob = new Blob([csv], { type: 'text/csv' });
                        var url  = URL.createObjectURL(blob);
                        var a    = document.createElement('a');
                        a.href     = url;
                        a.download = 'application_portfolio.csv';
                        a.click();
                        URL.revokeObjectURL(url);
                    }
                </script>
            </head>
            <body>
                <xsl:call-template name="Heading"/>

                <main class="eas-tbl-wrapper">

                    <!-- Page header -->
                    <div class="eas-tbl-header">
                        <h2 id="page-title">Application Atlas</h2>
                        <p class="eas-tbl-subtitle">
                            Sortable, filterable register of all applications. Columns are configurable. Sunset and retired applications are hidden by default.
                        </p>
                    </div>

                    <!-- KPI tiles -->
                    <section id="kpi-section" aria-labelledby="kpis-title">
                        <h3 id="kpis-title" class="sr-only">Key Performance Indicators</h3>
                        <div id="kpiTiles" aria-live="polite" aria-busy="true">
                            <div class="eas-loading" role="status">
                                <i class="fa fa-spinner fa-pulse fa-2x" aria-hidden="true"></i>
                                &#160;Loading portfolio data&#8230;
                            </div>
                        </div>
                    </section>

                    <!-- Toolbar: global search, sunset toggle, column toggle, export -->
                    <div class="eas-tbl-toolbar">
                        <input id="appSearch" class="eas-tbl-search" type="text"
                               aria-label="Search applications"
                               placeholder="Search applications, units, criticality&#8230;"/>
                        <span id="rowCount" class="eas-tbl-count" role="status" aria-live="polite" aria-atomic="true"></span>

                        <div style="display: flex; gap: 8px; align-items: center;">
                            <div class="eas-col-toggle-wrapper" style="position: relative;">
                                <button id="colToggleBtn" class="eas-export-btn" style="background: #fff; color: #337ab7; border: 1px solid #337ab7;"
                                        aria-haspopup="true" aria-expanded="false" aria-controls="colToggleMenu">
                                    <i class="fa fa-columns" aria-hidden="true"></i>&#160;Columns
                                </button>
                                <div id="colToggleMenu" class="eas-col-menu" style="display: none; position: absolute; right: 0; top: 100%; margin-top: 4px; background: #fff; border: 1px solid #757575; border-radius: 6px; box-shadow: 0 4px 12px rgba(0,0,0,0.15); padding: 8px 0; z-index: 1000; min-width: 200px; text-align: left;">
                                    <label class="eas-col-menu-item"><input type="checkbox" value="name" checked="checked"/> Application Name</label>
                                    <label class="eas-col-menu-item"><input type="checkbox" value="description" checked="checked"/> Description</label>
                                    <label class="eas-col-menu-item"><input type="checkbox" value="businessUnit" checked="checked"/> Business Units</label>
                                    <label class="eas-col-menu-item"><input type="checkbox" value="stakeholderPeople" checked="checked"/> People</label>
                                    <label class="eas-col-menu-item"><input type="checkbox" value="itspUnit" checked="checked"/> ITSP</label>
                                    <label class="eas-col-menu-item"><input type="checkbox" value="businessCriticality" checked="checked"/> Business Criticality</label>
                                    <label class="eas-col-menu-item"><input type="checkbox" value="dataSensitivity" checked="checked"/> Data Sensitivity</label>
                                    <label class="eas-col-menu-item"><input type="checkbox" value="ssoProtected" checked="checked"/> SSO Protected</label>
                                    <label class="eas-col-menu-item"><input type="checkbox" value="lifecycleStatus"/> Lifecycle Status</label>
                                    <label class="eas-col-menu-item"><input type="checkbox" value="integrationComplexity" checked="checked"/> Integration Complexity</label>
                                    <label class="eas-col-menu-item"><input type="checkbox" value="userBase" checked="checked"/> User Base</label>
                                    <label class="eas-col-menu-item"><input type="checkbox" value="userPopulation" checked="checked"/> User Population</label>
                                    <label class="eas-col-menu-item"><input type="checkbox" value="supplier"/> Supplier</label>
                                    <label class="eas-col-menu-item"><input type="checkbox" value="cost"/> Annual Cost</label>
                                </div>
                            </div>
                            <button id="exportCsvBtn" class="eas-export-btn">
                                <i class="fa fa-download" aria-hidden="true"></i>&#160;Export CSV
                            </button>
                        </div>
                    </div>

                    <!-- Main content: filter panel + table side by side -->
                    <div class="eas-layout-row">

                        <!-- Left filter panel -->
                        <aside class="eas-filter-panel" id="filterPanel" aria-label="Column filters">
                            <div class="eas-filter-panel-header">
                                <span class="eas-filter-panel-title"><i class="fa fa-filter" aria-hidden="true"></i> Filters</span>
                                <button class="eas-filter-toggle-btn" id="filterToggleBtn"
                                        aria-controls="filterPanelBody"
                                        aria-expanded="true"
                                        title="Collapse filters">
                                    <i class="fa fa-chevron-left" aria-hidden="true"></i>
                                    <span class="sr-only">Collapse filter panel</span>
                                </button>
                            </div>

                            <div class="eas-filter-panel-body" id="filterPanelBody">

                            <div class="eas-filter-group" data-filter-group="name">
                                <label for="filter-name">Application Name</label>
                                <input type="text" id="filter-name" autocomplete="off"
                                       class="eas-filter-input" data-filter-col="name"
                                       placeholder="Filter&#8230;" aria-label="Filter by application name"/>
                            </div>
                            <div class="eas-filter-group" data-filter-group="description">
                                <label for="filter-desc">Description</label>
                                <input type="text" id="filter-desc" autocomplete="off"
                                       class="eas-filter-input" data-filter-col="description"
                                       placeholder="Filter&#8230;" aria-label="Filter by description"/>
                            </div>
                            <div class="eas-filter-group" data-filter-group="businessUnit">
                                <label for="filter-bu">Business Units</label>
                                <input type="text" id="filter-bu" autocomplete="off"
                                       class="eas-filter-input" data-filter-col="businessUnit"
                                       placeholder="Filter&#8230;" aria-label="Filter by business unit"/>
                            </div>
                            <div class="eas-filter-group" data-filter-group="stakeholderPeople">
                                <label for="filter-people">People</label>
                                <input type="text" id="filter-people" autocomplete="off"
                                       class="eas-filter-input" data-filter-col="stakeholderPeople"
                                       placeholder="Filter&#8230;" aria-label="Filter by person"/>
                            </div>
                            <div class="eas-filter-group" data-filter-group="itspUnit">
                                <label for="filter-itsp">ITSP</label>
                                <select id="filter-itsp" class="eas-filter-input eas-filter-select"
                                        data-filter-col="itspUnit" aria-label="Filter by ITSP">
                                    <option value="">All</option>
                                </select>
                            </div>
                            <div class="eas-filter-group" data-filter-group="businessCriticality">
                                <label for="filter-crit">Business Criticality</label>
                                <select id="filter-crit" class="eas-filter-input eas-filter-select"
                                        data-filter-col="businessCriticality" aria-label="Filter by criticality">
                                    <option value="">All</option>
                                    <option value="critical">Critical</option>
                                    <option value="not critical">Not Critical</option>
                                    <option value="unclassified">Unclassified</option>
                                </select>
                            </div>
                            <div class="eas-filter-group" data-filter-group="dataSensitivity">
                                <label for="filter-sens">Data Sensitivity</label>
                                <select id="filter-sens" class="eas-filter-input eas-filter-select"
                                        data-filter-col="dataSensitivity" aria-label="Filter by data sensitivity">
                                    <option value="">All</option>
                                    <option value="High">High</option>
                                    <option value="Moderate">Moderate</option>
                                    <option value="Low">Low</option>
                                    <option value="Unclassified">Unclassified</option>
                                </select>
                            </div>
                            <div class="eas-filter-group" data-filter-group="ssoProtected">
                                <label for="filter-sso">SSO Protected</label>
                                <select id="filter-sso" class="eas-filter-input eas-filter-select"
                                        data-filter-col="ssoProtected" aria-label="Filter by SSO status">
                                    <option value="">All</option>
                                    <option value="yes">Yes</option>
                                    <option value="no">No</option>
                                </select>
                            </div>
                            <div class="eas-filter-group" data-filter-group="lifecycleStatus">
                                <label id="filter-lc-label">Lifecycle Status</label>
                                <div id="lifecycleCheckboxes" class="eas-filter-checkbox-group"
                                     role="group" aria-labelledby="filter-lc-label">
                                    <!-- populated dynamically by populateLifecycleFilter() -->
                                </div>
                                <div class="eas-filter-checkbox-actions" role="group" aria-label="Lifecycle filter shortcuts">
                                    <button type="button" id="lifecycleCheckAll"
                                            aria-label="Select all lifecycle statuses">All</button>
                                    <button type="button" id="lifecycleCheckNone"
                                            aria-label="Deselect all lifecycle statuses">None</button>
                                    <button type="button" id="lifecycleCheckDefault"
                                            aria-label="Reset lifecycle to default selection (excludes Sunset and Retired)"
                                            title="Active statuses (excludes Sunset / Retired)">Default</button>
                                </div>
                            </div>

                            <div class="eas-filter-group" data-filter-group="integrationComplexity">
                                <label for="filter-intcx">Integration Complexity</label>
                                <select id="filter-intcx" class="eas-filter-input eas-filter-select"
                                        data-filter-col="integrationComplexity" aria-label="Filter by integration complexity">
                                    <option value="">All</option>
                                    <option value="None">None</option>
                                    <option value="Low (1-2)">Low (1-2)</option>
                                    <option value="Moderate (3-5)">Moderate (3-5)</option>
                                    <option value="High (5+)">High (5+)</option>
                                </select>
                            </div>
                            <div class="eas-filter-group" data-filter-group="userBase">
                                <label for="filter-ubase">User Base</label>
                                <select id="filter-ubase" class="eas-filter-input eas-filter-select"
                                        data-filter-col="userBase" aria-label="Filter by user base">
                                    <option value="">All</option>
                                    <option value="Team or Department">Team or Department</option>
                                    <option value="School or Unit">School or Unit</option>
                                    <option value="Campus">Campus</option>
                                    <option value="University">University</option>
                                    <option value="Public">Public</option>
                                </select>
                            </div>
                            <div class="eas-filter-group" data-filter-group="userPopulation">
                                <label for="filter-upop">User Population</label>
                                <select id="filter-upop" class="eas-filter-input eas-filter-select"
                                        data-filter-col="userPopulation" aria-label="Filter by user population">
                                    <option value="">All</option>
                                    <option value="Staff">Staff</option>
                                    <option value="Faculty">Faculty</option>
                                    <option value="Students">Students</option>
                                    <option value="Public">Public</option>
                                    <option value="Alumni">Alumni</option>
                                    <option value="Research">Research</option>
                                </select>
                            </div>
                            <div class="eas-filter-group" data-filter-group="supplier">
                                <label for="filter-supplier">Supplier</label>
                                <input type="text" id="filter-supplier" autocomplete="off"
                                       class="eas-filter-input" data-filter-col="supplier"
                                       placeholder="Filter&#8230;" aria-label="Filter by supplier"/>
                            </div>
                            <div class="eas-filter-group" data-filter-group="cost">
                                <label for="filter-cost">Cost</label>
                                <input type="text" id="filter-cost" autocomplete="off"
                                       class="eas-filter-input" data-filter-col="cost"
                                       placeholder="Filter&#8230;" aria-label="Filter by cost"/>
                            </div>

                            <button id="clearFiltersBtn" class="eas-filter-clear-btn">
                                <i class="fa fa-undo" aria-hidden="true"></i>&#160;Reset Filters
                            </button>

                            </div><!-- /.eas-filter-panel-body -->
                        </aside>

                        <!-- Table -->
                        <section class="eas-table-section" id="table-section" aria-labelledby="table-title">
                            <h3 id="table-title" class="sr-only">Application Atlas</h3>
                            <div class="eas-tbl-card" id="tblCard">
                                <table class="eas-app-table">
                                    <caption class="sr-only">Application Atlas — sortable table of applications with ownership, criticality, data sensitivity, SSO status, lifecycle status, integration complexity, user base, user population and supplier. Use Enter or Space on a column header to sort.</caption>
                                    <thead>
                                        <tr>
                                            <th data-col="name"                style="min-width: 140px;" scope="col" tabindex="0" aria-sort="none">Application Name <i class="sort-icon fa fa-sort" aria-hidden="true"></i></th>
                                            <th data-col="description"         style="min-width: 180px;" scope="col" tabindex="0" aria-sort="none">Description <i class="sort-icon fa fa-sort" aria-hidden="true"></i></th>
                                            <th data-col="businessUnit"        style="min-width: 110px;" scope="col" tabindex="0" aria-sort="none">Business Units <i class="sort-icon fa fa-sort" aria-hidden="true"></i></th>
                                            <th data-col="stakeholderPeople"   style="min-width: 100px;" scope="col" tabindex="0" aria-sort="none">People <i class="sort-icon fa fa-sort" aria-hidden="true"></i></th>
                                            <th data-col="itspUnit"            style="min-width:  85px;" scope="col" tabindex="0" aria-sort="none">ITSP <i class="sort-icon fa fa-sort" aria-hidden="true"></i></th>
                                            <th data-col="businessCriticality" style="min-width: 80px; white-space: normal;" scope="col" tabindex="0" aria-sort="none">Business <span style="white-space: nowrap;">Criticality <i class="sort-icon fa fa-sort" aria-hidden="true"></i></span></th>
                                            <th data-col="dataSensitivity"       style="min-width: 100px;" scope="col" tabindex="0" aria-sort="none">Data Sensitivity <i class="sort-icon fa fa-sort" aria-hidden="true"></i></th>
                                            <th data-col="ssoProtected"          style="min-width:  75px; white-space: normal;" scope="col" tabindex="0" aria-sort="none">SSO <span style="white-space: nowrap;">Protected <i class="sort-icon fa fa-sort" aria-hidden="true"></i></span></th>
                                            <th data-col="lifecycleStatus"       style="min-width: 90px; white-space: normal;" scope="col" tabindex="0" aria-sort="none">Lifecycle <span style="white-space: nowrap;">Status <i class="sort-icon fa fa-sort" aria-hidden="true"></i></span></th>
                                            <th data-col="integrationComplexity" style="min-width: 80px; white-space: normal;" scope="col" tabindex="0" aria-sort="none">Integration <span style="white-space: nowrap;">Complexity <i class="sort-icon fa fa-sort" aria-hidden="true"></i></span></th>
                                            <th data-col="userBase"              style="min-width: 105px;" scope="col" tabindex="0" aria-sort="none">User Base <i class="sort-icon fa fa-sort" aria-hidden="true"></i></th>
                                            <th data-col="userPopulation"        style="min-width: 80px; white-space: normal;" scope="col" tabindex="0" aria-sort="none">User <span style="white-space: nowrap;">Population <i class="sort-icon fa fa-sort" aria-hidden="true"></i></span></th>
                                            <th data-col="supplier"              style="min-width: 110px;" scope="col" tabindex="0" aria-sort="none">Supplier <i class="sort-icon fa fa-sort" aria-hidden="true"></i></th>
                                            <th data-col="cost"                  style="min-width:  95px;" scope="col" tabindex="0" aria-sort="none">Annual Cost <i class="sort-icon fa fa-sort" aria-hidden="true"></i></th>
                                        </tr>
                                    </thead>
                                    <tbody id="appTableBody">
                                        <tr>
                                            <td colspan="14" class="eas-loading" role="status">
                                                <i class="fa fa-spinner fa-pulse" aria-hidden="true"></i>&#160;Loading&#8230;
                                            </td>
                                        </tr>
                                    </tbody>
                                </table>
                            </div>
                            <!-- Custom scrollbar anchored to the bottom of the table -->
                            <div class="eas-tbl-scroll-bottom" id="tblScrollBottom" aria-hidden="true">
                                <div class="eas-tbl-scroll-thumb" id="tblScrollThumb"></div>
                            </div>
                        </section>

                    </div><!-- /.eas-layout-row -->

                </main>

                <xsl:call-template name="Footer"/>
            </body>
        </html>
    </xsl:template>


    <!-- ═══════════════════════════════════════════════════════════════════
         COST DATE FILTER
         Returns true() when a cost component should be included based on
         cc_cost_start_date_iso_8601 / cc_cost_end_date_iso_8601 and today.

         Rules (as specified):
           • Both dates absent          → always include
           • Start only                 → include if start ≤ today
           • End only                   → effective start = end − 5 years;
                                          include if effectiveStart ≤ today ≤ end
           • Both present               → include if start ≤ today ≤ end

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

</xsl:stylesheet>
