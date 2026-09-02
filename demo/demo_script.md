# Consumer Insights & Personalization Engine

**Philippines - Retail & E-Commerce**
Use case: Consumer Personalization

> 110M Filipino internet users, price-sensitive and mobile-first — Snowflake builds consumer profiles with ML.CLASSIFICATION, generates personalized offers via Cortex Complete, and delivers through SES at scale.

## Why Snowflake

Snowflake ingests consumer behavior from Kinesis, classifies purchase intent with ML.CLASSIFICATION, generates personalized content via Cortex Complete, and delivers offers through SES — replacing Amazon Personalize with native capabilities

- **ML.CLASSIFICATION for purchase intent + churn** - Dual classification models — intent AND churn — on same Customer 360 table
- **Cortex Complete for marketing copy generation** - LLM generates personalized email/SMS at scale — replaces Personalize
- **SES notification delivery** - End-to-end: score → generate → deliver via email/SMS notification integration
- **45M browse events ingested via Kinesis** - Production-scale behavioral data ingestion and processing
- **Philippine retail consumer context** - ₱4.2T market with mobile-first, loyalty-driven Filipino shoppers

## What is deployed

| | |
|---|---|
| Database | `PH_RETAIL_PERSONALIZATION` |
| Service | `PH_RETAIL_PERSONALIZATION_APP` |
| Compute pool | `SEA_DEMOS_PHILIPPINES_POOL` |
| Dimension table | `RAW.PRODUCT_CATALOG` (20 rows) |
| Fact table | `RAW.BROWSE_EVENTS` (250,000 rows, 90 days) |
| Curated layer | `CURATED.PERFORMANCE_SUMMARY`, `CURATED.TREND_ANALYSIS`, `CURATED.KPI_SUMMARY` |
| Currency | PHP (₱) |

Regions in play: Metro Manila, Cebu, Davao, Pampanga, Iloilo
Segments: Mass Market, Young Professional, Family Shopper, Premium

Dynamic tables are created suspended and refreshed on demand:

```bash
./refresh_demo_data.sh PH_RETAIL_PERSONALIZATION
```

## KPI cards

Every card below is served live from `CURATED.KPI_SUMMARY`. The app keeps the
original literal as a fallback, so it still renders if Snowflake is unreachable.

| Card | Value | Backed by |
|---|---|---|
| Recommendation CTR | `8.4%` | average per event |
| Personalized Revenue | `₱1.2B` | total across Product Catalog |
| A/B Tests Active | `14` | average per event |
| Models Deployed | `8` | average per event |
| Revenue Lift (Avg) | `+14%` | average per event |
| Engagement Lift | `+22%` | average per event |
| Test Velocity | `4/week` | average per event |


## Demo flow

1. Executive Cockpit
2. Personalization
3. Customer 360
4. Ask AI
5. Architecture & Data

## Talking points

- **2.8M customers** - active customer base with unified profiles
- **₱8.4B** - CLV at risk from 342K churn-risk customers
- **2.4x** - conversion lift from ML-personalized vs static campaigns
- **45M events** - browse events ingested monthly via Kinesis
- **₱24,500** - average customer lifetime value
- **8.4% CTR** - for ML-personalized campaigns (vs 3.5% static)

## Business impact

- Philippine retail market valued at ₱4.2 trillion with 8% digital commerce penetration (PSA Philippines)
- ML-powered personalization improves campaign conversion 2-4x vs segment-based (McKinsey Marketing)
- Reducing churn by 5% increases profits 25-95% in retail (Bain & Company)
- Filipino consumers rank loyalty programs as #2 purchase decision factor after price (Nielsen Philippines)

---
Generated from `generator/demo_specs/aws-philippines-retail-personalization.json`. Do not hand-edit: run
`python3 generator/gen_repo_docs.py aws-philippines-retail-personalization` instead.
