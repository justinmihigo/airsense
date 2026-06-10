import React, { useEffect, useRef, useState } from 'react';
import { ResponsiveLine } from '@nivo/line';
import { useAuth } from '@/hooks/useAuth';
import { useInfluxData } from '@/hooks/useInfluxData';
import { useAlertNotifier } from '@/hooks/useAlertNotifier';
import { useMQTT, SensorData } from '@/hooks/useMQTT';
import api from '@/lib/api';
import {
  Activity,
  AlertTriangle,
  CheckCircle2,
  Cpu,
  Droplets,
  MapPin,
  RefreshCw,
  Thermometer,
  Wind,
  Zap,
} from 'lucide-react';

const GOOGLE_MAPS_KEY = import.meta.env.VITE_GOOGLE_MAPS_KEY || '';

interface Device {
  id: string;
  name: string;
  location: string;
  device_id: string;
  status: string;
  latitude: number | null;
  longitude: number | null;
}

// ---------------------------------------------------------------------------
// Google Maps — live MQTT position as primary pin, device registry as fallback
// ---------------------------------------------------------------------------
function SensorMap({ mqttData }: { mqttData: SensorData | null }) {
  const mapRef = useRef<HTMLDivElement>(null);
  const mapInstance = useRef<google.maps.Map | null>(null);
  const liveMarker = useRef<google.maps.marker.AdvancedMarkerElement | null>(null);
  const liveInfo = useRef<google.maps.InfoWindow | null>(null);
  const [mapsReady, setMapsReady] = useState(
    !!(window as unknown as { google?: { maps?: object } }).google?.maps,
  );

  // Load Maps JS API with the marker library
  useEffect(() => {
    if ((window as unknown as { google?: { maps?: object } }).google?.maps) {
      setMapsReady(true);
      return;
    }
    if (!GOOGLE_MAPS_KEY) return;
    const script = document.createElement('script');
    script.src = `https://maps.googleapis.com/maps/api/js?key=${GOOGLE_MAPS_KEY}&libraries=marker`;
    script.async = true;
    script.onload = () => setMapsReady(true);
    document.head.appendChild(script);
  }, []);

  // Initialise map once
  useEffect(() => {
    if (!mapsReady || !mapRef.current || mapInstance.current) return;
    mapInstance.current = new google.maps.Map(mapRef.current, {
      mapId: 'airsense_sensor_map', // required for AdvancedMarkerElement
      center: { lat: -1.9441, lng: 30.0619 },
      zoom: 14,
      mapTypeControl: false,
      streetViewControl: false,
      fullscreenControl: false,
    });
  }, [mapsReady]);

  // Move / create live marker on every MQTT position update
  useEffect(() => {
    if (!mapsReady || !mapInstance.current) return;
    if (!mqttData?.latitude || !mqttData?.longitude) return;

    const pos = { lat: mqttData.latitude, lng: mqttData.longitude };

    if (!liveMarker.current) {
      const pin = new google.maps.marker.PinElement({
        background: '#22C55E',
        borderColor: '#fff',
        glyphColor: '#fff',
        scale: 1.3,
      });

      liveMarker.current = new google.maps.marker.AdvancedMarkerElement({
        position: pos,
        map: mapInstance.current,
        title: mqttData.device || 'AirSense Sensor',
        content: pin,
      });

      liveInfo.current = new google.maps.InfoWindow();
      liveMarker.current.addEventListener('click', () => {
        liveInfo.current!.open(mapInstance.current!, liveMarker.current!);
      });
    } else {
      liveMarker.current.position = pos;
    }

    liveInfo.current!.setContent(`
      <div style="font-size:13px;font-weight:700;margin-bottom:4px">
        📡 ${mqttData.device || 'AirSense Sensor'}
      </div>
      <div style="font-size:11px;color:#6b7280;margin-bottom:6px">
        ${pos.lat.toFixed(6)}, ${pos.lng.toFixed(6)}
      </div>
      <table style="font-size:11px;border-collapse:collapse">
        <tr><td style="padding:1px 6px 1px 0;color:#6b7280">PM 2.5</td><td style="font-weight:600">${mqttData.pm2_5?.toFixed(1)} µg/m³</td></tr>
        <tr><td style="padding:1px 6px 1px 0;color:#6b7280">PM 10</td><td style="font-weight:600">${mqttData.pm10?.toFixed(1)} µg/m³</td></tr>
        <tr><td style="padding:1px 6px 1px 0;color:#6b7280">CO₂</td><td style="font-weight:600">${mqttData.gas_ppm?.toFixed(0)} ppm</td></tr>
        <tr><td style="padding:1px 6px 1px 0;color:#6b7280">Temp</td><td style="font-weight:600">${mqttData.temperature?.toFixed(1)} °C</td></tr>
        <tr><td style="padding:1px 6px 1px 0;color:#6b7280">Humidity</td><td style="font-weight:600">${mqttData.humidity?.toFixed(1)} %</td></tr>
      </table>
    `);

    mapInstance.current.panTo(pos);
  }, [mapsReady, mqttData]);

  if (!GOOGLE_MAPS_KEY) {
    return (
      <div className="flex h-full flex-col items-center justify-center gap-2 rounded-xl bg-gray-50 text-gray-400">
        <MapPin className="size-8 opacity-30" />
        <p className="text-xs">
          Set <code className="rounded bg-gray-100 px-1">VITE_GOOGLE_MAPS_KEY</code> to enable the map.
        </p>
        {mqttData?.latitude && mqttData?.longitude && (
          <p className="text-xs">
            Live position: {mqttData.latitude.toFixed(5)}, {mqttData.longitude.toFixed(5)}
          </p>
        )}
      </div>
    );
  }

  return (
    <div className="relative h-full w-full">
      <div ref={mapRef} className="h-full w-full rounded-xl" />
      {mqttData?.latitude && (
        <div className="absolute bottom-2 left-2 flex items-center gap-1.5 rounded-lg bg-white/90 px-2.5 py-1.5 text-xs shadow backdrop-blur-sm">
          <span className="size-2 animate-pulse rounded-full bg-green-500" />
          <span className="font-medium text-gray-700">{mqttData.device || 'Sensor'}</span>
          <span className="text-gray-400">
            {mqttData.latitude.toFixed(5)}, {mqttData.longitude.toFixed(5)}
          </span>
        </div>
      )}
    </div>
  );
}

const INFLUX_URL = import.meta.env.VITE_INFLUX_URL || 'http://influxdb.airsense.dpdns.org';
const MQTT_URL = import.meta.env.VITE_MQTT_URL || 'ws://192.168.1.64:9001/mqtt';
const MQTT_TOPIC = import.meta.env.VITE_MQTT_TOPIC || 'sensors/indoor/airquality';

const CHART_COLORS: Record<string, string> = {
  Temperature: '#22C55E',
  Humidity: '#3B82F6',
  'PM 2.5': '#F59E0B',
  'Gas PPM': '#EF4444',
};

const metricCards = [
  { label: 'Temperature', field: 'temperature' as const, mqttKey: 'temperature' as keyof SensorData, icon: Thermometer, unit: '°C', color: '#f97316' },
  { label: 'Humidity',    field: 'humidity'    as const, mqttKey: 'humidity'    as keyof SensorData, icon: Droplets,   unit: '%',    color: '#3b82f6' },
  { label: 'Gas PPM',     field: 'gas_ppm'     as const, mqttKey: 'gas_ppm'     as keyof SensorData, icon: Wind,       unit: 'ppm',  color: '#8b5cf6' },
  { label: 'PM 1.0',      field: 'pm1_0'       as const, mqttKey: 'pm1_0'       as keyof SensorData, icon: Activity,   unit: 'µg/m³',color: '#22c55e' },
  { label: 'PM 2.5',      field: 'pm2_5'       as const, mqttKey: 'pm2_5'       as keyof SensorData, icon: Zap,        unit: 'µg/m³',color: '#eab308' },
  { label: 'PM 10',       field: 'pm10'        as const, mqttKey: 'pm10'        as keyof SensorData, icon: Cpu,        unit: 'µg/m³',color: '#ef4444' },
];

const charts = [
  { key: 'temperature' as const, title: 'Temperature', unit: '°C' },
  { key: 'humidity'    as const, title: 'Humidity',    unit: '%'  },
  { key: 'pm2_5'      as const, title: 'PM 2.5',      unit: 'µg/m³' },
  { key: 'gas_ppm'    as const, title: 'Gas PPM',     unit: 'ppm' },
];

function pickTicks(data: { x: string; y: number }[], max = 5): string[] {
  if (data.length <= max) return data.map((d) => d.x);
  const step = Math.ceil(data.length / max);
  return data.filter((_, i) => i % step === 0 || i === data.length - 1).map((d) => d.x);
}

function MiniChart({ id, data, color }: { id: string; data: { x: string; y: number }[]; color: string }) {
  if (data.length === 0) {
    return <div className="flex h-full items-center justify-center text-xs text-gray-400">No data</div>;
  }
  const ticks = pickTicks(data);
  return (
    <ResponsiveLine
      data={[{ id, data }]}
      margin={{ top: 8, right: 8, bottom: 32, left: 36 }}
      xScale={{ type: 'point' }}
      yScale={{ type: 'linear', min: 'auto', max: 'auto' }}
      curve="monotoneX"
      colors={[color]}
      lineWidth={2}
      pointSize={data.length < 30 ? 4 : 0}
      pointColor="#fff"
      pointBorderWidth={2}
      pointBorderColor={color}
      enableArea
      areaOpacity={0.08}
      enableGridX={false}
      gridYValues={4}
      axisBottom={{ tickSize: 0, tickPadding: 6, tickRotation: -20, tickValues: ticks }}
      axisLeft={{ tickSize: 0, tickPadding: 4, tickValues: 4 }}
      animate={false}
      useMesh
      theme={{
        text: { fontSize: 10, fill: '#9ca3af' },
        grid: { line: { stroke: '#f3f4f6' } },
      }}
      tooltip={({ point }) => (
        <div className="rounded-lg border border-gray-100 bg-white px-2 py-1 text-xs shadow">
          <span className="font-semibold" style={{ color: point.seriesColor }}>{point.data.yFormatted}</span>
          <span className="ml-1 text-gray-400">{point.data.xFormatted}</span>
        </div>
      )}
    />
  );
}

const Dashboard: React.FC = () => {
  const { user } = useAuth();

  const { latest, series, alerts, isLoading, error: influxError, lastUpdated } = useInfluxData({
    baseUrl: INFLUX_URL,
    lookback: '-24h',
    refreshMs: 30000,
  });

  // Forwards new sensor alerts to the backend (server enforces 10-min cooldown)
  // and surfaces them as browser notifications. Email is sent server-side per user prefs.
  useAlertNotifier(alerts);

  const { data: mqttData, isConnected, error: mqttError } = useMQTT({
    brokerUrl: MQTT_URL,
    topic: MQTT_TOPIC,
  });

  const [devices, setDevices] = useState<Device[]>([]);
  const seenDeviceIds = useRef<Set<string>>(new Set());

  useEffect(() => {
    api.get<Device[]>('/api/devices').then(({ data }) => {
      setDevices(data);
      data.forEach((d) => seenDeviceIds.current.add(d.device_id));
    }).catch(() => null);
  }, []);

  // Auto-register device when MQTT data arrives from an unregistered device
  useEffect(() => {
    if (!mqttData?.device) return;
    if (seenDeviceIds.current.has(mqttData.device)) {
      return;
    }
    seenDeviceIds.current.add(mqttData.device);
    api
      .post<Device>('/api/devices/auto-register', {
        device_id: mqttData.device,
        latitude: mqttData.latitude ?? null,
        longitude: mqttData.longitude ?? null,
      })
      .then(({ data }) => {
        setDevices((prev) => {
          if (prev.some((d) => d.device_id === data.device_id)) return prev;
          return [...prev, data];
        });
      })
      .catch(() => null);
  }, [mqttData?.device]);

  return (
    <div className="min-h-screen bg-[#F6F6FA] p-6">
      {/* Header */}
      <div className="mb-6 flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Dashboard</h1>
          <p className="text-sm text-gray-500">
            Welcome back, <span className="font-medium text-[#22C55E]">{user?.name ?? 'User'}</span>
          </p>
        </div>
        <div className="flex items-center gap-3">
          <div className={`flex items-center gap-1.5 rounded-full px-3 py-1.5 text-xs font-medium ${isConnected ? 'bg-green-100 text-green-700' : 'bg-gray-100 text-gray-500'}`}>
            <span className={`size-1.5 rounded-full ${isConnected ? 'animate-pulse bg-green-500' : 'bg-gray-400'}`} />
            {isConnected ? 'MQTT Live' : 'MQTT Offline'}
          </div>
          <div className={`flex items-center gap-1.5 rounded-full px-3 py-1.5 text-xs font-medium ${!influxError && !isLoading ? 'bg-blue-100 text-blue-700' : 'bg-gray-100 text-gray-500'}`}>
            <span className={`size-1.5 rounded-full ${!influxError && !isLoading ? 'bg-blue-500' : 'bg-gray-400'}`} />
            {isLoading ? 'Syncing…' : influxError ? 'InfluxDB Error' : 'InfluxDB OK'}
          </div>
          {lastUpdated && !isLoading && (
            <span className="flex items-center gap-1 text-xs text-gray-400">
              <RefreshCw className="size-3" />
              {new Date(lastUpdated).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
            </span>
          )}
        </div>
      </div>

      {/* Error banners */}
      {mqttError && (
        <div className="mb-3 rounded-xl border border-amber-200 bg-amber-50 px-4 py-2.5 text-sm text-amber-700">
          MQTT: {mqttError}
        </div>
      )}
      {influxError && (
        <div className="mb-3 rounded-xl border border-red-200 bg-red-50 px-4 py-2.5 text-sm text-red-700">
          InfluxDB: {influxError}
        </div>
      )}

      {/* Live MQTT strip */}
      {/* {mqttData && (
        <div className="mb-6 rounded-xl bg-white p-4 shadow-sm">
          <div className="mb-2 flex items-center gap-2">
            <span className="size-2 animate-pulse rounded-full bg-green-500" />
            <span className="text-xs font-semibold uppercase tracking-wide text-gray-600">
              Live — {mqttData.device}
            </span>
            {mqttData.timestamp && (
              <span className="ml-auto text-xs text-gray-400">
                {new Date(mqttData.timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' })}
              </span>
            )}
          </div>
          <div className="flex flex-wrap gap-4">
            {[
              { label: 'Temp', value: mqttData.temperature, unit: '°C' },
              { label: 'Humidity', value: mqttData.humidity, unit: '%' },
              { label: 'Gas', value: mqttData.gas_ppm, unit: 'ppm' },
              { label: 'PM 1.0', value: mqttData.pm1_0, unit: 'µg/m³' },
              { label: 'PM 2.5', value: mqttData.pm2_5, unit: 'µg/m³' },
              { label: 'PM 10', value: mqttData.pm10, unit: 'µg/m³' },
            ].map((m) => (
              <div key={m.label} className="flex flex-col items-center">
                <span className="text-lg font-bold text-gray-900">{m.value.toFixed(1)}</span>
                <span className="text-xs text-gray-500">{m.label} <span className="text-gray-400">({m.unit})</span></span>
              </div>
            ))}
          </div>
        </div>
      )} */}

      {/* Metric cards — MQTT primary, InfluxDB fallback */}
      <div className="mb-6 grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-6">
        {metricCards.map(({ label, field, mqttKey, icon: Icon, unit, color }) => {
          const liveValue: number | null = mqttData
            ? (mqttData[mqttKey] as number)
            : (latest[field]?.value ?? null);

          return (
            <div key={field} className="rounded-xl bg-white p-4 shadow-sm">
              <div className="mb-2 flex items-center justify-between">
                <span className="text-xs font-medium text-gray-500">{label}</span>
                <Icon className="size-4" style={{ color }} />
              </div>
              {isLoading && !mqttData ? (
                <div className="h-7 w-16 animate-pulse rounded bg-gray-100" />
              ) : liveValue !== null ? (
                <span className="text-2xl font-bold text-gray-900">
                  {liveValue.toFixed(1)}
                  <span className="ml-1 text-sm font-normal text-gray-400">{unit}</span>
                </span>
              ) : (
                <span className="text-sm text-gray-400">--</span>
              )}
            </div>
          );
        })}
      </div>

      {/* 4 live charts from InfluxDB */}
      <div className="mb-6 grid grid-cols-1 gap-4 md:grid-cols-2">
        {charts.map(({ key, title, unit }) => {
          const s = series[key];
          const color = CHART_COLORS[s?.id ?? ''] ?? '#22C55E';
          const hasData = s && s.data.length > 0;

          return (
            <div key={key} className="rounded-xl bg-white p-5 shadow-sm">
              <div className="mb-3 flex items-center justify-between">
                <div>
                  <h3 className="text-sm font-semibold text-gray-900">{title}</h3>
                  <p className="text-xs text-gray-400">Last 24h ({unit})</p>
                </div>
                {s?.latest && (
                  <span className="text-sm font-bold" style={{ color }}>
                    {s.latest.value.toFixed(1)} {unit}
                  </span>
                )}
              </div>
              <div className="h-40">
                {isLoading ? (
                  <div className="h-full w-full animate-pulse rounded-lg bg-gray-50" />
                ) : hasData ? (
                  <MiniChart id={s.id} data={s.data} color={color} />
                ) : (
                  <div className="flex h-full items-center justify-center text-xs text-gray-400">
                    No data — check InfluxDB connection
                  </div>
                )}
              </div>
            </div>
          );
        })}
      </div>

      {/* Alerts */}
      <div className="mb-6 rounded-xl bg-white p-5 shadow-sm">
        <div className="mb-3 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <AlertTriangle className="size-4 text-amber-500" />
            <h2 className="text-sm font-semibold text-gray-900">Sensor Alerts</h2>
          </div>
          <span className="text-xs text-gray-400">{alerts.length} active</span>
        </div>
        {isLoading ? (
          <div className="h-8 w-40 animate-pulse rounded-lg bg-gray-100" />
        ) : alerts.length > 0 ? (
          <div className="grid gap-2 md:grid-cols-2">
            {alerts.slice(0, 6).map((alert) => (
              <div
                key={alert.id}
                className={`flex items-start gap-3 rounded-xl border p-3 ${
                  alert.severity === 'critical'
                    ? 'border-red-200 bg-red-50'
                    : 'border-amber-200 bg-amber-50'
                }`}
              >
                <AlertTriangle
                  className={`mt-0.5 size-4 flex-shrink-0 ${
                    alert.severity === 'critical' ? 'text-red-500' : 'text-amber-500'
                  }`}
                />
                <div className="min-w-0 flex-1">
                  <p className={`text-xs font-semibold ${alert.severity === 'critical' ? 'text-red-700' : 'text-amber-700'}`}>
                    {alert.title}
                  </p>
                  <p className="truncate text-xs text-gray-600">{alert.message}</p>
                </div>
                <span className="flex-shrink-0 text-[10px] text-gray-400">
                  {new Date(alert.time).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                </span>
              </div>
            ))}
          </div>
        ) : (
          <div className="flex items-center gap-2 rounded-xl border border-green-200 bg-green-50 px-4 py-2.5 text-sm text-green-700">
            <CheckCircle2 className="size-4" /> All readings within normal range
          </div>
        )}
      </div>

      {/* Sensor map + devices side-by-side */}
      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        {/* Google Maps */}
        <div className="rounded-xl bg-white p-5 shadow-sm">
          <div className="mb-3 flex items-center gap-2">
            <MapPin className="size-4 text-[#22C55E]" />
            <h2 className="text-sm font-semibold text-gray-900">Sensor Locations</h2>
          </div>
          <div className="h-72">
            <SensorMap mqttData={mqttData} />
          </div>
        </div>

        {/* Active devices list */}
        <div className="rounded-xl bg-white p-5 shadow-sm">
          <div className="mb-3 flex items-center justify-between">
            <h2 className="text-sm font-semibold text-gray-900">Active Devices</h2>
            <a
              href="/devices"
              className="rounded-lg bg-[#22C55E] px-3 py-1.5 text-xs font-semibold text-white hover:bg-[#16A34A]"
            >
              Manage
            </a>
          </div>

          {devices.length === 0 ? (
            <div className="flex h-60 flex-col items-center justify-center text-gray-400">
              <Cpu className="mb-2 size-8 opacity-30" />
              <p className="text-sm">No devices registered yet.</p>
            </div>
          ) : (
            <div className="flex flex-col gap-3 overflow-y-auto" style={{ maxHeight: '17rem' }}>
              {devices.map((device) => (
                <div key={device.id} className="rounded-xl border border-gray-100 p-4">
                  <div className="mb-3 flex items-center justify-between">
                    <div>
                      <p className="text-sm font-semibold text-gray-900">{device.name}</p>
                      <p className="text-xs text-gray-500">{device.location}</p>
                    </div>
                    <span className={`flex items-center gap-1 rounded-full px-2.5 py-0.5 text-xs font-medium ${device.status === 'active' ? 'bg-green-100 text-green-700' : 'bg-gray-100 text-gray-500'}`}>
                      <span className={`size-1.5 rounded-full ${device.status === 'active' ? 'animate-pulse bg-green-500' : 'bg-gray-400'}`} />
                      {device.status}
                    </span>
                  </div>
                  <div className="grid grid-cols-3 gap-2">
                    {metricCards.map(({ label, field, mqttKey, unit, color }) => {
                      const v = mqttData ? (mqttData[mqttKey] as number) : (latest[field]?.value ?? null);
                      return (
                        <div key={field} className="flex flex-col items-center rounded-lg bg-[#F6F6FA] p-2">
                          <span className="text-sm font-bold" style={{ color }}>
                            {v !== null ? v.toFixed(0) : '--'}
                          </span>
                          <span className="text-[10px] text-gray-500">{label}</span>
                          <span className="text-[9px] text-gray-400">{unit}</span>
                        </div>
                      );
                    })}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default Dashboard;
