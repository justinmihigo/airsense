import React, { useState } from 'react';
import AppLayout from '@/layouts/app-layout';
import { Link, router } from '@inertiajs/react';

interface Device {
  id: number;
  name: string;
  location: string;
  unique_id: string;
  sensors: any[];
}

interface Props {
  devices: Device[];
}

const Devices: React.FC<Props> = ({ devices }) => {
  const [searchTerm, setSearchTerm] = useState('');

  const handleDelete = (deviceId: number) => {
    if (window.confirm('Are you sure you want to delete this device?')) {
      router.delete(`/devices/${deviceId}`);
    }
  };

  const filteredDevices = devices.filter(device =>
    device.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
    device.location.toLowerCase().includes(searchTerm.toLowerCase()) ||
    device.unique_id.toLowerCase().includes(searchTerm.toLowerCase())
  );

  return (
    <AppLayout>
      <div className="bg-[#F6F6FA] min-h-screen p-8">
        <div className="max-w-4xl mx-auto">
          <input
            type="text"
            placeholder="Search a device here"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="w-full mb-8 px-4 py-2 rounded-lg border border-gray-200 focus:outline-none focus:ring-2 focus:ring-green-200 bg-white"
          />
          <div className="flex justify-between items-center">
            <h2 className="text-2xl font-semibold text-green-600 mb-8">Your Devices</h2>
            <Link
              href="/devices/add"
              className="w-1/4 py-2 rounded-full bg-[#6C2BD7] text-white font-semibold text-lg hover:bg-[#4B1A9A] text-center"
            >
              Add a device
            </Link>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
            {filteredDevices.map((device) => (
              <div key={device.id} className="bg-white rounded-xl shadow p-8 flex flex-col gap-4">
                <div>
                  <label className="block text-gray-500 text-sm mb-1">Name</label>
                  <input value={device.name} readOnly className="w-full px-4 py-2 rounded-full bg-[#F6F6FA] border border-gray-200 text-gray-700 font-medium" />
                </div>
                <div>
                  <label className="block text-gray-500 text-sm mb-1">Location</label>
                  <input value={device.location} readOnly className="w-full px-4 py-2 rounded-full bg-[#F6F6FA] border border-gray-200 text-gray-700 font-medium" />
                </div>
                <div>
                  <label className="block text-gray-500 text-sm mb-1">Unique ID</label>
                  <input value={device.unique_id} readOnly className="w-full px-4 py-2 rounded-full bg-[#F6F6FA] border border-gray-200 text-gray-700 font-medium" />
                </div>
                <div className="flex gap-2 mt-2">
                  <Link
                    href={`/devices/${device.id}/edit`}
                    className="flex-1 py-2 rounded-full bg-[#6C2BD7] text-white font-semibold text-lg hover:bg-[#4B1A9A] text-center"
                  >
                    Update
                  </Link>
                  <button 
                    onClick={() => handleDelete(device.id)}
                    className="flex-1 py-2 rounded-full bg-red-600 text-white font-semibold text-lg hover:bg-red-700"
                  >
                    Delete
                  </button>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </AppLayout>
  );
};

export default Devices; 