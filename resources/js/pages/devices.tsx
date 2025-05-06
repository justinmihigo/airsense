import React from 'react';
import AppLayout from '@/layouts/app-layout';

const devices = [
  { name: 'Room 1', location: 'Kigali, Nyarugenge', id: 'DEV238171720' },
  { name: 'Room 2', location: 'Kigali, Nyarugenge', id: 'DEV5859383' },
  { name: 'Room 3', location: 'Kigali, Nyarugenge', id: 'DEV5859383' },
];

const Devices: React.FC = () => {
  return (
    <AppLayout>
      <div className="bg-[#F6F6FA] min-h-screen p-8">
        <div className="max-w-4xl mx-auto">
          <input
            type="text"
            placeholder="Search a device here"
            className="w-full mb-8 px-4 py-2 rounded-lg border border-gray-200 focus:outline-none focus:ring-2 focus:ring-green-200 bg-white"
          />
          <h2 className="text-2xl font-semibold text-green-600 mb-8">Your Devices</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
            {devices.map((device, idx) => (
              <div key={idx} className="bg-white rounded-xl shadow p-8 flex flex-col gap-4">
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
                  <input value={device.id} readOnly className="w-full px-4 py-2 rounded-full bg-[#F6F6FA] border border-gray-200 text-gray-700 font-medium" />
                </div>
                <button className="mt-2 w-full py-2 rounded-full bg-[#6C2BD7] text-white font-semibold text-lg hover:bg-[#4B1A9A]">Update</button>
              </div>
            ))}
          </div>
        </div>
      </div>
    </AppLayout>
  );
};

export default Devices; 