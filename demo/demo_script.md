# Philippines Retail Loyalty Personalization

**Philippines - Retail Loyalty Personalization**
Use case: Offer fatigue, member opt-outs, consent controls and CRM risk triage

> Personalization monitoring for 40 aggregate loyalty segments of a fictional Philippine omnichannel retailer in Pasig City, Mandaue City, General Santos City, Zamboanga City and Angeles City: dynamic tables, a holdout-evaluated member opt-out classifier, an offer-issue forecast and ignore rate anomaly detection, a Cortex Agent with SOP citations, a live offer event feed with an alert, and an SPCS app. No member-level data is generated.

## Why Snowflake

- **Dynamic tables** reconcile offers sent, offer issues, member opt-outs, spam reports and creative refresh compliance from RAW segment data, with checks in `run_core.py`
- **Member opt-out classification** gives a holdout-evaluated next-7-day probability per segment
- **Offer-issue forecast** projects 14 days of program-wide offer issues with prediction intervals, for CRM team staffing
- **Grounded AI**: the Cortex Agent (Analyst over a semantic view, plus Search over SOPs) shows its SQL and SOP citations
- **Live offer events**: a native simulator (Snowflake only) or Firehose, S3 and Snowpipe (AWS build), then an alert and email

## What is built

| | |
|---|---|
| Dimension table | `RAW.SEGMENTS` (40 rows) |
| Fact table | `RAW.SEGMENT_DAILY` (3,600 segment-days, 90 days) |
| Curated layer | `CURATED.KPI_SUMMARY`, `PERFORMANCE_SUMMARY`, `ISSUE_SUMMARY`, `TREND_ANALYSIS` |
| ML | `ML.OPTOUT_RISK_SCORES`, `ML.OPTOUT_RISK_HOLDOUT_METRICS`, `ML.ISSUE_FORECAST`, `ML.IGNORE_RATE_ANOMALIES` |

Currency: PHP. Cities: Pasig City, Mandaue City, General Santos City, Zamboanga City, Angeles City.
Category affinities: Groceries, Fashion, Health and beauty, Home and living, Mobile and gadgets.

## KPI cards (live from `CURATED.KPI_SUMMARY`; no fallback values)

| Card | Value from the seeded data |
|---|---|
| Clean Offer Rate | 99.97% |
| Offer Issues Raised | 680 |
| Member Opt-outs | 219 |
| Issue Opt-out Rate | 32.2% |
| Spam Reports | 95 |
| Attributed Sales (PHP M) | 289 |
| Offers Sent | 2,183,501 |
| Offer Refresh Compliance | 84.2% |
| Segments Monitored | 40 |
| Consent Record Coverage | 45.5% |
| Consent Records Pending | 31 |

Values are synthetic. A rebuild reproduces them because the data is HASH-seeded; dates are relative to the build day.

## Demo flow

1. Executive Cockpit: KPIs, daily offer issues against member opt-outs, issues and opt-outs by issue type, segment table
2. Predictive: holdout metrics, risk bands, 14-day offer-issue forecast, ignore rate anomalies
3. Controls: offer refresh compliance, consent record coverage and pending batches, creative refresh compliance against member opt-outs, then generate the action memo
4. Live Offer Events: run `CALL APP.SIMULATE_OFFER_EVENTS(20)` (Snowflake only) or `python aws/publish_offer_events.py --count 20` (AWS build). Then run `EXECUTE ALERT APP.LIVE_OFFER_ALERT` and show the alert log and email
5. Ask AI: the Cortex Agent answers metric questions through the semantic view and cites SOPs from Cortex Search. The SQL is shown.
6. QuickSight (AWS build): the same Snowflake tables through DIRECT_QUERY
7. Architecture: both builds side by side

## Talking points

- 99.97% of offers go out without an issue; the 680 offer issues are where CRM time goes, and about 1 in 3 of them (32.2%) end in member opt-outs.
- Irrelevant recommendation issues produce the most member opt-outs (56 of 164). SMS gateway outages hit every segment in a city at once and always resolve without an opt-out.
- The risk model is evaluated on a time-based holdout: precision 0.56 and recall 0.58 at 0.5, against a 0.23 base rate. Present it as triage, not a verdict.
- SMS gateway outages are excluded from model training, because they are not segment-driven.
- Consent record coverage is 45.5% with 31 batches pending: a control gap to close before widening personalised sends.

## Business impact

Use only the sourced references in `README.md` (Business Impact).
