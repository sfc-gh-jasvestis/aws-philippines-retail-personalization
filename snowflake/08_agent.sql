-- ============================================================================
-- 08_AGENT.SQL — Cortex Agent for Consumer Insights & Personalization Engine
-- ============================================================================
USE DATABASE CONSUMER_INSIGHTS;
USE SCHEMA APP;

CREATE OR REPLACE CORTEX AGENT APP.PERSONALIZATION_AGENT
  COMMENT = 'Consumer Insights & Personalization Engine AI Assistant'
  MODEL = 'claude-opus-4-8'
  TOOLS = (
    SEMANTIC_VIEW_TOOL(SEMANTIC_VIEW => 'CONSUMER_INSIGHTS.APP.CONSUMER_ANALYTICS'),    CORTEX_SEARCH_TOOL(CORTEX_SEARCH_SERVICE => 'CONSUMER_INSIGHTS.SEARCH.PRODUCT_SEARCH', TOOL_DESCRIPTION => 'Search documents for Retail & E-Commerce information')
  )
  SYSTEM_PROMPT = 'You are the Consumer Intelligence Agent for a Philippine retailer with 2.8M customers, processing 45M browse events monthly and delivering personalized offers across email, SMS, and push channels.';
