import { useEffect, useRef, useState } from 'react';
import mqtt from 'mqtt';

export interface SensorData {
  device: string;
  temperature: number;
  humidity: number;
  gas_ppm: number;
  pm1_0: number;
  pm2_5: number;
  pm10: number;
  latitude: number;
  longitude: number;
  timestamp?: string;
}

interface UseMQTTOptions {
  brokerUrl: string;
  topic: string;
  onData?: (data: SensorData) => void;
}

export function useMQTT({ brokerUrl, topic, onData }: UseMQTTOptions) {
  const [data, setData] = useState<SensorData | null>(null);
  const [isConnected, setIsConnected] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const clientRef = useRef<mqtt.MqttClient | null>(null);
  const isMountedRef = useRef(true);
  const onDataRef = useRef(onData);

  useEffect(() => { onDataRef.current = onData; }, [onData]);

  useEffect(() => {
    isMountedRef.current = true;
    try {
      if (clientRef.current?.connected) return;
      if (isMountedRef.current) setError(null);
      const client = mqtt.connect(brokerUrl, {
        reconnectPeriod: 3000,
        connectTimeout: 30000,
        clean: true,
        keepalive: 60,
      });
      clientRef.current = client;
      client.on('connect', () => {
        if (isMountedRef.current) setIsConnected(true);
        client.subscribe(topic, (err) => {
          if (err && isMountedRef.current) setError('Failed to subscribe to topic');
        });
      });
      client.on('message', (_topic: string, message: Buffer) => {
        try {
          const payload = JSON.parse(message.toString()) as SensorData;
          payload.timestamp = new Date().toISOString();
          if (isMountedRef.current) {
            setData(payload);
            onDataRef.current?.(payload);
          }
        } catch {
          if (isMountedRef.current) setError('Failed to parse sensor data');
        }
      });
      client.on('error', (err) => {
        if (isMountedRef.current) { setError(err.message); setIsConnected(false); }
      });
      client.on('offline', () => { if (isMountedRef.current) setIsConnected(false); });
    } catch (err) {
      if (isMountedRef.current) {
        setError(err instanceof Error ? err.message : 'Unknown error');
        setIsConnected(false);
      }
    }
    return () => { isMountedRef.current = false; };
  }, [brokerUrl, topic]);

  const reconnect = () => clientRef.current?.reconnect();
  const disconnect = () => {
    clientRef.current?.end(true, () => {
      if (isMountedRef.current) setIsConnected(false);
    });
  };

  return { data, isConnected, error, reconnect, disconnect };
}
