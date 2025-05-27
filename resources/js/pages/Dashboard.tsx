import React, { useEffect, useRef, useState } from 'react';
import AppLayout from '@/layouts/app-layout';
import { Chart, registerables } from 'chart.js';
import { GoogleMap, LoadScript, Marker } from '@react-google-maps/api';

Chart.register(...registerables);

// Mock data for dashboard
const levels = [
  { label: 'PM 2.5', value: 400, unit: 'PPM' },
  { label: 'NO₂', value: 150, unit: 'PPM' },
  { label: 'CO₂', value: 300, unit: 'PPM' },
  { label: 'Temperature', value: 30, unit: '°C' },
  { label: 'Humidity', value: 293, unit: 'PPM' },
  { label: 'PM 2.5', value: 334, unit: 'PPM' },
];

const devices = [
  {
    name: 'Room 1',
    location: 'Kigali, Nyarugenge',
    status: 'Active',
    metrics: [
      { label: 'PM 2.5', value: 400, unit: 'PPM', color: 'red-500' },
      { label: 'CO', value: 150, unit: 'PPM', color: 'yellow-400' },
      { label: 'Temperature', value: 30, unit: '°C', color: 'green-400' },
      { label: 'Humidity', value: 293, unit: 'PPM', color: 'green-400' },
      { label: 'SO₂', value: 100, unit: 'PPM', color: 'red-500' },
      { label: 'NO₂', value: 150, unit: 'PPM', color: 'yellow-400' },
    ],
  },
  {
    name: 'Room 2',
    location: 'Kigali, Nyarugenge',
    status: 'Active',
    metrics: [
      { label: 'PM 2.5', value: 400, unit: 'PPM', color: 'red-500' },
      { label: 'CO', value: 150, unit: 'PPM', color: 'yellow-400' },
      { label: 'Temperature', value: 30, unit: '°C', color: 'green-400' },
      { label: 'Humidity', value: 293, unit: 'PPM', color: 'green-400' },
      { label: 'SO₂', value: 100, unit: 'PPM', color: 'red-500' },
      { label: 'NO₂', value: 150, unit: 'PPM', color: 'yellow-400' },
    ],
  },
];

// Mock data for dashboard charts
const weeklyData = [60, 80, 40, 70, 50, 80, 60];
const weeklyLabels = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
const monthlyData = [60, 80, 40, 70, 50, 80, 60];
const monthlyLabels = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JULY'];

// Map configuration
const mapContainerStyle = {
  width: '100%',
  height: '400px'
};

const center = {
  lat: -1.9403, // Kigali coordinates
  lng: 30.0588
};

function LineChart({ labels, data, title }: { labels: string[]; data: number[]; title: string }) {
  const chartRef = useRef<HTMLCanvasElement>(null);
  useEffect(() => {
    if (chartRef.current) {
      const ctx = chartRef.current.getContext('2d');
      if (!ctx) return;
      const chart = new Chart(ctx, {
        type: 'line',
        data: {
          labels,
          datasets: [
            {
              label: title,
              data,
              borderColor: '#3B82F6',
              backgroundColor: 'rgba(59,130,246,0.1)',
              fill: true,
              tension: 0.4,
              pointBackgroundColor: '#fff',
              pointBorderColor: '#3B82F6',
              pointRadius: 5,
            },
          ],
        },
        options: {
          plugins: { legend: { display: false } },
          scales: { y: { beginAtZero: true } },
        },
      });
      return () => chart.destroy();
    }
  }, [labels, data, title]);
  return <canvas ref={chartRef} height={96} />;
}

function OverallChart({ data }: { data: number[] }) {
  const chartRef = useRef<HTMLCanvasElement>(null);
  
  useEffect(() => {
    if (chartRef.current) {
      const ctx = chartRef.current.getContext('2d');
      if (!ctx) return;
      
      const chart = new Chart(ctx, {
        type: 'line',
        data: {
          labels: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul'],
          datasets: [
            {
              label: 'Overall AQI',
              data: data,
              borderColor: '#3B82F6',
              backgroundColor: 'rgba(59,130,246,0.1)',
              fill: true,
              tension: 0.4,
            }
          ]
        },
        options: {
          responsive: true,
          plugins: {
            legend: { display: false }
          },
          scales: {
            y: { beginAtZero: true }
          }
        }
      });
      
      return () => chart.destroy();
    }
  }, [data]);
  
  return <canvas ref={chartRef} />;
}

function AQILevelsChart() {
  const chartRef = useRef<HTMLCanvasElement>(null);
  
  useEffect(() => {
    if (chartRef.current) {
      const ctx = chartRef.current.getContext('2d');
      if (!ctx) return;
      
      const chart = new Chart(ctx, {
        type: 'bar',
        data: {
          labels: ['Good', 'Moderate', 'Unhealthy', 'Very Unhealthy', 'Hazardous'],
          datasets: [{
            label: 'AQI Levels',
            data: [50, 100, 150, 200, 300],
            backgroundColor: [
              'rgba(34, 197, 94, 0.8)',  // green
              'rgba(234, 179, 8, 0.8)',  // yellow
              'rgba(249, 115, 22, 0.8)', // orange
              'rgba(239, 68, 68, 0.8)',  // red
              'rgba(220, 38, 38, 0.8)',  // dark red
            ]
          }]
        },
        options: {
          responsive: true,
          plugins: {
            legend: { display: false }
          },
          scales: {
            y: { beginAtZero: true }
          }
        }
      });
      
      return () => chart.destroy();
    }
  }, []);
  
  return <canvas ref={chartRef} />;
}

const Dashboard: React.FC = () => {
  const [userLocation, setUserLocation] = useState<{lat: number, lng: number} | null>(null);
  const [locationError, setLocationError] = useState<string>('');

  useEffect(() => {
    // Request location permission
    if (navigator.geolocation) {
      navigator.geolocation.getCurrentPosition(
        (position) => {
          setUserLocation({
            lat: position.coords.latitude,
            lng: position.coords.longitude
          });
        },
        (error) => {
          setLocationError('Unable to retrieve your location');
          console.error('Error getting location:', error);
        }
      );
    } else {
      setLocationError('Geolocation is not supported by your browser');
    }
  }, []);

  return (
    <AppLayout>
      <div className="p-6 bg-[#F8FAFB] min-h-screen">
        {/* Topbar with Sidebar Collapse Button */}
        <div className="flex flex-col gap-2 mb-6">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <span className="text-lg font-bold text-gray-900">Dashboard</span>
            </div>
            <div className="flex items-center gap-4">
              <button className="p-2 rounded-full bg-white shadow"><span role="img" aria-label="lock">🔒</span></button>
              <button className="p-2 rounded-full bg-white shadow"><span role="img" aria-label="settings">⚙️</span></button>
              <div className="flex items-center gap-2 bg-white px-3 py-2 rounded-lg shadow">
                <span className="font-bold text-gray-900">Hello,</span>
                <span className="font-bold text-green-600">Samantha</span>
                <img src="https://randomuser.me/api/portraits/women/44.jpg" alt="User" className="w-8 h-8 rounded-full" />
              </div>
              <div className="flex items-center gap-2 bg-white px-3 py-2 rounded-lg shadow">
                <span className="text-xs text-gray-500">Filter Period</span>
                <span className="font-semibold text-sm">9 Apr 2023 - 21 May 2023</span>
              </div>
            </div>
          </div>
          <div className="flex-1 mt-2">
            <input
              type="text"
              placeholder="Search here"
              className="w-full md:w-96 px-4 py-2 rounded-lg border border-gray-200 focus:outline-none focus:ring-2 focus:ring-blue-200"
            />
          </div>
        </div>

        {/* Air Quality Status */}
        <div className="mb-6">
          <h2 className="text-2xl font-semibold mb-2">Air quality status <span className="text-green-500 font-bold">Good</span></h2>
        </div>

        {/* Levels */}
        <div className="bg-white rounded-xl shadow p-6 mb-6">
          <div className="flex flex-wrap gap-6 justify-between items-center">
            {levels.map((level, idx) => (
              <div key={idx} className="flex flex-col items-center">
                <div className="w-20 h-20 rounded-full border-8 border-blue-200 flex items-center justify-center mb-2 bg-white">
                  <span className="text-xl font-bold text-gray-900">{level.value}</span>
                </div>
                <span className="text-xs text-gray-500">{level.label}</span>
                <span className="text-xs font-semibold">{level.unit}</span>
              </div>
            ))}
          </div>
        </div>

        {/* Reports Section */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-6">
          <div className="bg-white rounded-xl shadow p-4 flex flex-col">
            <span className="font-semibold mb-2">Weekly report</span>
            <div className="flex-1 flex items-center justify-center">
              <div className="w-full h-24 bg-gray-100 rounded-lg flex items-center justify-center">
                <LineChart labels={weeklyLabels} data={weeklyData} title="Weekly AQI" />
              </div>
            </div>
            <button className="mt-2 text-xs text-blue-600 font-semibold">Save Report</button>
          </div>
          <div className="bg-white rounded-xl shadow p-4 flex flex-col">
            <span className="font-semibold mb-2">Monthly</span>
            <div className="flex-1 flex items-center justify-center">
              <div className="w-full h-24 bg-gray-100 rounded-lg flex items-center justify-center">
                <LineChart labels={monthlyLabels} data={monthlyData} title="Monthly AQI" />
              </div>
            </div>
            <button className="mt-2 text-xs text-blue-600 font-semibold">Save Report</button>
          </div>
          <div className="bg-white rounded-xl shadow p-4 flex flex-col col-span-2 lg:col-span-2">
            <span className="font-semibold mb-2">Overall report</span>
            <div className="flex-1 flex items-center justify-center">
              <div className="w-full h-48 bg-gray-100 rounded-lg p-4">
                <OverallChart data={[65, 59, 80, 81, 56, 55, 40]} />
              </div>
            </div>
          </div>
          <div className="bg-white rounded-xl shadow p-4 flex flex-col">
            <span className="font-semibold mb-2">AQI Levels</span>
            <div className="flex-1 flex items-center justify-center">
              <div className="w-full h-48 bg-gray-100 rounded-lg p-4">
                <AQILevelsChart />
              </div>
            </div>
          </div>
        </div>

        {/* Devices Section */}
        <div className="mb-6">
          <h2 className="text-2xl font-semibold mb-4 text-center">Devices</h2>
          <div className="flex flex-wrap gap-6 justify-center">
            {devices.map((device, idx) => (
              <div key={idx} className="bg-white rounded-xl shadow p-6 w-72 flex flex-col items-center">
                <div className="text-4xl mb-2">🤖</div>
                <div className="font-bold text-lg mb-1">{device.name}</div>
                <div className="text-xs text-gray-500 mb-1">{device.location}</div>
                <div className="text-xs text-green-500 mb-2">● {device.status}</div>
                <div className="grid grid-cols-3 gap-2 w-full">
                  {device.metrics.map((metric, mIdx) => (
                    <div key={mIdx} className="flex flex-col items-center">
                      <div className="w-10 h-10 rounded-full border-4 border-blue-200 flex items-center justify-center mb-1 bg-white">
                        <span className="text-xs font-bold text-gray-900">{metric.value}</span>
                      </div>
                      <span className="text-[10px] text-gray-500">{metric.label}</span>
                    </div>
                  ))}
                </div>
              </div>
            ))}
          </div>
          <div className="flex justify-center mt-6">
            <button className="px-6 py-2 bg-purple-600 text-white rounded-full font-semibold hover:bg-purple-700">View your devices</button>
          </div>
        </div>

        {/* Map Section */}
        <div className="bg-white rounded-xl shadow p-6">
          <div className="mb-2 font-semibold">Device Locations</div>
          <LoadScript googleMapsApiKey={import.meta.env.VITE_GOOGLE_MAPS_API_KEY || ''}>
            <GoogleMap
              mapContainerStyle={mapContainerStyle}
              center={userLocation || center}
              zoom={13}
            >
              {userLocation && (
                <Marker
                  position={userLocation}
                  title="Your Location"
                />
              )}
              {devices.map((device, index) => (
                <Marker
                  key={index}
                  position={{
                    lat: -1.9403 + (index * 0.01),
                    lng: 30.0588 + (index * 0.01)
                  }}
                  title={device.name}
                />
              ))}
            </GoogleMap>
          </LoadScript>
          {locationError && (
            <div className="mt-2 text-red-500 text-sm">{locationError}</div>
          )}
        </div>
      </div>
    </AppLayout>
  );
};

export default Dashboard;
