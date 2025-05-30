import React from 'react';
import AppLayout from '@/layouts/app-layout';
import { useForm, Link } from '@inertiajs/react';

interface Device {
  id: number;
  name: string;
  location: string;
  unique_id: string;
  sensors: any[];
}

interface Props {
  device: Device;
}

const EditDevice: React.FC<Props> = ({ device }) => {
  const { data, setData, put, processing, errors } = useForm({
    name: device.name,
    location: device.location,
    sensors: device.sensors || []
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    put(`/devices/${device.id}`);
  };

  return (
    <AppLayout>
      <div className="bg-[#F6F6FA] min-h-screen p-8">
        <div className="max-w-2xl mx-auto">
          <h2 className="text-2xl font-semibold text-green-600 mb-8">Edit Device</h2>
          <form onSubmit={handleSubmit} className="bg-white rounded-xl shadow p-8">
            <div className="mb-6">
              <label className="block text-gray-500 text-sm mb-2">Device Name</label>
              <input
                type="text"
                value={data.name}
                onChange={e => setData('name', e.target.value)}
                className="w-full px-4 py-2 rounded-lg border border-gray-200 focus:outline-none focus:ring-2 focus:ring-green-200"
                required
              />
              {errors.name && <div className="text-red-500 text-sm mt-1">{errors.name}</div>}
            </div>
            <div className="mb-6">
              <label className="block text-gray-500 text-sm mb-2">Location</label>
              <input
                type="text"
                value={data.location}
                onChange={e => setData('location', e.target.value)}
                className="w-full px-4 py-2 rounded-lg border border-gray-200 focus:outline-none focus:ring-2 focus:ring-green-200"
                required
              />
              {errors.location && <div className="text-red-500 text-sm mt-1">{errors.location}</div>}
            </div>
            <div className="flex gap-4">
              <Link
                href="/devices"
                className="flex-1 py-2 rounded-full bg-gray-500 text-white font-semibold text-lg hover:bg-gray-600 text-center"
              >
                Cancel
              </Link>
              <button
                type="submit"
                disabled={processing}
                className="flex-1 py-2 rounded-full bg-[#6C2BD7] text-white font-semibold text-lg hover:bg-[#4B1A9A] disabled:opacity-50"
              >
                {processing ? 'Saving...' : 'Save Changes'}
              </button>
            </div>
          </form>
        </div>
      </div>
    </AppLayout>
  );
};

export default EditDevice; 