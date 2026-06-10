import React, { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { Bell, AlertTriangle, Info, CheckCheck, RefreshCw, Send, Mail, Monitor } from 'lucide-react';
import api from '@/lib/api';
import { useAuth } from '@/hooks/useAuth';

interface Notification {
  id: string;
  message: string;
  level: string;
  device: string;
  field: string;
  read: boolean;
  created_at: string;
}

interface NotificationPrefs {
  email_alerts: boolean;
  web_alerts: boolean;
  min_level: 'info' | 'warning' | 'critical';
}

const LEVEL_STYLES: Record<string, { bg: string; border: string; text: string; icon: React.ReactNode }> = {
  critical: { bg: 'bg-red-50', border: 'border-red-200', text: 'text-red-700', icon: <AlertTriangle className="size-5 text-red-500" /> },
  warning:  { bg: 'bg-amber-50', border: 'border-amber-200', text: 'text-amber-700', icon: <AlertTriangle className="size-5 text-amber-500" /> },
  info:     { bg: 'bg-blue-50',  border: 'border-blue-200',  text: 'text-blue-700',  icon: <Info className="size-5 text-blue-500" /> },
};

const Notifications: React.FC = () => {
  const { user } = useAuth();
  const isAdmin = user?.role === 'admin';

  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [search, setSearch] = useState('');
  const [filter, setFilter] = useState<string>('all');

  // Admin broadcast form
  const [broadcastMsg, setBroadcastMsg] = useState('');
  const [broadcastLevel, setBroadcastLevel] = useState('info');
  const [broadcasting, setBroadcasting] = useState(false);
  const [broadcastStatus, setBroadcastStatus] = useState<string | null>(null);

  // Notification preferences
  const [prefs, setPrefs] = useState<NotificationPrefs>({
    email_alerts: true,
    web_alerts: true,
    min_level: 'warning',
  });
  const [browserPerm, setBrowserPerm] = useState<NotificationPermission>(
    typeof window !== 'undefined' && 'Notification' in window ? Notification.permission : 'denied',
  );
  const [savingPrefs, setSavingPrefs] = useState(false);
  const [prefsStatus, setPrefsStatus] = useState<string | null>(null);

  const loadPrefs = () => {
    api
      .get<NotificationPrefs>('/api/notifications/preferences')
      .then(({ data }) => setPrefs(data))
      .catch(() => null);
  };

  useEffect(loadPrefs, []);

  const updatePrefs = async (next: Partial<NotificationPrefs>) => {
    setSavingPrefs(true);
    setPrefsStatus(null);
    const merged = { ...prefs, ...next };
    setPrefs(merged);
    try {
      const { data } = await api.patch<NotificationPrefs>('/api/notifications/preferences', next);
      setPrefs(data);
      setPrefsStatus('Saved.');
    } catch {
      setPrefsStatus('Could not save preferences.');
    } finally {
      setSavingPrefs(false);
      setTimeout(() => setPrefsStatus(null), 2500);
    }
  };

  const requestBrowserPerm = async () => {
    if (!('Notification' in window)) {
      setPrefsStatus('This browser does not support notifications.');
      return;
    }
    const result = await Notification.requestPermission();
    setBrowserPerm(result);
  };

  const load = () => {
    setIsLoading(true);
    api
      .get<Notification[]>('/api/notifications?limit=100')
      .then(({ data }) => setNotifications(data))
      .catch(() => setError('Failed to load notifications'))
      .finally(() => setIsLoading(false));
  };

  useEffect(load, []);

  const markRead = async (id: string) => {
    await api.patch(`/api/notifications/${id}/read`).catch(() => null);
    setNotifications((prev) =>
      prev.map((n) => (n.id === id ? { ...n, read: true } : n)),
    );
  };

  const markAllRead = async () => {
    const unread = notifications.filter((n) => !n.read);
    await Promise.all(unread.map((n) => api.patch(`/api/notifications/${n.id}/read`).catch(() => null)));
    setNotifications((prev) => prev.map((n) => ({ ...n, read: true })));
  };

  const handleBroadcast = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!broadcastMsg.trim()) return;
    setBroadcasting(true);
    setBroadcastStatus(null);
    try {
      await api.post('/api/notifications', {
        message: broadcastMsg.trim(),
        level: broadcastLevel,
        broadcast: true,
      });
      setBroadcastMsg('');
      setBroadcastStatus('Notification sent to all users.');
      load();
    } catch {
      setBroadcastStatus('Failed to send notification.');
    } finally {
      setBroadcasting(false);
    }
  };

  const filtered = notifications.filter((n) => {
    const matchesSearch =
      n.message.toLowerCase().includes(search.toLowerCase()) ||
      n.device.toLowerCase().includes(search.toLowerCase());
    const matchesFilter = filter === 'all' || n.level === filter || (filter === 'unread' && !n.read);
    return matchesSearch && matchesFilter;
  });

  const unreadCount = notifications.filter((n) => !n.read).length;

  return (
    <div className="min-h-screen bg-[#F6F6FA] p-8">
      <div className="mx-auto max-w-4xl">
        {/* Header */}
        <div className="mb-6 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Bell className="size-5 text-green-600" />
            <h2 className="text-2xl font-semibold text-green-600">Notifications</h2>
            {unreadCount > 0 && (
              <span className="rounded-full bg-red-500 px-2 py-0.5 text-xs font-bold text-white">
                {unreadCount}
              </span>
            )}
          </div>
          <div className="flex items-center gap-2">
            <button
              onClick={load}
              className="rounded-lg p-2 text-gray-400 hover:bg-gray-100"
              title="Refresh"
            >
              <RefreshCw className="size-4" />
            </button>
            {unreadCount > 0 && (
              <button
                onClick={markAllRead}
                className="flex items-center gap-1.5 rounded-xl border border-gray-200 bg-white px-3 py-1.5 text-xs font-medium text-gray-600 hover:bg-gray-50"
              >
                <CheckCheck className="size-4" /> Mark all read
              </button>
            )}
          </div>
        </div>

        {/* Preferences */}
        <div className="mb-6 rounded-2xl border border-gray-200 bg-white p-5 shadow-sm">
          <div className="mb-3 flex items-center justify-between">
            <div className="flex items-center gap-2">
              <Bell className="size-4 text-gray-500" />
              <h3 className="text-sm font-semibold text-gray-900">Notification preferences</h3>
            </div>
            {prefsStatus && <span className="text-xs text-gray-500">{prefsStatus}</span>}
          </div>

          <div className="grid grid-cols-1 gap-3 md:grid-cols-3">
            {/* Email alerts */}
            <label className="flex items-start gap-3 rounded-xl border border-gray-100 p-3 hover:bg-gray-50">
              <input
                type="checkbox"
                checked={prefs.email_alerts}
                disabled={savingPrefs}
                onChange={(e) => updatePrefs({ email_alerts: e.target.checked })}
                className="mt-0.5 size-4 accent-green-600"
              />
              <div>
                <div className="flex items-center gap-1.5 text-sm font-medium text-gray-800">
                  <Mail className="size-4 text-gray-500" /> Email alerts
                </div>
                <p className="text-xs text-gray-500">
                  Send a copy of new alerts to {user?.email ?? 'your account email'}.
                </p>
              </div>
            </label>

            {/* Web (browser) alerts */}
            <label className="flex items-start gap-3 rounded-xl border border-gray-100 p-3 hover:bg-gray-50">
              <input
                type="checkbox"
                checked={prefs.web_alerts}
                disabled={savingPrefs}
                onChange={(e) => updatePrefs({ web_alerts: e.target.checked })}
                className="mt-0.5 size-4 accent-green-600"
              />
              <div className="flex-1">
                <div className="flex items-center gap-1.5 text-sm font-medium text-gray-800">
                  <Monitor className="size-4 text-gray-500" /> Browser notifications
                </div>
                <p className="text-xs text-gray-500">
                  Show a desktop notification while AirSense is open.
                </p>
                {browserPerm !== 'granted' && (
                  <button
                    type="button"
                    onClick={requestBrowserPerm}
                    className="mt-1.5 text-xs font-medium text-green-700 underline"
                  >
                    {browserPerm === 'denied'
                      ? 'Permission denied — enable in browser settings'
                      : 'Grant browser permission'}
                  </button>
                )}
              </div>
            </label>

            {/* Min level */}
            <div className="flex items-start gap-3 rounded-xl border border-gray-100 p-3">
              <AlertTriangle className="mt-0.5 size-4 text-gray-500" />
              <div className="flex-1">
                <div className="text-sm font-medium text-gray-800">Minimum level</div>
                <p className="mb-1.5 text-xs text-gray-500">
                  Skip alerts below this severity. Repeats are throttled to 10 min.
                </p>
                <select
                  value={prefs.min_level}
                  disabled={savingPrefs}
                  onChange={(e) =>
                    updatePrefs({ min_level: e.target.value as NotificationPrefs['min_level'] })
                  }
                  className="rounded-lg border border-gray-200 bg-white px-2 py-1 text-xs focus:outline-none"
                >
                  <option value="info">Info and above</option>
                  <option value="warning">Warning and above</option>
                  <option value="critical">Critical only</option>
                </select>
              </div>
            </div>
          </div>
        </div>

        {/* Admin broadcast panel */}
        {isAdmin && (
          <div className="mb-6 rounded-2xl border border-purple-200 bg-purple-50 p-4">
            <p className="mb-3 flex items-center gap-1.5 text-sm font-semibold text-purple-800">
              <Send className="size-4" /> Broadcast notification to all users
            </p>
            <form onSubmit={handleBroadcast} className="flex flex-col gap-3 sm:flex-row">
              <input
                value={broadcastMsg}
                onChange={(e) => setBroadcastMsg(e.target.value)}
                placeholder="Notification message…"
                className="flex-1 rounded-xl border border-purple-200 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-purple-300"
              />
              <select
                value={broadcastLevel}
                onChange={(e) => setBroadcastLevel(e.target.value)}
                className="rounded-xl border border-purple-200 bg-white px-3 py-2 text-sm focus:outline-none"
              >
                <option value="info">Info</option>
                <option value="warning">Warning</option>
                <option value="critical">Critical</option>
              </select>
              <button
                type="submit"
                disabled={broadcasting || !broadcastMsg.trim()}
                className="rounded-xl bg-purple-600 px-4 py-2 text-sm font-semibold text-white hover:bg-purple-700 disabled:opacity-50"
              >
                {broadcasting ? 'Sending…' : 'Send'}
              </button>
            </form>
            {broadcastStatus && (
              <p className="mt-2 text-xs text-purple-700">{broadcastStatus}</p>
            )}
          </div>
        )}

        {/* Filters */}
        <div className="mb-6 flex flex-col gap-3 md:flex-row">
          <input
            type="text"
            placeholder="Search notifications…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="flex-1 rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-200"
          />
          <select
            value={filter}
            onChange={(e) => setFilter(e.target.value)}
            className="rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm text-gray-500 focus:outline-none"
          >
            <option value="all">All</option>
            <option value="unread">Unread</option>
            <option value="critical">Critical</option>
            <option value="warning">Warning</option>
            <option value="info">Info</option>
          </select>
        </div>

        {error && (
          <div className="mb-4 flex items-center gap-2 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
            <AlertTriangle className="size-4" /> {error}
          </div>
        )}

        {isLoading ? (
          <div className="flex flex-col gap-4">
            {[1, 2, 3].map((i) => (
              <div key={i} className="flex animate-pulse items-center gap-6 rounded-xl bg-white p-6 shadow">
                <div className="size-12 flex-shrink-0 rounded-full bg-gray-100" />
                <div className="flex-1 space-y-2">
                  <div className="h-4 w-32 rounded bg-gray-100" />
                  <div className="h-3 w-full rounded bg-gray-100" />
                </div>
              </div>
            ))}
          </div>
        ) : filtered.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-20 text-gray-400">
            <Bell className="mb-3 size-10 opacity-30" />
            <p className="font-medium">No notifications</p>
            <p className="text-sm">{filter !== 'all' ? 'Try a different filter.' : 'You\'re all caught up.'}</p>
          </div>
        ) : (
          <div className="flex flex-col gap-4">
            {filtered.map((n) => {
              const style = LEVEL_STYLES[n.level] ?? LEVEL_STYLES.info;
              return (
                <div
                  key={n.id}
                  className={`flex items-start gap-4 rounded-xl border p-5 shadow-sm transition-opacity ${style.bg} ${style.border} ${n.read ? 'opacity-60' : ''}`}
                >
                  <div className="mt-0.5 flex-shrink-0">{style.icon}</div>
                  <div className="min-w-0 flex-1">
                    <div className="mb-0.5 flex items-center gap-2">
                      <span className={`text-xs font-bold uppercase ${style.text}`}>{n.level}</span>
                      {n.device && <span className="text-xs text-gray-400">· {n.device}</span>}
                      {!n.read && <span className="size-1.5 rounded-full bg-blue-500" />}
                    </div>
                    <p className="text-sm text-gray-800">{n.message}</p>
                    <div className="mt-1.5 flex items-center gap-3">
                      <span className="text-xs text-gray-400">
                        {new Date(n.created_at).toLocaleString()}
                      </span>
                      <Link to="/dashboard" className="text-xs text-purple-600 underline">
                        View dashboard
                      </Link>
                      {!n.read && (
                        <button
                          onClick={() => markRead(n.id)}
                          className="text-xs text-gray-500 hover:text-gray-700 underline"
                        >
                          Mark read
                        </button>
                      )}
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
};

export default Notifications;
