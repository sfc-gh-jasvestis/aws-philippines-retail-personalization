# Demo Script: Consumer Insights & Personalization Engine
## ~4-Minute Recorded Walkthrough
**Format**: Screen recording with voiceover
**Target**: Customer meeting / booth loop / social share
**Narrative**: "Snowflake ingests consumer behavior from Kinesis, classifies purchase intent with ML.CLASSIFICATION, generates personalized content via Cortex Complete, and delivers offers through SES — replacing Amazon Personalize with native capabilities"
**Demo Mode**: Open app with `?demo=true` for presenter notes

---

## Two Personas

| Persona | Role | Tool | What they care about |
|---|---|---|---|
| **Clarissa Joy Tan-Cojuangco** | VP Marketing & CRM | React App (SPCS) | Customer lifetime value, campaign ROI, churn prevention, segment performance |
| **Dennis Patrick Soriano** | Personalization Engineer | Amazon QuickSight | Recommendation accuracy, A/B test results, model performance, feature engineering |

---

## What's Built

| Layer | Component | Detail |
|---|---|---|
| **RAW** | 6 tables | CUSTOMERS (2800000), BROWSE_EVENTS (45000000), PURCHASE_HISTORY (8500000), CAMPAIGN_RESPONSES (12000000), PRODUCT_CATALOG (85000), LOYALTY_POINTS (1800000) |
| **CURATED** | 4 Dynamic Tables | CUSTOMER_360, SEGMENT_PERFORMANCE, PRODUCT_AFFINITY, NEXT_BEST_OFFER |
| **ML** | ML.CLASSIFICATION + ML.CLASSIFICATION | Forecasting + anomaly detection |
| **AI** | COMPLETE, AI_CLASSIFY | Classification + extraction |
| **Search** | Cortex Search | 85000 documents indexed |
| **Agent** | PERSONALIZATION_AGENT | Semantic View + Search tools |


---

## The Story

Philippine retail is a ₱4.2 trillion market where consumers are mobile-first, price-sensitive, and loyalty-driven. A leading omnichannel retailer with 2.8M customers sends 50M marketing messages monthly — but most are batch, segment-based, and irrelevant. ML-powered personalization with Cortex Complete generates individualized offers that convert 2.4x higher, protecting ₱8.4B in customer lifetime value.

---

## Script

### [0:00–0:45] EXECUTIVE COCKPIT

**Show**: Executive Cockpit tab

> "2.8 million active customers — average CLV of ₱24,500 across all segments."

**Action**: Point at 2.8M customers KPI

### [0:45–1:30] PERSONALIZATION

**Show**: Personalization tab

> "ML.CLASSIFICATION predicts purchase intent for 2.8M customers — refreshed hourly."

**Action**: Show prediction score distribution

### [1:30–2:15] CUSTOMER 360

**Show**: Customer 360 tab

> "Five segments: VIP (top 5%), Loyal (20%), Active (35%), At-Risk (25%), Dormant (15%)."

**Action**: Show segment pyramid with CLV

### [2:15–3:00] ASK AI

**Show**: Ask AI tab

> "Clarissa asks: 'What's the best offer for at-risk VIP customers?'"

**Action**: Type: 'Best offer for at-risk VIPs?'

### [3:00–3:45] ARCHITECTURE & DATA

**Show**: Architecture & Data tab

> "Kinesis → Snowpipe → Customer 360 → ML scoring → Cortex Complete copy → SES delivery."

**Action**: Walk through architecture diagram


---

## Key Demo Differentiators

1. **ML.CLASSIFICATION for purchase intent + churn** — Dual classification models — intent AND churn — on same Customer 360 table
2. **Cortex Complete for marketing copy generation** — LLM generates personalized email/SMS at scale — replaces Personalize
3. **SES notification delivery** — End-to-end: score → generate → deliver via email/SMS notification integration
4. **45M browse events ingested via Kinesis** — Production-scale behavioral data ingestion and processing
5. **Philippine retail consumer context** — ₱4.2T market with mobile-first, loyalty-driven Filipino shoppers


---

## Demo Prep Checklist

### Data Verification
- [ ] `SELECT COUNT(*) FROM CONSUMER_INSIGHTS.RAW.BROWSE_EVENTS` → 45000000
- [ ] `SELECT COUNT(*) FROM CONSUMER_INSIGHTS.RAW.CUSTOMERS` → 2800000
- [ ] `SELECT COUNT(*) FROM CONSUMER_INSIGHTS.CURATED.CUSTOMER_360 WHERE CHURN_RISK_SCORE > 0.8` → ~342000

### ML Model Verification
- [ ] `SELECT COUNT(*) FROM CONSUMER_INSIGHTS.ML.PURCHASE_INTENT_RESULTS WHERE WILL_PURCHASE_7D = TRUE` → >0
- [ ] `SELECT COUNT(*) FROM CONSUMER_INSIGHTS.ML.CHURN_RISK_RESULTS WHERE WILL_CHURN_30D = TRUE` → ~342000

### AI/Agent Verification
- [ ] `SELECT COUNT(*) FROM CONSUMER_INSIGHTS.AI.LIFECYCLE_CLASSIFICATION` → 2800000

