import React from 'react';
import AppLayout from '@/layouts/app-layout';
import { Chart, registerables } from 'chart.js';
import { useEffect, useRef } from 'react';

Chart.register(...registerables);

// Mock data for charts
const weeklyData = [60, 80, 40, 70, 50, 80, 60];
const weeklyLabels = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
const monthlyData = [60, 80, 40, 70, 50, 80, 60];
const monthlyLabels = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JULY'];
const overallLabels = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sept', 'Oct', 'Nov', 'Des'];
const overallData2024 = [100, 120, 110, 180, 250, 379, 300, 200, 150, 100, 200, 250];
const overallData2025 = [200, 180, 150, 200, 300, 250, 200, 300, 250, 150, 300, 350];
const aqiLevels = [60, 80, 40, 70, 50, 80, 60];

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
  return <canvas ref={chartRef} height={120} />;
}

function MultiLineChart() {
  const chartRef = useRef<HTMLCanvasElement>(null);
  useEffect(() => {
    if (chartRef.current) {
      const ctx = chartRef.current.getContext('2d');
      if (!ctx) return;
      const chart = new Chart(ctx, {
        type: 'line',
        data: {
          labels: overallLabels,
          datasets: [
            {
              label: '2024',
              data: overallData2024,
              borderColor: '#3B82F6',
              backgroundColor: 'rgba(59,130,246,0.1)',
              fill: false,
              tension: 0.4,
            },
            {
              label: '2025',
              data: overallData2025,
              borderColor: '#F87171',
              backgroundColor: 'rgba(248,113,113,0.1)',
              fill: false,
              tension: 0.4,
            },
          ],
        },
        options: {
          plugins: { legend: { display: true } },
          scales: { y: { beginAtZero: true } },
        },
      });
      return () => chart.destroy();
    }
  }, []);
  return <canvas ref={chartRef} height={120} />;
}

function BarChart() {
  const chartRef = useRef<HTMLCanvasElement>(null);
  useEffect(() => {
    if (chartRef.current) {
      const ctx = chartRef.current.getContext('2d');
      if (!ctx) return;
      const chart = new Chart(ctx, {
        type: 'bar',
        data: {
          labels: weeklyLabels,
          datasets: [
            {
              label: 'AQI',
              data: aqiLevels,
              backgroundColor: aqiLevels.map(v => v > 60 ? '#FFD600' : '#FF5252'),
              borderRadius: 8,
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
  }, []);
  return <canvas ref={chartRef} height={120} />;
}

const Analytics: React.FC = () => {
  return (
    <AppLayout>
      <div className="bg-[#F6F6FA] min-h-screen p-8">
        <div className="max-w-6xl mx-auto">
          <input
            type="text"
            placeholder="Search analytics here"
            className="w-full mb-8 px-4 py-2 rounded-lg border border-gray-200 focus:outline-none focus:ring-2 focus:ring-green-200 bg-white"
          />
          <h2 className="text-2xl font-semibold text-green-600 mb-8">Analytics</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-8 mb-8">
            <div className="bg-white rounded-xl shadow p-6">
              <div className="flex items-center justify-between mb-2">
                <div>
                  <h4 className="text-lg font-bold">Weekly report</h4>
                  <div className="text-gray-400 text-sm">The weekly levels of overall report on air quality</div>
                </div>
                <button className="flex items-center gap-2 border border-blue-400 text-blue-500 px-4 py-1.5 rounded-lg font-semibold hover:bg-blue-50">
                  <span className="text-lg">&#8595;</span> Save Report
                </button>
              </div>
              <LineChart labels={weeklyLabels} data={weeklyData} title="Weekly AQI" />
            </div>
            <div className="bg-white rounded-xl shadow p-6">
              <div className="flex items-center justify-between mb-2">
                <div>
                  <h4 className="text-lg font-bold">Monthly</h4>
                  <div className="text-gray-400 text-sm">The monthly  levels of overall report on air quality</div>
                </div>
                <button className="flex items-center gap-2 border border-blue-400 text-blue-500 px-4 py-1.5 rounded-lg font-semibold hover:bg-blue-50">
                  <span className="text-lg">&#8595;</span> Save Report
                </button>
              </div>
              <LineChart labels={monthlyLabels} data={monthlyData} title="Monthly AQI" />
            </div>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            <div className="bg-white rounded-xl shadow p-6 col-span-2">
              <h4 className="text-lg font-bold mb-2">Overall report</h4>
              <MultiLineChart />
            </div>
            <div className="bg-white rounded-xl shadow p-6">
              <div className="flex items-center justify-between mb-2">
                <h4 className="text-lg font-bold">AQI Levels</h4>
                <select className="border rounded px-2 py-1 text-sm">
                  <option>Weekly</option>
                  <option>Monthly</option>
                </select>
              </div>
              <BarChart />
            </div>
          </div>
        </div>
      </div>
    </AppLayout>
  );
};

export default Analytics; 