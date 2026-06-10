import { useEffect, useRef } from 'react';
import api from '@/lib/api';
import type { InfluxAlert } from './useInfluxData';

interface NotifierOptions {
  enabled?: boolean;
  /** Client-side hint — server still owns the authoritative cooldown. */
  clientCooldownMs?: number;
}

interface AlertPayload {
  message: string;
  level: 'info' | 'warning' | 'critical';
  device: string;
  field: string;
  value: number;
  threshold: number;
}

const ALERT_KEY = (a: InfluxAlert) => `${a.device}|${a.field}|${a.severity}`;

async function requestBrowserPermission() {
  if (typeof window === 'undefined' || !('Notification' in window)) return 'denied';
  if (Notification.permission === 'default') {
    try {
      return await Notification.requestPermission();
    } catch {
      return 'denied';
    }
  }
  return Notification.permission;
}

function showBrowserNotification(payload: AlertPayload) {
  if (typeof window === 'undefined' || !('Notification' in window)) return;
  if (Notification.permission !== 'granted') return;
  try {
    const n = new Notification(`AirSense · ${payload.level.toUpperCase()}`, {
      body: payload.message,
      tag: `${payload.device}-${payload.field}-${payload.level}`,
      icon: '/favicon.ico',
      requireInteraction: payload.level === 'critical',
    });
    n.onclick = () => {
      window.focus();
      window.location.href = '/notifications';
      n.close();
    };
  } catch {
    // ignore — older browsers throw on some option combinations
  }
}

/**
 * Watches sensor alerts and forwards new ones to the backend, which records,
 * deduplicates within a 10-minute window (server-enforced), and emails the user
 * if their preferences allow it. Also raises a browser Notification on send.
 */
export function useAlertNotifier(alerts: InfluxAlert[], opts: NotifierOptions = {}) {
  const { enabled = true, clientCooldownMs = 9 * 60 * 1000 } = opts;
  const lastSentAt = useRef<Map<string, number>>(new Map());

  useEffect(() => {
    if (!enabled) return;
    requestBrowserPermission();
  }, [enabled]);

  useEffect(() => {
    if (!enabled || alerts.length === 0) return;
    const now = Date.now();

    for (const alert of alerts) {
      const key = ALERT_KEY(alert);
      const last = lastSentAt.current.get(key) ?? 0;
      // Client-side guard so we don't hammer the API; server has the real cooldown.
      if (now - last < clientCooldownMs) continue;
      lastSentAt.current.set(key, now);

      const payload: AlertPayload = {
        message: alert.message,
        level: alert.severity,
        device: alert.device,
        field: alert.field,
        value: alert.value,
        threshold: alert.threshold,
      };

      api
        .post('/api/notifications/alerts', payload)
        .then(({ data }) => {
          if (!data?.throttled) {
            showBrowserNotification(payload);
          }
        })
        .catch(() => {
          // Allow retry next tick if the call failed entirely
          lastSentAt.current.delete(key);
        });
    }
  }, [alerts, enabled, clientCooldownMs]);
}
