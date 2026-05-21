import React, { useState, useEffect, useCallback, useRef } from 'react';
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
} from 'lucide-react';

const INFLUX_URL = import.meta.env.VITE_INFLUX_URL || 'http://influxdb.airsense.dpdns.org';

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
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function pickTicks(data: { x: string; y: number }[], max = 6): string[] {
  if (data.length <= max) return data.map((d) => d.x);
  const step = Math.ceil(data.length / max);
  return data.filter((_, i) => i % step === 0 || i === data.length - 1).map((d) => d.x);
}

// ---------------------------------------------------------------------------
// Forecast chart with CI band
// ---------------------------------------------------------------------------

function ForecastChart({ points, unit }: { points: ForecastPoint[]; unit: string }) {
  const meanData = points.map((p, i) => ({ x: i + 1, y: Math.round(p.mean * 10) / 10 }));

  // CI band drawn as a custom SVG layer using closure data — no extra series needed
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

  return (
    <ResponsiveLine
      data={[{ id: 'PM2.5 Forecast', data: meanData }]}
      margin={{ top: 8, right: 12, bottom: 44, left: 44 }}
      xScale={{ type: 'linear', min: 1, max: points.length }}
      yScale={{ type: 'linear', min: 0, max: 'auto' }}
      curve="monotoneX"
      colors={['#F59E0B']}
      lineWidth={2}
      pointSize={0}
      enableArea={false}
      enableGridX={false}
      gridYValues={4}
      layers={['grid', 'axes', CIBand as any, 'lines', 'mesh']}
      axisBottom={{
        tickSize: 0,
        tickPadding: 6,
        legend: 'Steps ahead',
        legendPosition: 'middle',
        legendOffset: 36,
        tickValues: points.length <= 24 ? undefined : [1, 12, 24, 36, 48],
      }}
      axisLeft={{ tickSize: 0, tickPadding: 4, tickValues: 4 }}
      animate={false}
      useMesh
      theme={nivoTheme}
      tooltip={({ point }) => {
        const step = point.data.x as number;
        const orig = points[step - 1];
        return (
          <div className="rounded-lg border border-gray-100 bg-white px-2.5 py-1.5 text-xs shadow">
            <span className="font-semibold text-amber-600">
              Step {step}: {(point.data.y as number).toFixed(1)} {unit}
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
// Main page
// ---------------------------------------------------------------------------

const Analytics: React.FC = () => {
  const { series, latest, isLoading, error, lastUpdated } = useInfluxData({
    baseUrl: INFLUX_URL,
    lookback: '-7d',
    refreshMs: 60000,
  });

  const [occupancy, setOccupancy] = useState(1);
  const [recommendation, setRecommendation] = useState<MLRecommendation | null>(null);
  const [aqiPrediction, setAqiPrediction] = useState<AqiPrediction | null>(null);
  const [forecast, setForecast] = useState<ForecastResult | null>(null);
  const [mlLoading, setMlLoading] = useState(false);
  const [mlError, setMlError] = useState<string | null>(null);
  const [insightsOpen, setInsightsOpen] = useState(true);

  // Track last-fetched sensor hash to avoid duplicate calls
  const lastFetchKey = useRef<string>('');

  const fetchInsights = useCallback(async () => {
    setMlLoading(true);
    setMlError(null);
    try {
      const body = {
        pm25: latest.pm2_5?.value ?? null,
        pm10: latest.pm10?.value ?? null,
        co2: latest.gas_ppm?.value ?? null,
        temperature: latest.temperature?.value ?? null,
        humidity: latest.humidity?.value ?? null,
        occupancy,
      };

      const [recRes, aqiRes, fcRes] = await Promise.all([
        api.post('/api/ml/recommend', body),
        api.post('/api/ml/predict/aqi', body),
        api.get('/api/ml/forecast', { params: { steps: 48 } }),
      ]);

      setRecommendation(recRes.data as MLRecommendation);
      setAqiPrediction(aqiRes.data as AqiPrediction);
      setForecast(fcRes.data as ForecastResult);
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
  }, [latest, occupancy]);

  // Auto-fetch once sensor data loads
  useEffect(() => {
    if (isLoading) return;
    const key = `${latest.pm2_5?.value}-${latest.pm10?.value}-${latest.gas_ppm?.value}`;
    if (key === lastFetchKey.current) return;
    lastFetchKey.current = key;
    fetchInsights();
  }, [isLoading]); // eslint-disable-line react-hooks/exhaustive-deps

  const aqiStyle = AQI_STYLE[recommendation?.level ?? 'Unknown'] ?? AQI_STYLE['Unknown'];

  return (
    <div className="min-h-screen bg-[#F6F6FA] p-6">
      {/* Header */}
      <div className="mb-6 flex items-center justify-between">
        <div className="flex items-center gap-2">
          <BarChart2 className="size-5 text-[#22C55E]" />
          <h1 className="text-xl font-bold text-gray-900">Analytics</h1>
          <span className="ml-2 rounded-full bg-gray-100 px-2.5 py-0.5 text-xs text-gray-500">
            Last 7 days
          </span>
        </div>
        <div className="flex items-center gap-3">
          {isLoading && (
            <span className="flex items-center gap-1.5 text-xs text-gray-400">
              <RefreshCw className="size-3 animate-spin" /> Syncing…
            </span>
          )}
          {lastUpdated && !isLoading && (
            <span className="flex items-center gap-1.5 text-xs text-gray-400">
              <RefreshCw className="size-3" />
              Updated {new Date(lastUpdated).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
            </span>
          )}
        </div>
      </div>

      {/* InfluxDB error */}
      {error && (
        <div className="mb-5 flex items-center gap-2 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          <AlertTriangle className="size-4 flex-shrink-0" />
          InfluxDB: {error}
        </div>
      )}

      {/* Summary chips */}
      <div className="mb-6 flex flex-wrap gap-3">
        {FIELDS.map((field) => {
          const cfg = FIELD_CONFIG[field];
          const val = latest[field]?.value;
          return (
            <div key={field} className="flex items-center gap-2 rounded-xl bg-white px-4 py-2.5 shadow-sm">
              <span className="size-2 rounded-full" style={{ backgroundColor: cfg.color }} />
              <span className="text-xs font-medium text-gray-600">{cfg.title}</span>
              <span className="text-sm font-bold" style={{ color: cfg.color }}>
                {isLoading ? '…' : val !== undefined ? `${val.toFixed(1)} ${cfg.unit}` : '--'}
              </span>
            </div>
          );
        })}
      </div>

      {/* ================================================================
          AI INSIGHTS PANEL
         ================================================================ */}
      <div className="mb-6 rounded-2xl border border-gray-200 bg-white shadow-sm">
        {/* Panel header */}
        <div className="flex items-center justify-between border-b border-gray-100 px-5 py-4">
          <div className="flex items-center gap-2">
            <Brain className="size-5 text-indigo-500" />
            <h2 className="text-sm font-semibold text-gray-900">AI Insights</h2>
            <span className="rounded-full bg-indigo-50 px-2 py-0.5 text-[10px] font-medium text-indigo-600">
              ML-powered
            </span>
          </div>
          <div className="flex items-center gap-3">
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
                  {/* Big AQI number */}
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
                      </span>
                    )}
                  </div>

                  {/* AQI scale legend */}
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

                {/* Sensor alerts strip */}
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

                {/* 3-column advice cards */}
                <div className="mb-6 grid grid-cols-1 gap-4 md:grid-cols-3">
                  {/* Health */}
                  <div className="rounded-xl border border-rose-100 bg-rose-50 p-4">
                    <div className="mb-2.5 flex items-center gap-1.5">
                      <Heart className="size-4 text-rose-500" />
                      <span className="text-xs font-semibold text-rose-700">Health</span>
                    </div>
                    <ul className="flex flex-col gap-1.5">
                      {recommendation.health_advice.map((a, i) => (
                        <li key={i} className="text-xs leading-relaxed text-gray-700">
                          {a}
                        </li>
                      ))}
                    </ul>
                  </div>

                  {/* Activity */}
                  <div className="rounded-xl border border-blue-100 bg-blue-50 p-4">
                    <div className="mb-2.5 flex items-center gap-1.5">
                      <Activity className="size-4 text-blue-500" />
                      <span className="text-xs font-semibold text-blue-700">Activity</span>
                    </div>
                    <ul className="flex flex-col gap-1.5">
                      {recommendation.activity_advice.map((a, i) => (
                        <li key={i} className="text-xs leading-relaxed text-gray-700">
                          {a}
                        </li>
                      ))}
                    </ul>
                  </div>

                  {/* Ventilation */}
                  <div className="rounded-xl border border-teal-100 bg-teal-50 p-4">
                    <div className="mb-2.5 flex items-center gap-1.5">
                      <Wind className="size-4 text-teal-500" />
                      <span className="text-xs font-semibold text-teal-700">Ventilation</span>
                    </div>
                    <ul className="flex flex-col gap-1.5">
                      {recommendation.ventilation_advice.map((a, i) => (
                        <li key={i} className="text-xs leading-relaxed text-gray-700">
                          {a}
                        </li>
                      ))}
                    </ul>
                  </div>
                </div>

                {/* PM2.5 Forecast */}
                {forecast ? (
                  <div>
                    <div className="mb-3 flex items-center gap-2">
                      <TrendingUp className="size-4 text-amber-500" />
                      <span className="text-sm font-semibold text-gray-900">
                        PM 2.5 Forecast — next {forecast.steps} steps
                      </span>
                      <span className="rounded-md bg-amber-50 px-2 py-0.5 text-[10px] font-medium text-amber-600">
                        SARIMA · 95% CI band
                      </span>
                      <span className="ml-auto text-xs text-gray-400">{forecast.unit}</span>
                    </div>
                    <div className="h-52">
                      <ForecastChart points={forecast.forecast} unit={forecast.unit} />
                    </div>
                  </div>
                ) : (
                  <div className="flex h-32 flex-col items-center justify-center gap-2 rounded-xl border border-amber-100 bg-amber-50 text-xs text-amber-600">
                    <Cpu className="size-6 opacity-40" />
                    <span>SARIMA model not loaded. Run the forecasting notebook to enable PM2.5 forecasting.</span>
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
          7-DAY TREND CHARTS (3 × 2 grid)
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
                  <p className="text-xs text-gray-400">7-day trend ({cfg.unit})</p>
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
