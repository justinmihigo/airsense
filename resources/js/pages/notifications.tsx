import React from 'react';
import AppLayout from '@/layouts/app-layout';

const notifications = [
  {
    type: 'info',
    title: 'Daily update',
    message: 'At Room 1 Kigali , Nyarugenge the air quality is  good with 150 AQI, with CO2 at 140PPM and CO at 150PPM  for more information,',
    link: '/dashboard',
  },
  {
    type: 'info',
    title: 'Daily update',
    message: 'At Room 2 Kigali , Nyarugenge the air quality is  Moderate with 150 AQI, with CO2 at 140PPM and CO at 150PPM  for more information,',
    link: '/dashboard',
  },
  {
    type: 'alert',
    title: 'Alert',
    message: 'At Room 2 Kigali , Nyarugenge the air quality is  bad try opening windows or turn on an air purifier, for more information,',
    link: '/dashboard',
  },
  {
    type: 'alert',
    title: 'Alert',
    message: 'At Room 2 Kigali , Nyarugenge the air quality is  bad try opening windows or turn on an air purifier, for more information,',
    link: '/dashboard',
  },
  {
    type: 'alert',
    title: 'Alert',
    message: 'At Room 2 Kigali , Nyarugenge the air quality is  bad try opening windows or turn on an air purifier, for more information,',
    link: '/dashboard',
  },
];

const Notifications: React.FC = () => {
  return (
    <AppLayout>
      <div className="bg-[#F6F6FA] min-h-screen p-8">
        <div className="max-w-5xl mx-auto">
          <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4 mb-8">
            <input
              type="text"
              placeholder="Search a here"
              className="w-full md:w-1/2 px-4 py-2 rounded-lg border border-gray-200 focus:outline-none focus:ring-2 focus:ring-green-200 bg-white"
            />
            <div className="flex gap-4 w-full md:w-auto">
              <select className="px-4 py-2 rounded-lg border border-gray-200 bg-white text-gray-500 focus:outline-none">
                <option>Category</option>
              </select>
              <div className="flex items-center gap-2 bg-white px-3 py-2 rounded-lg border border-gray-200">
                <span className="text-xs text-gray-500">Filter Period</span>
                <span className="font-semibold text-sm">17 April 2025 - 21 May 2025</span>
              </div>
            </div>
          </div>
          <h2 className="text-2xl font-semibold text-green-600 mb-8">Your Notifications</h2>
          <div className="flex flex-col gap-6">
            {notifications.map((n, idx) => (
              <div key={idx} className="flex items-center bg-white rounded-xl shadow p-6 gap-6">
                <div className="flex-shrink-0 flex items-center justify-center w-16 h-16 rounded-full bg-[#F6F6FA]">
                  {n.type === 'info' ? (
                    <span className="text-4xl text-blue-400">i</span>
                  ) : (
                    <span className="text-4xl text-red-400">&#9888;</span>
                  )}
                </div>
                <div className="flex-1">
                  <div className="font-bold text-lg mb-1 {n.type === 'alert' ? 'text-red-500' : ''}">{n.title}</div>
                  <div className="text-gray-700 mb-1">
                    {n.message}
                    <a href={n.link} className="text-purple-600 underline ml-1">visit your dashboard</a>
                  </div>
                </div>
                <button className="ml-4 text-red-400 hover:text-red-600 text-2xl">&#10006;</button>
              </div>
            ))}
          </div>
        </div>
      </div>
    </AppLayout>
  );
};

export default Notifications; 