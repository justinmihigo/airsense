import { useEffect, useMemo, useState } from 'react';
import { InfluxDB } from '@influxdata/influxdb-client';

export type InfluxField = 'temperature' | 'humidity' | 'gas_ppm' | 'pm1_0' | 'pm2_5' | 'pm10';

export interface InfluxRecord {
  time: string;
  field: InfluxField;
  value: number;
  device: string;
  ssid?: string;
}

export interface InfluxAlert {
  id: string;
  severity: 'info' | 'warning' | 'critical';
  title: string;
  message: string;
  device: string;
  field: InfluxField;
  value: number;
  threshold: number;
  time: string;
}

interface UseInfluxDataOptions {
  baseUrl?: string;
  bucket?: string;
  org?: string;
  token?: string;
  measurement?: string;
  lookback?: string;
  refreshMs?: number;
}

const DEFAULT_FIELDS: InfluxField[] = ['temperature', 'humidity', 'gas_ppm', 'pm1_0', 'pm2_5', 'pm10'];

const FIELD_LABELS: Record<InfluxField, string> = {
  temperature: 'Temperature',
  humidity: 'Humidity',
  gas_ppm: 'Gas PPM',
  pm1_0: 'PM 1.0',
  pm2_5: 'PM 2.5',
  pm10: 'PM 10',
};

const FIELD_UNITS: Record<InfluxField, string> = {
  temperature: '°C',
  humidity: '%',
  gas_ppm: 'ppm',
  pm1_0: 'µg/m³',
  pm2_5: 'µg/m³',
  pm10: 'µg/m³',
};

const THRESHOLDS: Record<InfluxField, { warning: number; critical: number; lowerIsWorse?: boolean }> = {
  temperature: { warning: 35, critical: 40 },
  humidity: { warning: 35, critical: 20, lowerIsWorse: true },
  gas_ppm: { warning: 500, critical: 800 },
  pm1_0: { warning: 15, critical: 35 },
  pm2_5: { warning: 35, critical: 55 },
  pm10: { warning: 50, critical: 100 },
};

function buildFluxQuery(bucket: string, measurement: string, lookback: string) {
  const fieldFilter = DEFAULT_FIELDS.map((field) => `r._field == "${field}"`).join(' or ');
  return [
    `from(bucket: "${bucket}")`,
    `  |> range(start: ${lookback})`,
    measurement ? `  |> filter(fn: (r) => r._measurement == "${measurement}")` : '',
    `  |> filter(fn: (r) => ${fieldFilter})`,
    '  |> keep(columns: ["_time", "_field", "_value", "device", "ssid"])',
    '  |> sort(columns: ["_time"])',
  ]
    .filter(Boolean)
    .join('\n');
}

function buildQueryCandidates(bucket: string, measurement: string, lookback: string) {
  const queries = [buildFluxQuery(bucket, measurement, lookback)];
  if (measurement) queries.push(buildFluxQuery(bucket, '', lookback));
  return queries;
}

function toChartData(records: InfluxRecord[], field: InfluxField) {
  const fieldRecords = records.filter((r) => r.field === field);
  return {
    id: FIELD_LABELS[field],
    data: fieldRecords.map((r) => ({
      x: new Date(r.time).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
      y: r.value,
    })),
    latest: fieldRecords.at(-1),
  };
}

function createAlert(record: InfluxRecord): InfluxAlert | null {
  const threshold = THRESHOLDS[record.field];
  if (!threshold) return null;
  const isCritical = threshold.lowerIsWorse ? record.value <= threshold.critical : record.value >= threshold.critical;
  const isWarning = threshold.lowerIsWorse ? record.value <= threshold.warning : record.value >= threshold.warning;
  if (!isCritical && !isWarning) return null;
  const severity = isCritical ? 'critical' : 'warning';
  const descriptor = threshold.lowerIsWorse ? 'dropped to' : 'reached';
  const unit = FIELD_UNITS[record.field];
  return {
    id: `${record.field}-${record.device}-${record.time}`,
    severity,
    title: severity === 'critical' ? 'Critical alert' : 'Alert',
    message: `${record.device} ${FIELD_LABELS[record.field]} ${descriptor} ${record.value.toFixed(1)} ${unit}.`,
    device: record.device,
    field: record.field,
    value: record.value,
    threshold: threshold.lowerIsWorse ? threshold.critical : threshold.warning,
    time: record.time,
  };
}

export function useInfluxData({
  baseUrl = import.meta.env.VITE_INFLUX_URL || 'http://192.168.1.64:8086',
  bucket = import.meta.env.VITE_INFLUX_BUCKET || 'Kigali',
  org = import.meta.env.VITE_INFLUX_ORG || '',
  token = import.meta.env.VITE_INFLUX_TOKEN || '',
  measurement = import.meta.env.VITE_INFLUX_MEASUREMENT || '',
  lookback = '-24h',
  refreshMs = 30000,
}: UseInfluxDataOptions = {}) {
  const [records, setRecords] = useState<InfluxRecord[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [lastUpdated, setLastUpdated] = useState<string | null>(null);

  useEffect(() => {
    let mounted = true;
    const fetchData = async () => {
      try {
        if (!token) throw new Error('InfluxDB token not configured (VITE_INFLUX_TOKEN)');
        const influxDB = new InfluxDB({ url: baseUrl, token });
        const queryApi = influxDB.getQueryApi(org);
        let parsed: InfluxRecord[] = [];
        const candidates = buildQueryCandidates(bucket, measurement, lookback);
        for (const query of candidates) {
          const results: InfluxRecord[] = [];
          const runner = new Promise<void>((resolve, reject) => {
            const timer = setTimeout(() => reject(new Error('InfluxDB query timed out')), 10000);
            queryApi.queryRows(query, {
              next: (row, tableMeta) => {
                try {
                  const table = tableMeta.toObject(row);
                  const field = table._field as InfluxField | undefined;
                  const value = Number(table._value);
                  const time = String(table._time);
                  const device = String(table.device || 'Unknown device');
                  const ssid = table.ssid ? String(table.ssid) : undefined;
                  if (field && DEFAULT_FIELDS.includes(field) && !Number.isNaN(value) && time) {
                    results.push({ time, field, value, device, ssid });
                  }
                } catch {}
              },
              error: (err) => { clearTimeout(timer); reject(err); },
              complete: () => { clearTimeout(timer); resolve(); },
            });
          });
          try {
            await runner;
          } catch {
            continue;
          }
          if (results.length > 0) { parsed = results; break; }
        }
        if (mounted) {
          setRecords(parsed);
          setLastUpdated(new Date().toISOString());
          setError(parsed.length === 0 ? 'No InfluxDB records returned' : null);
          setIsLoading(false);
        }
      } catch (err) {
        if (!mounted) return;
        setError(err instanceof Error ? err.message : 'Failed to load InfluxDB data');
        setIsLoading(false);
      }
    };
    fetchData();
    const interval = window.setInterval(fetchData, refreshMs);
    return () => { mounted = false; window.clearInterval(interval); };
  }, [baseUrl, bucket, lookback, measurement, org, refreshMs, token]);

  const series = useMemo(
    () => DEFAULT_FIELDS.reduce<Record<InfluxField, ReturnType<typeof toChartData>>>((acc, field) => {
      acc[field] = toChartData(records, field);
      return acc;
    }, {} as Record<InfluxField, ReturnType<typeof toChartData>>),
    [records],
  );

  const latest = useMemo(
    () => DEFAULT_FIELDS.reduce<Partial<Record<InfluxField, InfluxRecord>>>((acc, field) => {
      const r = records.filter((r) => r.field === field).at(-1);
      if (r) acc[field] = r;
      return acc;
    }, {}),
    [records],
  );

  const alerts = useMemo(
    () => records.map(createAlert).filter((a): a is InfluxAlert => Boolean(a)).slice(-10).reverse(),
    [records],
  );

  return { alerts, error, isLoading, lastUpdated, latest, records, series };
}
