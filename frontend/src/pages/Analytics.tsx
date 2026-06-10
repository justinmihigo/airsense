import React, { useState, useEffect, useCallback, useMemo, useRef } from 'react';
import { ResponsiveLine } from '@nivo/line';
import { useInfluxData, InfluxField } from '@/hooks/useInfluxData';
import api from '@/lib/api';
import {
  BarChart2,
  RefreshCw,
  AlertTriangle,
  Brain,
  Users,
  Wind,
  Activity,
  Heart,
  ChevronDown,
  ChevronUp,
  TrendingUp,
  Cpu,
  Database,
  Clock,
  ArrowUpRight,
  ArrowDownRight,
  Minus,
  Sliders,
  BarChart3,
} from 'lucide-react';

const INFLUX_URL = import.meta.env.VITE_INFLUX_URL || 'https://influxdb.airsense.dpdns.org';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface MLRecommendation {
  aqi: number | null;
  level: string;
  color: string;
  health_advice: string[];
  activity_advice: string[];
  ventilation_advice: string[];
  sensor_alerts: string[];
}

interface AqiPrediction {
  aqi: number;
  category: string;
  source: string;
}

interface ForecastPoint {
  mean: number;
  lower_ci: number;
  upper_ci: number;
}

interface ForecastResult {
  target: string;
  steps: number;
  unit: string;
  forecast: ForecastPoint[];
  history_used?: number;
  last_observed?: number | null;
  source?: string;
}

interface FieldStats {
  count: number;
  mean: number;
  min: number;
  max: number;
}

interface PollutantPrediction {
  value: number;
  unit: string;
  delta: number | null;
  current: number | null;
}

interface PollutantsResult {
  predictions: Record<string, PollutantPrediction>;
  horizon: string;
}

interface SensitivityPoint {
  x: number;
  aqi: number;
  category: string;
}

interface SensitivityResult {
  vary: string;
  source: string;
  points: SensitivityPoint[];
  baseline: { value: number | null; aqi: number | null };
}

interface FeatureImportanceEntry {
  feature: string;
  importance: number;
}

interface FeatureImportanceResult {
  model: string;
  kind: string;
  top: FeatureImportanceEntry[];
}

type LookbackValue = '-1h' | '-24h' | '-7d' | '-30d';
type AnalysisBasis = 'latest' | 'average';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const RANGES: { v: LookbackValue; label: string; human: string }[] = [
  { v: '-1h', label: '1h', human: 'Last hour' },
  { v: '-24h', label: '24h', human: 'Last 24 hours' },
  { v: '-7d', label: '7d', human: 'Last 7 days' },
  { v: '-30d', label: '30d', human: 'Last 30 days' },
];

const FIELD_CONFIG: Record<InfluxField, { title: string; unit: string; color: string }> = {
  temperature: { title: 'Temperature', unit: '°C',    color: '#22C55E' },
  humidity:    { title: 'Humidity',    unit: '%',     color: '#3B82F6' },
  gas_ppm:     { title: 'Gas PPM',    unit: 'ppm',   color: '#8B5CF6' },
  pm1_0:       { title: 'PM 1.0',     unit: 'µg/m³', color: '#F97316' },
  pm2_5:       { title: 'PM 2.5',     unit: 'µg/m³', color: '#F59E0B' },
  pm10:        { title: 'PM 10',      unit: 'µg/m³', color: '#EF4444' },
};

const FIELDS = Object.keys(FIELD_CONFIG) as InfluxField[];

const AQI_STYLE: Record<string, { bg: string; text: string; border: string; dot: string }> = {
  'Good':                           { bg: 'bg-green-50',  text: 'text-green-700',  border: 'border-green-200',  dot: 'bg-green-500'  },
  'Moderate':                        { bg: 'bg-yellow-50', text: 'text-yellow-700', border: 'border-yellow-200', dot: 'bg-yellow-500' },
  'Unhealthy for Sensitive Groups':  { bg: 'bg-orange-50', text: 'text-orange-700', border: 'border-orange-200', dot: 'bg-orange-500' },
  'Unhealthy':                       { bg: 'bg-red-50',    text: 'text-red-700',    border: 'border-red-200',    dot: 'bg-red-500'    },
  'Very Unhealthy':                  { bg: 'bg-purple-50', text: 'text-purple-700', border: 'border-purple-200', dot: 'bg-purple-500' },
  'Hazardous':                       { bg: 'bg-rose-100',  text: 'text-rose-800',   border: 'border-rose-300',   dot: 'bg-rose-700'   },
  'Unknown':                         { bg: 'bg-gray-50',   text: 'text-gray-500',   border: 'border-gray-200',   dot: 'bg-gray-400'   },
};

const nivoTheme = {
  text: { fontSize: 11, fill: '#9ca3af' },
  grid: { line: { stroke: '#f3f4f6' } },
};

// Field-to-ML-key mapping (frontend uses InfluxField names, ML API expects different keys)
const ML_KEY: Record<InfluxField, string> = {
  pm2_5: 'pm25',
  pm10: 'pm10',
  gas_ppm: 'co2',
  temperature: 'temperature',
  humidity: 'humidity',
  pm1_0: 'pm1',
};

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function pickTicks(data: { x: string; y: number }[], max = 6): string[] {
  if (data.length <= max) return data.map((d) => d.x);
  const step = Math.ceil(data.length / max);
  return data.filter((_, i) => i % step === 0 || i === data.length - 1).map((d) => d.x);
}

function refreshIntervalFor(lookback: LookbackValue): number {
  if (lookback === '-1h') return 15000;
  if (lookback === '-24h') return 30000;
  return 60000;
}

// ---------------------------------------------------------------------------
// Forecast chart with CI band
// ---------------------------------------------------------------------------

function ForecastChart({
  points,
  unit,
  history,
}: {
  points: ForecastPoint[];
  unit: string;
  history: number[];
}) {
  // Show a tail of recent observations to the left of the forecast for visual continuity.
  const tail = history.slice(-Math.min(history.length, Math.max(points.length, 24)));
  const tailLen = tail.length;
  const historyData = tail.map((y, i) => ({ x: i - tailLen + 1, y: Math.round(y * 10) / 10 }));
  const meanData = points.map((p, i) => ({ x: i + 1, y: Math.round(p.mean * 10) / 10 }));

  // Bridge segment so the line visually connects last observation → first forecast point.
  if (historyData.length > 0 && meanData.length > 0) {
    meanData.unshift({ x: 0, y: historyData[historyData.length - 1].y });
  }

  const xMin = historyData.length > 0 ? historyData[0].x : 1;
  const xMax = points.length;

  const CIBand = useCallback(
    ({ xScale, yScale }: { xScale: (v: number) => number; yScale: (v: number) => number }) => {
      if (!points.length) return null;
      const upper = points.map((p, i) => `${xScale(i + 1)},${yScale(p.upper_ci)}`);
      const lower = [...points]
        .reverse()
        .map((p, i) => `${xScale(points.length - i)},${yScale(p.lower_ci)}`);
      return (
        <polygon
          points={[...upper, ...lower].join(' ')}
          fill="#F59E0B"
          fillOpacity={0.18}
        />
      );
    },
    [points],
  );

  const NowMarker = useCallback(
    ({ xScale, innerHeight }: { xScale: (v: number) => number; innerHeight: number }) => (
      <g>
        <line
          x1={xScale(0)}
          x2={xScale(0)}
          y1={0}
          y2={innerHeight}
          stroke="#9ca3af"
          strokeDasharray="3 3"
          strokeWidth={1}
        />
        <text x={xScale(0) + 4} y={10} fontSize={9} fill="#9ca3af">now</text>
      </g>
    ),
    [],
  );

  const series = [{ id: 'PM2.5 Forecast', data: meanData }];
  if (historyData.length > 0) {
    series.unshift({ id: 'Recent observed', data: historyData });
  }

  return (
    <ResponsiveLine
      data={series}
      margin={{ top: 8, right: 12, bottom: 44, left: 44 }}
      xScale={{ type: 'linear', min: xMin, max: xMax }}
      yScale={{ type: 'linear', min: 'auto', max: 'auto' }}
      curve="monotoneX"
      colors={historyData.length > 0 ? ['#9ca3af', '#F59E0B'] : ['#F59E0B']}
      lineWidth={2}
      pointSize={0}
      enableArea={false}
      enableGridX={false}
      gridYValues={4}
      layers={['grid', 'axes', CIBand as any, 'lines', NowMarker as any, 'mesh']}
      axisBottom={{
        tickSize: 0,
        tickPadding: 6,
        legend: 'Steps (← past · future →)',
        legendPosition: 'middle',
        legendOffset: 36,
        tickValues: 5,
      }}
      axisLeft={{ tickSize: 0, tickPadding: 4, tickValues: 4 }}
      animate={false}
      useMesh
      theme={nivoTheme}
      tooltip={({ point }) => {
        const x = point.data.x as number;
        const isForecast = x >= 1;
        const orig = isForecast ? points[x - 1] : null;
        return (
          <div className="rounded-lg border border-gray-100 bg-white px-2.5 py-1.5 text-xs shadow">
            <span className={`font-semibold ${isForecast ? 'text-amber-600' : 'text-gray-600'}`}>
              {isForecast ? `+${x} ahead` : `${x} back`}: {(point.data.y as number).toFixed(1)} {unit}
            </span>
            {orig && (
              <div className="mt-0.5 text-gray-400">
                95% CI: {orig.lower_ci.toFixed(1)} – {orig.upper_ci.toFixed(1)} {unit}
              </div>
            )}
          </div>
        );
      }}
    />
  );
}

// ---------------------------------------------------------------------------
// Sensitivity sweep chart
// ---------------------------------------------------------------------------

function SensitivityChart({ points, vary }: { points: SensitivityPoint[]; vary: string }) {
  const data = points.map((p) => ({ x: p.x, y: Math.round(p.aqi * 10) / 10 }));
  return (
    <div className="h-48">
      <ResponsiveLine
        data={[{ id: `AQI vs ${vary}`, data }]}
        margin={{ top: 8, right: 12, bottom: 40, left: 44 }}
        xScale={{ type: 'linear', min: 'auto', max: 'auto' }}
        yScale={{ type: 'linear', min: 0, max: 'auto' }}
        curve="monotoneX"
        colors={['#A855F7']}
        lineWidth={2}
        pointSize={5}
        pointColor="#fff"
        pointBorderWidth={2}
        pointBorderColor="#A855F7"
        enableArea
        areaOpacity={0.1}
        enableGridX={false}
        gridYValues={4}
        axisBottom={{
          tickSize: 0,
          tickPadding: 6,
          legend: vary,
          legendPosition: 'middle',
          legendOffset: 32,
        }}
        axisLeft={{ tickSize: 0, tickPadding: 4, tickValues: 4, legend: 'AQI', legendOffset: -34, legendPosition: 'middle' }}
        animate={false}
        useMesh
        theme={nivoTheme}
        tooltip={({ point }) => {
          const xVal = point.data.x as number;
          const orig = points.find((p) => p.x === xVal);
          return (
            <div className="rounded-lg border border-gray-100 bg-white px-2.5 py-1.5 text-xs shadow">
              <span className="font-semibold text-purple-600">
                {vary} = {xVal}: AQI {(point.data.y as number).toFixed(1)}
              </span>
              {orig && (
                <div className="mt-0.5 text-gray-400">{orig.category}</div>
              )}
            </div>
          );
        }}
      />
    </div>
  );
}

// ---------------------------------------------------------------------------
// Feature importance bar list
// ---------------------------------------------------------------------------

function ImportanceBars({ entries }: { entries: FeatureImportanceEntry[] }) {
  const max = Math.max(...entries.map((e) => e.importance), 0.0001);
  return (
    <ul className="flex flex-col gap-1.5">
      {entries.map((e) => {
        const pct = (e.importance / max) * 100;
        return (
          <li key={e.feature} className="flex items-center gap-2 text-[11px]">
            <span className="w-32 flex-shrink-0 truncate text-gray-600" title={e.feature}>
              {e.feature}
            </span>
            <div className="relative h-2.5 flex-1 overflow-hidden rounded-full bg-gray-100">
              <div
                className="absolute inset-y-0 left-0 rounded-full bg-teal-500"
                style={{ width: `${pct}%` }}
              />
            </div>
            <span className="w-14 text-right tabular-nums text-gray-500">
              {e.importance.toFixed(3)}
            </span>
          </li>
        );
      })}
    </ul>
  );
}

// ---------------------------------------------------------------------------
// Main page
// ---------------------------------------------------------------------------

const Analytics: React.FC = () => {
  const [lookback, setLookback] = useState<LookbackValue>('-24h');
  const [basis, setBasis] = useState<AnalysisBasis>('average');

  const { series, latest, records, isLoading, error, lastUpdated } = useInfluxData({
    baseUrl: INFLUX_URL,
    lookback,
    refreshMs: refreshIntervalFor(lookback),
  });

  const rangeLabel = RANGES.find((r) => r.v === lookback)?.human ?? 'Last 24 hours';

  // ---- Historical statistics over the selected range ----
  const stats = useMemo(() => {
    const out = {} as Record<InfluxField, FieldStats | null>;
    for (const f of FIELDS) {
      const vals = records.filter((r) => r.field === f).map((r) => r.value);
      if (vals.length === 0) {
        out[f] = null;
        continue;
      }
      let sum = 0;
      let min = Infinity;
      let max = -Infinity;
      for (const v of vals) {
        sum += v;
        if (v < min) min = v;
        if (v > max) max = v;
      }
      out[f] = { count: vals.length, mean: sum / vals.length, min, max };
    }
    return out;
  }, [records]);

  // ---- Value picker: latest snapshot OR historical mean ----
  const valueFor = useCallback(
    (f: InfluxField): number | null => {
      if (basis === 'average') return stats[f]?.mean ?? null;
      return latest[f]?.value ?? null;
    },
    [basis, stats, latest],
  );

  // ---- AI Insights state ----
  const [occupancy, setOccupancy] = useState(1);
  const [recommendation, setRecommendation] = useState<MLRecommendation | null>(null);
  const [aqiPrediction, setAqiPrediction] = useState<AqiPrediction | null>(null);
  const [forecast, setForecast] = useState<ForecastResult | null>(null);
  const [pollutants, setPollutants] = useState<PollutantsResult | null>(null);
  const [sensitivity, setSensitivity] = useState<SensitivityResult | null>(null);
  const [sensitivityVar, setSensitivityVar] = useState<string>('occupancy');
  const [featureImportance, setFeatureImportance] = useState<FeatureImportanceResult | null>(null);
  const [mlLoading, setMlLoading] = useState(false);
  const [mlError, setMlError] = useState<string | null>(null);
  const [insightsOpen, setInsightsOpen] = useState(true);

  const lastFetchKey = useRef<string>('');

  // Chronological PM2.5 history straight from InfluxDB — feeds the SARIMA refit.
  const pm25History = useMemo(
    () =>
      records
        .filter((r) => r.field === 'pm2_5')
        .map((r) => ({ t: r.time, v: r.value }))
        .sort((a, b) => a.t.localeCompare(b.t))
        .map((p) => p.v),
    [records],
  );

  const fetchInsights = useCallback(async () => {
    setMlLoading(true);
    setMlError(null);
    try {
      const body = {
        pm25: valueFor('pm2_5'),
        pm10: valueFor('pm10'),
        co2: valueFor('gas_ppm'),
        temperature: valueFor('temperature'),
        humidity: valueFor('humidity'),
        occupancy,
      };

      const forecastBody = {
        history: pm25History,
        steps: 48,
      };

      const sensitivityBody = {
        reading: body,
        vary: sensitivityVar,
      };

      const [recRes, aqiRes, fcRes, polRes, sensRes, fiRes] = await Promise.all([
        api.post('/api/ml/recommend', body),
        api.post('/api/ml/predict/aqi', body),
        api.post('/api/ml/forecast', forecastBody),
        api.post('/api/ml/predict/pollutants', body).catch(() => ({ data: null })),
        api.post('/api/ml/sensitivity', sensitivityBody).catch(() => ({ data: null })),
        api.get('/api/ml/feature_importance', { params: { model_key: 'xgboost_reg', top: 10 } })
          .catch(() => ({ data: null })),
      ]);

      setRecommendation(recRes.data as MLRecommendation);
      setAqiPrediction(aqiRes.data as AqiPrediction);
      setForecast(fcRes.data as ForecastResult);
      setPollutants(polRes.data as PollutantsResult | null);
      setSensitivity(sensRes.data as SensitivityResult | null);
      setFeatureImportance(fiRes.data as FeatureImportanceResult | null);
    } catch (e: unknown) {
      const msg =
        e instanceof Error
          ? e.message.includes('503') || e.message.includes('Network')
            ? 'ML service is offline. Start the ML API with: cd ml && python api.py'
            : e.message
          : 'ML service unreachable';
      setMlError(msg);
    } finally {
      setMlLoading(false);
    }
  }, [valueFor, occupancy, pm25History, sensitivityVar]);

  // Auto-fetch when range, basis, or sensor data changes meaningfully
  useEffect(() => {
    if (isLoading) return;
    const key = `${lookback}|${basis}|${stats.pm2_5?.mean}|${stats.pm10?.mean}|${stats.gas_ppm?.mean}|${latest.pm2_5?.value}`;
    if (key === lastFetchKey.current) return;
    lastFetchKey.current = key;
    fetchInsights();
  }, [isLoading, lookback, basis, stats, latest]); // eslint-disable-line react-hooks/exhaustive-deps

  const aqiStyle = AQI_STYLE[recommendation?.level ?? 'Unknown'] ?? AQI_STYLE['Unknown'];

  // Inputs that were used for the last ML call — for transparency
  const mlInputs = useMemo(() => {
    return FIELDS
      .filter((f) => f !== 'pm1_0')
      .map((f) => ({
        field: f,
        title: FIELD_CONFIG[f].title,
        unit: FIELD_CONFIG[f].unit,
        value: valueFor(f),
        color: FIELD_CONFIG[f].color,
        mlKey: ML_KEY[f],
      }));
  }, [valueFor]);

  return (
    <div className="min-h-screen bg-[#F6F6FA] p-6">
      {/* ---------------- Header ---------------- */}
      <div className="mb-6 flex flex-wrap items-center justify-between gap-4">
        <div className="flex items-center gap-2">
          <BarChart2 className="size-5 text-[#22C55E]" />
          <h1 className="text-xl font-bold text-gray-900">Analytics</h1>
          <span className="ml-2 inline-flex items-center gap-1 rounded-full bg-gray-100 px-2.5 py-0.5 text-xs text-gray-600">
            <Clock className="size-3" />
            {rangeLabel}
          </span>
        </div>
        <div className="flex items-center gap-3">
          {/* Time range selector */}
          <div className="flex rounded-xl border border-gray-200 bg-white p-1">
            {RANGES.map((r) => (
              <button
                key={r.v}
                onClick={() => setLookback(r.v)}
                className={`rounded-lg px-3 py-1 text-xs font-semibold transition-colors ${
                  lookback === r.v
                    ? 'bg-[#22C55E] text-white shadow-sm'
                    : 'text-gray-600 hover:bg-gray-50'
                }`}
              >
                {r.label}
              </button>
            ))}
          </div>
          {isLoading && (
            <span className="flex items-center gap-1.5 text-xs text-gray-400">
              <RefreshCw className="size-3 animate-spin" /> Syncing…
            </span>
          )}
          {lastUpdated && !isLoading && (
            <span className="flex items-center gap-1.5 text-xs text-gray-400">
              <RefreshCw className="size-3" />
              {new Date(lastUpdated).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
            </span>
          )}
        </div>
      </div>

      {/* ---------------- InfluxDB error ---------------- */}
      {error && (
        <div className="mb-5 flex items-center gap-2 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          <AlertTriangle className="size-4 flex-shrink-0" />
          InfluxDB: {error}
        </div>
      )}

      {/* ---------------- Live "Now" chips ---------------- */}
      <div className="mb-4 flex flex-wrap items-center gap-3">
        <span className="flex items-center gap-1.5 rounded-md bg-green-100 px-2 py-0.5 text-[10px] font-bold uppercase tracking-wide text-green-700">
          <span className="size-1.5 animate-pulse rounded-full bg-green-500" /> Now
        </span>
        {FIELDS.map((field) => {
          const cfg = FIELD_CONFIG[field];
          const val = latest[field]?.value;
          return (
            <div key={field} className="flex items-center gap-2 rounded-xl bg-white px-3 py-1.5 shadow-sm">
              <span className="size-2 rounded-full" style={{ backgroundColor: cfg.color }} />
              <span className="text-xs font-medium text-gray-600">{cfg.title}</span>
              <span className="text-sm font-bold" style={{ color: cfg.color }}>
                {isLoading ? '…' : val !== undefined ? `${val.toFixed(1)} ${cfg.unit}` : '--'}
              </span>
            </div>
          );
        })}
      </div>

      {/* ---------------- Period statistics ---------------- */}
      <div className="mb-6 rounded-2xl border border-gray-200 bg-white p-5 shadow-sm">
        <div className="mb-3 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Database className="size-4 text-gray-500" />
            <h2 className="text-sm font-semibold text-gray-900">
              Period statistics — {rangeLabel}
            </h2>
          </div>
          <span className="text-xs text-gray-400">
            {records.length.toLocaleString()} readings
          </span>
        </div>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-6">
          {FIELDS.map((field) => {
            const cfg = FIELD_CONFIG[field];
            const s = stats[field];
            return (
              <div key={field} className="rounded-xl bg-[#F6F6FA] p-3">
                <div className="mb-1 flex items-center gap-1.5">
                  <span className="size-1.5 rounded-full" style={{ backgroundColor: cfg.color }} />
                  <span className="text-[11px] font-medium text-gray-600">{cfg.title}</span>
                </div>
                {s ? (
                  <>
                    <p className="text-lg font-bold" style={{ color: cfg.color }}>
                      {s.mean.toFixed(1)}
                      <span className="ml-1 text-[10px] font-normal text-gray-400">{cfg.unit}</span>
                    </p>
                    <p className="text-[10px] text-gray-500">
                      {s.min.toFixed(1)} – {s.max.toFixed(1)}
                    </p>
                    <p className="text-[9px] text-gray-400">n = {s.count}</p>
                  </>
                ) : (
                  <p className="text-sm text-gray-400">--</p>
                )}
              </div>
            );
          })}
        </div>
      </div>

      {/* ================================================================
          AI INSIGHTS PANEL
         ================================================================ */}
      <div className="mb-6 rounded-2xl border border-gray-200 bg-white shadow-sm">
        {/* Panel header */}
        <div className="flex flex-wrap items-center justify-between gap-3 border-b border-gray-100 px-5 py-4">
          <div className="flex items-center gap-2">
            <Brain className="size-5 text-indigo-500" />
            <h2 className="text-sm font-semibold text-gray-900">AI Insights</h2>
            <span className="rounded-full bg-indigo-50 px-2 py-0.5 text-[10px] font-medium text-indigo-600">
              ML-powered
            </span>
          </div>
          <div className="flex flex-wrap items-center gap-3">
            {/* Basis toggle */}
            <div className="flex items-center gap-1.5">
              <span className="text-[10px] uppercase tracking-wide text-gray-400">Basis</span>
              <div className="flex rounded-lg border border-gray-200 p-0.5">
                {(['latest', 'average'] as AnalysisBasis[]).map((b) => (
                  <button
                    key={b}
                    onClick={() => setBasis(b)}
                    className={`rounded-md px-2.5 py-1 text-[11px] font-semibold transition-colors ${
                      basis === b
                        ? 'bg-indigo-100 text-indigo-700'
                        : 'text-gray-500 hover:bg-gray-50'
                    }`}
                  >
                    {b === 'latest' ? 'Latest' : `${rangeLabel.replace('Last ', '')} avg`}
                  </button>
                ))}
              </div>
            </div>
            {/* Occupancy */}
            <div className="flex items-center gap-2 rounded-lg border border-gray-200 px-3 py-1.5">
              <Users className="size-3.5 text-gray-400" />
              <span className="text-xs text-gray-500">People:</span>
              <input
                type="number"
                min={0}
                max={50}
                value={occupancy}
                onChange={(e) => setOccupancy(Math.max(0, parseInt(e.target.value) || 0))}
                className="w-10 text-center text-sm font-semibold text-gray-800 focus:outline-none"
              />
            </div>
            <button
              onClick={fetchInsights}
              disabled={mlLoading}
              className="flex items-center gap-1.5 rounded-xl bg-indigo-600 px-3 py-1.5 text-xs font-semibold text-white hover:bg-indigo-700 disabled:opacity-50"
            >
              {mlLoading ? (
                <><RefreshCw className="size-3 animate-spin" /> Analyzing…</>
              ) : (
                <><Brain className="size-3" /> Get Insights</>
              )}
            </button>
            <button
              onClick={() => setInsightsOpen((v) => !v)}
              className="rounded-lg p-1 text-gray-400 hover:bg-gray-100"
            >
              {insightsOpen ? <ChevronUp className="size-4" /> : <ChevronDown className="size-4" />}
            </button>
          </div>
        </div>

        {insightsOpen && (
          <div className="p-5">
            {/* Inputs being sent to the model (transparency) */}
            <div className="mb-4 rounded-xl border border-dashed border-indigo-200 bg-indigo-50/40 px-4 py-3">
              <div className="mb-2 flex items-center gap-2">
                <span className="text-[10px] font-bold uppercase tracking-wide text-indigo-700">
                  Inputs to the model
                </span>
                <span className="text-[10px] text-gray-500">
                  ({basis === 'average'
                    ? `historical mean over ${rangeLabel.toLowerCase()}`
                    : 'most recent reading'})
                </span>
              </div>
              <div className="flex flex-wrap gap-x-4 gap-y-1.5">
                {mlInputs.map((m) => (
                  <span key={m.field} className="flex items-center gap-1.5 text-[11px]">
                    <span className="size-1.5 rounded-full" style={{ backgroundColor: m.color }} />
                    <span className="text-gray-500">{m.title}:</span>
                    <span className="font-semibold text-gray-800">
                      {m.value !== null ? `${m.value.toFixed(1)} ${m.unit}` : '—'}
                    </span>
                  </span>
                ))}
                <span className="flex items-center gap-1.5 text-[11px]">
                  <Users className="size-3 text-gray-400" />
                  <span className="text-gray-500">Occupancy:</span>
                  <span className="font-semibold text-gray-800">{occupancy}</span>
                </span>
              </div>
            </div>

            {/* ML error */}
            {mlError && (
              <div className="mb-4 flex items-start gap-2 rounded-xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">
                <AlertTriangle className="mt-0.5 size-4 flex-shrink-0" />
                <span>{mlError}</span>
              </div>
            )}

            {/* Loading skeleton */}
            {mlLoading && !recommendation && (
              <div className="flex flex-col gap-3">
                <div className="h-24 w-full animate-pulse rounded-xl bg-gray-50" />
                <div className="grid grid-cols-1 gap-3 md:grid-cols-3">
                  {[1, 2, 3].map((i) => (
                    <div key={i} className="h-32 animate-pulse rounded-xl bg-gray-50" />
                  ))}
                </div>
              </div>
            )}

            {recommendation && (
              <>
                {/* AQI + Category row */}
                <div className={`mb-4 flex flex-wrap items-center gap-4 rounded-xl border p-4 ${aqiStyle.bg} ${aqiStyle.border}`}>
                  <div className="flex flex-col items-center">
                    <span className={`text-4xl font-black tabular-nums ${aqiStyle.text}`}>
                      {recommendation.aqi !== null ? Math.round(recommendation.aqi) : '--'}
                    </span>
                    <span className="text-[10px] font-medium uppercase tracking-widest text-gray-400">AQI</span>
                  </div>

                  <div className="flex flex-col gap-1">
                    <div className="flex items-center gap-2">
                      <span className={`size-2.5 rounded-full ${aqiStyle.dot}`} />
                      <span className={`text-base font-bold ${aqiStyle.text}`}>{recommendation.level}</span>
                    </div>
                    {aqiPrediction && (
                      <span className="rounded-md bg-white/70 px-2 py-0.5 text-[10px] font-medium text-gray-500">
                        {aqiPrediction.source.startsWith('model:')
                          ? `Model: ${aqiPrediction.source.replace('model:', '').replace(/_/g, ' ')}`
                          : 'EPA formula fallback'}
                        {' · '}
                        {basis === 'average' ? `${rangeLabel.toLowerCase()} avg` : 'latest reading'}
                      </span>
                    )}
                  </div>

                  <div className="ml-auto flex flex-wrap items-center gap-2">
                    {[
                      { label: 'Good', dot: 'bg-green-500' },
                      { label: 'Moderate', dot: 'bg-yellow-500' },
                      { label: 'USG', dot: 'bg-orange-500' },
                      { label: 'Unhealthy', dot: 'bg-red-500' },
                      { label: 'Very Unhealthy', dot: 'bg-purple-500' },
                      { label: 'Hazardous', dot: 'bg-rose-700' },
                    ].map(({ label, dot }) => (
                      <div key={label} className="flex items-center gap-1">
                        <span className={`size-1.5 rounded-full ${dot}`} />
                        <span className="text-[9px] text-gray-400">{label}</span>
                      </div>
                    ))}
                  </div>
                </div>

                {recommendation.sensor_alerts.length > 0 && (
                  <div className="mb-4 flex flex-wrap gap-2">
                    {recommendation.sensor_alerts.map((alert, i) => (
                      <div
                        key={i}
                        className="flex items-center gap-1.5 rounded-lg border border-red-200 bg-red-50 px-3 py-1.5 text-xs text-red-700"
                      >
                        <AlertTriangle className="size-3 flex-shrink-0" />
                        {alert}
                      </div>
                    ))}
                  </div>
                )}

                <div className="mb-6 grid grid-cols-1 gap-4 md:grid-cols-3">
                  <div className="rounded-xl border border-rose-100 bg-rose-50 p-4">
                    <div className="mb-2.5 flex items-center gap-1.5">
                      <Heart className="size-4 text-rose-500" />
                      <span className="text-xs font-semibold text-rose-700">Health</span>
                    </div>
                    <ul className="flex flex-col gap-1.5">
                      {recommendation.health_advice.map((a, i) => (
                        <li key={i} className="text-xs leading-relaxed text-gray-700">{a}</li>
                      ))}
                    </ul>
                  </div>

                  <div className="rounded-xl border border-blue-100 bg-blue-50 p-4">
                    <div className="mb-2.5 flex items-center gap-1.5">
                      <Activity className="size-4 text-blue-500" />
                      <span className="text-xs font-semibold text-blue-700">Activity</span>
                    </div>
                    <ul className="flex flex-col gap-1.5">
                      {recommendation.activity_advice.map((a, i) => (
                        <li key={i} className="text-xs leading-relaxed text-gray-700">{a}</li>
                      ))}
                    </ul>
                  </div>

                  <div className="rounded-xl border border-teal-100 bg-teal-50 p-4">
                    <div className="mb-2.5 flex items-center gap-1.5">
                      <Wind className="size-4 text-teal-500" />
                      <span className="text-xs font-semibold text-teal-700">Ventilation</span>
                    </div>
                    <ul className="flex flex-col gap-1.5">
                      {recommendation.ventilation_advice.map((a, i) => (
                        <li key={i} className="text-xs leading-relaxed text-gray-700">{a}</li>
                      ))}
                    </ul>
                  </div>
                </div>

                {forecast ? (
                  <div>
                    <div className="mb-3 flex flex-wrap items-center gap-2">
                      <TrendingUp className="size-4 text-amber-500" />
                      <span className="text-sm font-semibold text-gray-900">
                        PM 2.5 Forecast — next {forecast.steps} steps
                      </span>
                      <span className="rounded-md bg-amber-50 px-2 py-0.5 text-[10px] font-medium text-amber-600">
                        SARIMA · 95% CI band
                      </span>
                      {forecast.history_used !== undefined && forecast.history_used > 0 && (
                        <span className="rounded-md bg-gray-100 px-2 py-0.5 text-[10px] font-medium text-gray-600">
                          fit on {forecast.history_used} live readings
                        </span>
                      )}
                      {forecast.last_observed !== undefined && forecast.last_observed !== null && (
                        <span className="rounded-md bg-gray-100 px-2 py-0.5 text-[10px] font-medium text-gray-600">
                          last obs: {forecast.last_observed.toFixed(1)} {forecast.unit}
                        </span>
                      )}
                      <span className="ml-auto text-xs text-gray-400">{forecast.unit}</span>
                    </div>
                    <div className="h-52">
                      <ForecastChart
                        points={forecast.forecast}
                        unit={forecast.unit}
                        history={pm25History}
                      />
                    </div>
                    {forecast.source && (
                      <p className="mt-1 text-right text-[10px] text-gray-400">
                        source: {forecast.source}
                      </p>
                    )}
                  </div>
                ) : (
                  <div className="flex h-32 flex-col items-center justify-center gap-2 rounded-xl border border-amber-100 bg-amber-50 text-xs text-amber-600">
                    <Cpu className="size-6 opacity-40" />
                    <span>
                      {pm25History.length < 10
                        ? `Need at least 10 PM2.5 readings to forecast (have ${pm25History.length}). Increase the time range.`
                        : 'SARIMA forecasting unavailable. Check the ML service.'}
                    </span>
                  </div>
                )}

                {/* Per-pollutant next-step predictions */}
                {pollutants && Object.keys(pollutants.predictions).length > 0 && (
                  <div className="mt-6">
                    <div className="mb-3 flex items-center gap-2">
                      <TrendingUp className="size-4 text-indigo-500" />
                      <span className="text-sm font-semibold text-gray-900">
                        Next-step pollutant prediction
                      </span>
                      <span className="rounded-md bg-indigo-50 px-2 py-0.5 text-[10px] font-medium text-indigo-600">
                        XGBoost · horizon {pollutants.horizon}
                      </span>
                    </div>
                    <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-5">
                      {Object.entries(pollutants.predictions).map(([key, p]) => {
                        const trendIcon =
                          p.delta === null || Math.abs(p.delta) < 0.1
                            ? <Minus className="size-3 text-gray-400" />
                            : p.delta > 0
                            ? <ArrowUpRight className="size-3 text-red-500" />
                            : <ArrowDownRight className="size-3 text-green-500" />;
                        const trendColor =
                          p.delta === null || Math.abs(p.delta) < 0.1
                            ? 'text-gray-500'
                            : p.delta > 0
                            ? 'text-red-600'
                            : 'text-green-600';
                        return (
                          <div key={key} className="rounded-xl border border-gray-100 bg-gray-50 p-3">
                            <div className="text-[10px] font-medium uppercase tracking-wide text-gray-500">
                              {key.replace('_', ' ')}
                            </div>
                            <div className="mt-1 flex items-baseline gap-1">
                              <span className="text-lg font-bold text-gray-900 tabular-nums">
                                {p.value.toFixed(1)}
                              </span>
                              <span className="text-[10px] text-gray-400">{p.unit}</span>
                            </div>
                            {p.delta !== null && (
                              <div className={`flex items-center gap-1 text-[11px] ${trendColor}`}>
                                {trendIcon}
                                <span>
                                  {p.delta > 0 ? '+' : ''}{p.delta.toFixed(1)} vs current
                                </span>
                              </div>
                            )}
                          </div>
                        );
                      })}
                    </div>
                  </div>
                )}

                {/* Sensitivity sweep */}
                {sensitivity && sensitivity.points.length > 0 && (
                  <div className="mt-6">
                    <div className="mb-3 flex flex-wrap items-center gap-2">
                      <Sliders className="size-4 text-purple-500" />
                      <span className="text-sm font-semibold text-gray-900">
                        Sensitivity — what changes AQI?
                      </span>
                      <span className="rounded-md bg-purple-50 px-2 py-0.5 text-[10px] font-medium text-purple-600">
                        {sensitivity.source}
                      </span>
                      <div className="ml-auto flex items-center gap-1.5">
                        <span className="text-[10px] uppercase tracking-wide text-gray-400">Vary</span>
                        <select
                          value={sensitivityVar}
                          onChange={(e) => setSensitivityVar(e.target.value)}
                          className="rounded-lg border border-gray-200 bg-white px-2 py-1 text-[11px] focus:outline-none"
                        >
                          <option value="occupancy">Occupancy</option>
                          <option value="pm25">PM 2.5</option>
                          <option value="pm10">PM 10</option>
                          <option value="co2">CO₂</option>
                          <option value="temperature">Temperature</option>
                          <option value="humidity">Humidity</option>
                        </select>
                      </div>
                    </div>
                    <SensitivityChart points={sensitivity.points} vary={sensitivity.vary} />
                    {sensitivity.baseline.value !== null && sensitivity.baseline.aqi !== null && (
                      <p className="mt-2 text-[11px] text-gray-500">
                        Baseline: <strong>{sensitivity.baseline.value}</strong> {sensitivityVar} → AQI{' '}
                        <strong>{sensitivity.baseline.aqi.toFixed(1)}</strong>
                      </p>
                    )}
                  </div>
                )}

                {/* Feature importance */}
                {featureImportance && featureImportance.top.length > 0 && (
                  <div className="mt-6">
                    <div className="mb-3 flex items-center gap-2">
                      <BarChart3 className="size-4 text-teal-500" />
                      <span className="text-sm font-semibold text-gray-900">
                        What drives the AQI model
                      </span>
                      <span className="rounded-md bg-teal-50 px-2 py-0.5 text-[10px] font-medium text-teal-600">
                        {featureImportance.model} · {featureImportance.kind}
                      </span>
                    </div>
                    <div className="rounded-xl border border-gray-100 bg-white p-4">
                      <ImportanceBars entries={featureImportance.top} />
                    </div>
                  </div>
                )}
              </>
            )}

            {!recommendation && !mlLoading && !mlError && (
              <div className="flex flex-col items-center justify-center py-10 text-gray-400">
                <Brain className="mb-2 size-8 opacity-30" />
                <p className="text-sm">Click "Get Insights" to run the ML analysis.</p>
              </div>
            )}
          </div>
        )}
      </div>

      {/* ================================================================
          TREND CHARTS
         ================================================================ */}
      <div className="grid grid-cols-1 gap-5 md:grid-cols-2 xl:grid-cols-3">
        {FIELDS.map((field) => {
          const cfg = FIELD_CONFIG[field];
          const s = series[field];
          const hasData = s && s.data.length > 0;
          const ticks = hasData ? pickTicks(s.data) : [];

          return (
            <div key={field} className="rounded-2xl bg-white p-5 shadow-sm">
              <div className="mb-3 flex items-start justify-between">
                <div>
                  <h3 className="text-sm font-semibold text-gray-900">{cfg.title}</h3>
                  <p className="text-xs text-gray-400">
                    {rangeLabel} ({cfg.unit})
                  </p>
                </div>
                {s?.latest && (
                  <span
                    className="rounded-lg px-2 py-1 text-xs font-bold"
                    style={{ backgroundColor: `${cfg.color}18`, color: cfg.color }}
                  >
                    {s.latest.value.toFixed(1)} {cfg.unit}
                  </span>
                )}
              </div>

              <div className="h-44">
                {isLoading ? (
                  <div className="h-full w-full animate-pulse rounded-xl bg-gray-50" />
                ) : hasData ? (
                  <ResponsiveLine
                    data={[{ id: cfg.title, data: s.data }]}
                    margin={{ top: 8, right: 8, bottom: 36, left: 40 }}
                    xScale={{ type: 'point' }}
                    yScale={{ type: 'linear', min: 'auto', max: 'auto' }}
                    curve="monotoneX"
                    colors={[cfg.color]}
                    lineWidth={2}
                    pointSize={s.data.length < 40 ? 3 : 0}
                    pointColor="#fff"
                    pointBorderWidth={2}
                    pointBorderColor={cfg.color}
                    enableArea
                    areaOpacity={0.08}
                    enableGridX={false}
                    gridYValues={4}
                    axisBottom={{
                      tickSize: 0,
                      tickPadding: 6,
                      tickRotation: -25,
                      tickValues: ticks,
                    }}
                    axisLeft={{ tickSize: 0, tickPadding: 4, tickValues: 4 }}
                    animate={false}
                    useMesh
                    theme={nivoTheme}
                    tooltip={({ point }) => (
                      <div className="rounded-lg border border-gray-100 bg-white px-2.5 py-1.5 text-xs shadow">
                        <span className="font-semibold" style={{ color: point.seriesColor }}>
                          {point.data.yFormatted} {cfg.unit}
                        </span>
                        <span className="ml-1.5 text-gray-400">{point.data.xFormatted}</span>
                      </div>
                    )}
                  />
                ) : (
                  <div className="flex h-full flex-col items-center justify-center gap-1 text-xs text-gray-400">
                    <BarChart2 className="size-6 opacity-30" />
                    No data — check InfluxDB connection
                  </div>
                )}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
};

export default Analytics;
