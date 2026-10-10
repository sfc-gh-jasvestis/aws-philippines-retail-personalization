'use client';

import { useEffect, useState } from 'react';
import { AppLayout } from '@/components/AppLayout';
import { KPICard } from '@/components/KPICard';
import { Chart } from '@/components/Chart';
import { DataTable } from '@/components/DataTable';
import { AskAI } from '@/components/AskAI';
import { ActionMemo } from '@/components/ActionMemo';

interface PersonalizationData {
  platform: 'snowflake' | 'aws';
  kpiCards: { title: string; value: string }[];
  timeseries: { period: string; issues: number | null; optouts: number | null }[];
  categories: { category: string; issues: number | null; optouts: number | null }[];
  entities: Record<string, string | number | null>[];
  refreshRisk: { name: string; compliance: number; optouts: number }[];
  sourceWatermark: string | null;
  rawWatermark: string | null;
  requestedAt: string;
  stale: boolean;
  pipelineBehind: boolean;
  risk: Record<string, string | number | null>[];
  holdout: { n: number | null; baseRate: number | null; precision: number | null; recall: number | null } | null;
  forecast: { period: string; value: number | null; lower: number | null; upper: number | null }[];
  live: Record<string, string | number | null>[];
  liveSummary: { n: number | null; issues: number | null; lastLoaded: string | null; medianLagSeconds: number | null };
  anomalies: Record<string, string | number | null>[];
  alerts: Record<string, string | number | null>[];
}

const pct = (value: number | null) => (value === null ? 'n/a' : `${(value * 100).toFixed(0)}%`);

export default function HomePage() {
  const [data, setData] = useState<PersonalizationData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [attempt, setAttempt] = useState(0);

  useEffect(() => {
    const controller = new AbortController();
    setLoading(true);
    setError(null);
    setData(null);
    fetch('/api/data', { cache: 'no-store', signal: controller.signal })
      .then(async (response) => {
        if (!response.ok) throw new Error('Data request failed');
        const payload = await response.json();
        if (!Array.isArray(payload.kpiCards) || !Array.isArray(payload.entities)) throw new Error('Invalid contract');
        return payload;
      })
      .then(setData)
      .catch(() => {
        if (!controller.signal.aborted) setError('Snowflake data is unavailable. No fallback values are displayed.');
      })
      .finally(() => { if (!controller.signal.aborted) setLoading(false); });
    return () => controller.abort();
  }, [attempt]);

  const isAws = (data?.platform ?? 'aws') === 'aws';
  const awsDiagram = { key: 'aws', title: 'AWS + Snowflake', src: '/architecture-aws.html' };
  const sfDiagram = { key: 'snowflake', title: 'Snowflake Only', src: '/architecture-snowflake.html' };
  const diagrams = isAws ? [awsDiagram, sfDiagram] : [sfDiagram, awsDiagram];
  const kpiVal = (title: string) => data?.kpiCards.find((card) => card.title === title)?.value ?? 'Unavailable';
  const executive = (
    <div className="space-y-6">
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {['Clean Offer Rate', 'Offer Issues Raised', 'Member Opt-outs', 'Attributed Sales (PHP M)'].map((title) => (
          <KPICard key={title} title={title} value={kpiVal(title)} status="neutral" />
        ))}
      </div>
      <p className="text-sm text-slate-600">Clean offer rate = offers without an issue / offers sent. Issue opt-out rate = offer issues that end as member opt-outs / offer issues raised. Attributed sales is the PHP value of baskets that redeemed an offer in the snapshot.</p>
      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <Chart data={data?.timeseries ?? []} type="line" xKey="period"
          yKeys={[{ key: 'issues', name: 'Offer issues raised' }, { key: 'optouts', name: 'Member opt-outs' }]} title="Daily Offer Issues" />
        <Chart data={data?.categories ?? []} type="bar" xKey="category"
          yKeys={[{ key: 'issues', name: 'Offer issues' }, { key: 'optouts', name: 'Opted out' }]} title="Offer Issues and Member Opt-outs by Issue Type" />
      </div>
      <DataTable columns={[
        { key: 'id', header: 'Segment' }, { key: 'region', header: 'City' }, { key: 'category', header: 'Category' },
        { key: 'tier', header: 'Risk tier' }, { key: 'offers', header: 'Offers' }, { key: 'issues', header: 'Offer issues' },
        { key: 'optouts', header: 'Opted out' }, { key: 'spam', header: 'Spam reports' }, { key: 'value', header: 'Attributed Sales (PHP M)' },
      ]} data={data?.entities ?? []} title="Segment observations, 90 days (fictional segments in 5 Philippine cities)" />
    </div>
  );
  const predictive = (
    <div className="space-y-4">
      <h2 className="font-semibold">7-day member opt-out risk and offer-issue forecast</h2>
      <p className="text-sm text-slate-600">
        Snowflake ML classification predicts the probability that a segment has a member opt-out in the next 7 days,
        from the ignore rate, contacts per member per week, recent opt-outs, engagement risk tier, member tenure and category affinity.
      </p>
      {data?.holdout ? (
        <p role="status" className="text-sm text-slate-700">
          Out-of-time holdout ({data.holdout.n} segment-days): precision {pct(data.holdout.precision)} and recall{' '}
          {pct(data.holdout.recall)} at a 0.5 threshold, versus a {pct(data.holdout.baseRate)} base rate.
        </p>
      ) : (
        <p role="status">Model outputs are not deployed. Run snowflake/05_ml.sql.</p>
      )}
      <DataTable columns={[
        { key: 'id', header: 'Segment' }, { key: 'band', header: 'Risk band' },
        { key: 'probability', header: 'P(member opt-out in 7 days)' }, { key: 'scoredAsOf', header: 'Scored as of' },
      ]} data={data?.risk ?? []} title="Member opt-out risk by segment" />
      <Chart data={data?.forecast ?? []} type="line" xKey="period"
        yKeys={[{ key: 'value', name: 'Forecast' }, { key: 'lower', name: 'Lower' }, { key: 'upper', name: 'Upper' }]}
        title="Program-wide offer-issue forecast, next 14 days (issues per day)" />
      <DataTable columns={[
        { key: 'id', header: 'Segment' }, { key: 'date', header: 'Date' }, { key: 'ignoreRate', header: 'Ignore rate (%)' },
        { key: 'expected', header: 'Expected' }, { key: 'upper', header: 'Upper bound' },
      ]} data={data?.anomalies ?? []} title="Ignore rate anomalies, last 15 days (Snowflake ML anomaly detection, trained on the prior 75 days)" />
    </div>
  );
  const liveTab = (
    <div className="space-y-4">
      <h2 className="font-semibold">{isAws ? 'Live offer events: Amazon Data Firehose to S3 to Snowpipe' : 'Live offer events: Snowflake-native simulator'}</h2>
      <p className="text-sm text-slate-600">
        {isAws
          ? 'Simulated offer events are sent to the Firehose stream ph-retail-personalization-offers (aws/publish_offer_events.py). Firehose writes batches to S3, and Snowpipe auto-ingest loads them into RAW.LIVE_OFFER_EVENTS.'
          : 'CALL APP.SIMULATE_OFFER_EVENTS(n) inserts simulated offer events directly into RAW.LIVE_OFFER_EVENTS (or resume APP.TASK_SIMULATE_OFFER_EVENTS for a feed every minute). This simulates an offer event feed; it is not Snowpipe Streaming.'}
        {' '}The alert APP.LIVE_OFFER_ALERT logs ISSUE events and emails the on-call CRM analyst.
      </p>
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <KPICard title="Offer events loaded" value={String(data?.liveSummary?.n ?? 'n/a')} />
        <KPICard title="ISSUE events" value={String(data?.liveSummary?.issues ?? 'n/a')} />
        <KPICard title={isAws ? 'Median send to table lag (s)' : 'Median generated to table lag (s)'} value={String(data?.liveSummary?.medianLagSeconds ?? 'n/a')} />
        <KPICard title="Last load" value={data?.liveSummary?.lastLoaded ?? 'none'} />
      </div>
      <DataTable columns={[
        { key: 'id', header: 'Segment' }, { key: 'eventTs', header: 'Event (UTC)' }, { key: 'amount', header: 'Basket (PHP)' },
        { key: 'sendDelay', header: 'Send delay (min)' }, { key: 'status', header: 'Status' }, { key: 'loadedAt', header: 'Loaded' },
      ]} data={data?.live ?? []} title="Latest 25 offer events" />
      <DataTable columns={[
        { key: 'id', header: 'Segment' }, { key: 'eventTs', header: 'Event (UTC)' }, { key: 'amount', header: 'Basket (PHP)' },
        { key: 'sendDelay', header: 'Send delay (min)' }, { key: 'hint', header: 'Action hint' },
      ]} data={data?.alerts ?? []} title="Alert log" />
    </div>
  );
  const planning = (
    <div className="space-y-6">
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
        <KPICard title="Offer Refresh Compliance" value={kpiVal('Offer Refresh Compliance')} />
        <KPICard title="Consent Record Coverage" value={kpiVal('Consent Record Coverage')} />
        <KPICard title="Consent Records Pending" value={kpiVal('Consent Records Pending')} />
      </div>
      <Chart data={data?.refreshRisk ?? []} type="scatter" xKey="compliance" xName="Creative refresh compliance"
        yKeys={[{ key: 'optouts', name: 'Member opt-outs' }]} yDomain={[0, 'auto']}
        title="Creative refresh compliance (%) vs member opt-outs by segment" />
      <p className="text-sm text-slate-600">Synthetic associations are not evidence that creative refreshes prevented opt-outs.</p>
      <ActionMemo persona={{ name: 'Marisol Dizon', role: 'Head of CRM Personalization (fictional persona)' }} context={{}}
        onGenerate={async () => {
          const r = await fetch('/api/ask', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ mode: 'memo' }) });
          if (!r.ok) throw new Error('memo failed');
          const j = await r.json();
          return { subject: 'Draft CRM personalization actions (synthetic data, human review required)', body: j.answer, urgency: 'review', actions: [] };
        }} />
      <p role="status" className="text-sm text-slate-600">{isAws ? 'Draft generated by Amazon Bedrock (Claude) through a Snowflake external-access function' : 'Draft generated by Snowflake Cortex AI_COMPLETE (Claude Sonnet 4.5)'}, from the KPI, segment, issue-type and risk tables only. No notification is sent.</p>
    </div>
  );
  const ai = (
    <div className="space-y-4">
      <p role="status">Answers come from the Cortex Agent APP.PERSONALIZATION_AGENT. It uses Cortex Analyst over the semantic view APP.PERSONALIZATION_ANALYTICS for metrics, and Cortex Search over synthetic offer-issue handling SOPs for procedures. The generated SQL is shown with each answer.</p>
      <div className="h-[500px]">
        <AskAI title="Ask the loyalty personalization agent" mode="advisor" sampleQuestions={['Which 3 segments have the most member opt-outs?', 'Which segments are high risk this week and what SOP applies?', 'What is the opt-out share by issue type?']}
          onSubmit={async (question) => {
            const r = await fetch('/api/agent', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ question }) });
            if (!r.ok) throw new Error('agent failed');
            const j = await r.json();
            const cites = j.sops?.length ? `\n\nSOPs: ${j.sops.join(', ')}` : '';
            return { answer: `${j.answer}${cites}`, sql: j.sql ?? undefined };
          }} />
      </div>
    </div>
  );
  const architecture = (
    <div className="space-y-4">
      {diagrams.map((d, i) => (
        <div key={d.key} className="space-y-2">
          <h2 className="font-semibold">Architecture: {d.title}{i === 0 ? ' (this deployment)' : ''}</h2>
          <iframe src={d.src} title={`${d.title} architecture diagram`} className="h-[620px] w-full rounded border border-slate-200" />
          <p className="text-sm text-slate-600">Hover a component for details. <a className="underline" href={d.src} target="_blank" rel="noreferrer">Open full screen</a></p>
        </div>
      ))}
      <h2 className="font-semibold">Implementation status</h2>
      <p>Core source: 40 synthetic segments in 5 Philippine cities and 5 category affinities, daily segment observations and aggregate consent record counts. Curated dynamic tables compute numerator/denominator metrics and are suspended after on-demand initialization.</p>
      <p>Application: Next.js server queries the explicit curated contract. Request time and source observation watermark are separate.</p>
      <p>ML: SNOWFLAKE.ML.CLASSIFICATION member opt-out risk model evaluated on a time-based holdout, plus a 14-day offer-issue FORECAST with prediction intervals.</p>
      <p>ML: ANOMALY_DETECTION flags ignore rate outliers per segment over the last 15 days.</p>
      <p>AI: Cortex Agent (Cortex Analyst over a semantic view, plus Cortex Search over SOPs) answers questions. The action memo uses {isAws ? 'Amazon Bedrock Claude through an external-access UDF' : 'Cortex AI_COMPLETE (Claude Sonnet 4.5)'}.</p>
      {isAws ? (
        <>
          <p>AWS ingestion: Amazon Data Firehose to S3 to Snowpipe auto-ingest (SQS) into RAW.LIVE_OFFER_EVENTS, with a Snowflake alert and email on ISSUE events.</p>
          <p>QuickSight: Snowflake DIRECT_QUERY dashboard (daily offer issues, member opt-outs by segment, member opt-out risk) through a PAT-only service user, with a Q topic.</p>
        </>
      ) : (
        <>
          <p>Ingestion: APP.SIMULATE_OFFER_EVENTS inserts simulated offer events into RAW.LIVE_OFFER_EVENTS, with a Snowflake alert and email on ISSUE events. No AWS account is used.</p>
          <p>BI: this SPCS app is the dashboard; natural-language questions go to the Cortex Agent.</p>
        </>
      )}
      <p>Orchestration: the task graph APP.TASK_REFRESH_CURATED, then TASK_RESCORE_RISK, runs on demand. Alerts and tasks stay suspended between demos.</p>
    </div>
  );
  const tabs = [
    { id: 'executive-cockpit', label: 'Executive Cockpit', icon: '', content: executive },
    { id: 'predictive', label: 'Predictive', icon: '', content: predictive },
    { id: 'planning', label: 'Controls', icon: '', content: planning },
    { id: 'live', label: 'Live Offer Events', icon: '', content: liveTab },
    { id: 'ask-ai', label: 'Ask AI', icon: '', content: ai },
    { id: 'architecture', label: 'Architecture & Data', icon: '', content: architecture },
  ].map((tab) => ({ ...tab, content: tab.id === 'architecture' ? tab.content : (
    <div className="space-y-4">
      <p className="text-sm text-slate-600">Synthetic demo data for a fictional Philippine omnichannel retailer. On-demand snapshots are not live customer operations.</p>
      {loading ? <p role="status">Loading Snowflake data...</p> : error ? (
        <div role="alert" className="rounded border border-red-200 p-4">
          <p>{error}</p>
          <button className="mt-3 rounded border px-3 py-2" onClick={() => setAttempt((value) => value + 1)}>Retry data connection</button>
        </div>
      ) : !data?.entities.length ? <p role="status">No segment observations are available in this snapshot.</p> : (
        <>
          <p className="text-sm">Observation watermark: {data.sourceWatermark ?? 'Unavailable'}. Request time: {data.requestedAt}.</p>
          {(data.stale || data.pipelineBehind) && <p role="status" className="text-amber-700">Stale or lagging snapshot. Refresh the on-demand pipeline before presenting current results.</p>}
          {tab.content}
        </>
      )}
    </div>
  ) }));
  return <AppLayout title="Philippines Retail Loyalty Personalization" tabs={tabs} />;
}
