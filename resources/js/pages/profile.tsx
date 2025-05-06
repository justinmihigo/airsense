import React from 'react';
import AppLayout from '@/layouts/app-layout';

const user = {
  email: 'samanthajones@gmail.com',
  name: 'Samantha Jones',
  org: 'University of Rwanda',
  uniqueId: '33486439472',
  avatar: 'https://randomuser.me/api/portraits/women/44.jpg',
};

const devices = [
  { name: 'Room 1', location: 'Kigali, Nyarugenge', id: 'DEV238171720' },
  { name: 'Room 2', location: 'Kigali, Nyarugenge', id: 'DEV5859383' },
];

const Profile: React.FC = () => {
  return (
    <AppLayout>
      <div className="bg-[#F6F6FA] min-h-screen p-8">
        <div className="max-w-5xl mx-auto">
          <h2 className="text-2xl font-semibold mb-2">Welcome Back, <span className="text-black">Samantha</span></h2>
          <h3 className="text-xl text-green-600 font-semibold mb-8">Your Profile</h3>
          <div className="bg-white rounded-xl shadow p-8 flex flex-col gap-8">
            {/* Basic Info */}
            <div>
              <h4 className="text-lg font-bold mb-4">Basic Information</h4>
              <div className="flex flex-col md:flex-row gap-8 items-center">
                <img src={user.avatar} alt="Avatar" className="w-32 h-32 rounded-full object-cover" />
                <div className="flex-1 grid grid-cols-1 md:grid-cols-2 gap-6">
                  <div>
                    <label className="block text-gray-500 text-sm mb-1">Email</label>
                    <input value={user.email} readOnly className="w-full px-4 py-2 rounded-full bg-[#F6F6FA] border border-gray-200 text-gray-700 font-medium" />
                  </div>
                  <div>
                    <label className="block text-gray-500 text-sm mb-1">Names</label>
                    <input value={user.name} readOnly className="w-full px-4 py-2 rounded-full bg-[#F6F6FA] border border-gray-200 text-gray-700 font-medium" />
                  </div>
                  <div>
                    <label className="block text-gray-500 text-sm mb-1">Organization</label>
                    <input value={user.org} readOnly className="w-full px-4 py-2 rounded-full bg-[#F6F6FA] border border-gray-200 text-gray-700 font-medium" />
                  </div>
                  <div>
                    <label className="block text-gray-500 text-sm mb-1">Unique ID</label>
                    <input value={user.uniqueId} readOnly className="w-full px-4 py-2 rounded-full bg-[#F6F6FA] border border-gray-200 text-gray-700 font-medium" />
                  </div>
                </div>
              </div>
            </div>
            {/* Devices */}
            <div>
              <h4 className="text-lg font-bold mb-4">Devices</h4>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
                {devices.map((device, idx) => (
                  <div key={idx} className="bg-[#F6F6FA] rounded-xl p-6 flex flex-col gap-4">
                    <div>
                      <label className="block text-gray-500 text-sm mb-1">Name</label>
                      <input value={device.name} readOnly className="w-full px-4 py-2 rounded-full border border-gray-200 text-gray-700 font-medium bg-white" />
                    </div>
                    <div>
                      <label className="block text-gray-500 text-sm mb-1">Location</label>
                      <input value={device.location} readOnly className="w-full px-4 py-2 rounded-full border border-gray-200 text-gray-700 font-medium bg-white" />
                    </div>
                    <div>
                      <label className="block text-gray-500 text-sm mb-1">Unique ID</label>
                      <input value={device.id} readOnly className="w-full px-4 py-2 rounded-full border border-gray-200 text-gray-700 font-medium bg-white" />
                    </div>
                    <button className="mt-2 w-full py-2 rounded-full bg-[#6C2BD7] text-white font-semibold text-lg hover:bg-[#4B1A9A]">Manage Device</button>
                  </div>
                ))}
              </div>
            </div>
            <button className="mt-4 w-full py-3 rounded-full bg-[#6C2BD7] text-white font-semibold text-lg hover:bg-[#4B1A9A]">Update Profile</button>
          </div>
        </div>
      </div>
    </AppLayout>
  );
};

export default Profile; 