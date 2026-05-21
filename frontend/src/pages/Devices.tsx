import React, { useEffect, useState } from 'react';
import { Plus, Trash2, MapPin, Cpu, AlertTriangle, X } from 'lucide-react';
import api from '@/lib/api';
import { useAuth } from '@/hooks/useAuth';

interface Device {
  id: string;
  name: string;
  location: string;
  device_id: string;
  status: string;
  latitude: number | null;
  longitude: number | null;
}

interface DeviceForm {
  name: string;
  location: string;
  device_id: string;
  latitude: string;
  longitude: string;
}

const EMPTY_FORM: DeviceForm = { name: '', location: '', device_id: '', latitude: '', longitude: '' };

const Devices: React.FC = () => {
  const { user } = useAuth();
  const isAdmin = user?.role === 'admin';

  const [devices, setDevices] = useState<Device[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [search, setSearch] = useState('');

  const [showModal, setShowModal] = useState(false);
  const [form, setForm] = useState<DeviceForm>(EMPTY_FORM);
  const [saving, setSaving] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);

  const [deletingId, setDeletingId] = useState<string | null>(null);

  const load = () => {
    setIsLoading(true);
    api
      .get<Device[]>('/api/devices')
      .then(({ data }) => setDevices(data))
      .catch(() => setError('Failed to load devices'))
      .finally(() => setIsLoading(false));
  };

  useEffect(load, []);

  const handleCreate = async (e: React.FormEvent) => {
    e.preventDefault();
    setFormError(null);
    if (!form.name.trim() || !form.location.trim() || !form.device_id.trim()) {
      setFormError('Name, location and device ID are required.');
      return;
    }
    setSaving(true);
    try {
      const payload = {
        name: form.name.trim(),
        location: form.location.trim(),
        device_id: form.device_id.trim(),
        latitude: form.latitude ? parseFloat(form.latitude) : null,
        longitude: form.longitude ? parseFloat(form.longitude) : null,
      };
      const { data } = await api.post<Device>('/api/devices', payload);
      setDevices((prev) => [data, ...prev]);
      setShowModal(false);
      setForm(EMPTY_FORM);
    } catch (err: unknown) {
      const msg = (err as { response?: { data?: { detail?: string } } })?.response?.data?.detail;
      setFormError(msg || 'Failed to create device.');
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async (id: string) => {
    if (!confirm('Delete this device? This cannot be undone.')) return;
    setDeletingId(id);
    try {
      await api.delete(`/api/devices/${id}`);
      setDevices((prev) => prev.filter((d) => d.id !== id));
    } catch {
      alert('Failed to delete device.');
    } finally {
      setDeletingId(null);
    }
  };

  const filtered = devices.filter(
    (d) =>
      d.name.toLowerCase().includes(search.toLowerCase()) ||
      d.location.toLowerCase().includes(search.toLowerCase()) ||
      d.device_id.toLowerCase().includes(search.toLowerCase()),
  );

  return (
    <div className="min-h-screen bg-[#F6F6FA] p-8">
      <div className="mx-auto max-w-5xl">
        {/* Header */}
        <div className="mb-6 flex items-center justify-between">
          <h2 className="text-2xl font-semibold text-green-600">Devices</h2>
          {isAdmin && (
            <button
              onClick={() => { setShowModal(true); setForm(EMPTY_FORM); setFormError(null); }}
              className="flex items-center gap-2 rounded-xl bg-[#22C55E] px-4 py-2 text-sm font-semibold text-white hover:bg-[#16A34A]"
            >
              <Plus className="size-4" /> Add Device
            </button>
          )}
        </div>

        <input
          type="text"
          placeholder="Search by name, location or ID…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          className="mb-8 w-full rounded-lg border border-gray-200 bg-white px-4 py-2 focus:outline-none focus:ring-2 focus:ring-green-200"
        />

        {error && (
          <div className="mb-6 flex items-center gap-2 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
            <AlertTriangle className="size-4" /> {error}
          </div>
        )}

        {isLoading ? (
          <div className="grid grid-cols-1 gap-6 md:grid-cols-2 lg:grid-cols-3">
            {[1, 2, 3].map((i) => (
              <div key={i} className="animate-pulse rounded-xl bg-white p-6 shadow">
                {[1, 2, 3, 4].map((j) => <div key={j} className="mb-3 h-9 rounded-full bg-gray-100" />)}
              </div>
            ))}
          </div>
        ) : filtered.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-24 text-gray-400">
            <Cpu className="mb-4 size-12 opacity-30" />
            <p className="font-medium">{devices.length === 0 ? 'No devices yet' : 'No devices match your search.'}</p>
            {isAdmin && devices.length === 0 && (
              <p className="mt-1 text-sm">Click "Add Device" to register your first sensor.</p>
            )}
          </div>
        ) : (
          <div className="grid grid-cols-1 gap-6 md:grid-cols-2 lg:grid-cols-3">
            {filtered.map((device) => (
              <div key={device.id} className="flex flex-col gap-3 rounded-xl bg-white p-6 shadow">
                <Field label="Name" value={device.name} />
                <Field label="Location" value={device.location} />
                <Field label="Device ID" value={device.device_id} />
                {(device.latitude != null && device.longitude != null) && (
                  <div className="flex items-center gap-1.5 text-xs text-gray-400">
                    <MapPin className="size-3.5" />
                    {device.latitude.toFixed(5)}, {device.longitude.toFixed(5)}
                  </div>
                )}
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-1.5">
                    <span className={`size-2 rounded-full ${device.status === 'active' ? 'animate-pulse bg-green-500' : 'bg-gray-300'}`} />
                    <span className="text-xs capitalize text-gray-500">{device.status}</span>
                  </div>
                  {isAdmin && (
                    <button
                      onClick={() => handleDelete(device.id)}
                      disabled={deletingId === device.id}
                      className="flex items-center gap-1 rounded-lg px-2.5 py-1.5 text-xs font-medium text-red-500 hover:bg-red-50 disabled:opacity-50"
                    >
                      <Trash2 className="size-3.5" />
                      {deletingId === device.id ? 'Deleting…' : 'Delete'}
                    </button>
                  )}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Add Device Modal */}
      {showModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
          <div className="w-full max-w-md rounded-2xl bg-white p-6 shadow-xl">
            <div className="mb-5 flex items-center justify-between">
              <h3 className="text-lg font-bold text-gray-900">Add Device</h3>
              <button onClick={() => setShowModal(false)} className="text-gray-400 hover:text-gray-600">
                <X className="size-5" />
              </button>
            </div>

            {formError && (
              <div className="mb-4 rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
                {formError}
              </div>
            )}

            <form onSubmit={handleCreate} className="flex flex-col gap-4">
              <FormInput label="Device Name *" value={form.name} onChange={(v) => setForm((f) => ({ ...f, name: v }))} placeholder="e.g. Room 1 Sensor" />
              <FormInput label="Location *" value={form.location} onChange={(v) => setForm((f) => ({ ...f, location: v }))} placeholder="e.g. Kigali, Nyarugenge" />
              <FormInput label="Device ID *" value={form.device_id} onChange={(v) => setForm((f) => ({ ...f, device_id: v }))} placeholder="e.g. airsense-001" />
              <div className="grid grid-cols-2 gap-3">
                <FormInput label="Latitude" value={form.latitude} onChange={(v) => setForm((f) => ({ ...f, latitude: v }))} placeholder="-1.9441" type="number" />
                <FormInput label="Longitude" value={form.longitude} onChange={(v) => setForm((f) => ({ ...f, longitude: v }))} placeholder="30.0619" type="number" />
              </div>
              <button
                type="submit"
                disabled={saving}
                className="mt-1 w-full rounded-xl bg-[#22C55E] py-2.5 text-sm font-semibold text-white hover:bg-[#16A34A] disabled:opacity-50"
              >
                {saving ? 'Creating…' : 'Create Device'}
              </button>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

function Field({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <label className="mb-1 block text-xs text-gray-400">{label}</label>
      <div className="w-full rounded-full bg-[#F6F6FA] px-4 py-2 text-sm font-medium text-gray-700 border border-gray-200">
        {value}
      </div>
    </div>
  );
}

function FormInput({ label, value, onChange, placeholder, type = 'text' }: {
  label: string; value: string; onChange: (v: string) => void; placeholder?: string; type?: string;
}) {
  return (
    <div>
      <label className="mb-1 block text-xs font-medium text-gray-600">{label}</label>
      <input
        type={type}
        step="any"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder}
        className="w-full rounded-xl border border-gray-200 bg-[#F6F6FA] px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-200"
      />
    </div>
  );
}

export default Devices;
