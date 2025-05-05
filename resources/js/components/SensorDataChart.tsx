import { useEffect, useRef } from 'react';
import { Chart, registerables } from 'chart.js';
import { AirQualityData, Sensor } from '@/types';

Chart.register(...registerables);

interface SensorDataChartProps {
    data: AirQualityData[];
    sensor: Sensor;
}

export default function SensorDataChart({ data, sensor }: SensorDataChartProps) {
    const chartRef = useRef<HTMLCanvasElement>(null);
    const chartInstance = useRef<Chart | null>(null);

    useEffect(() => {
        if (chartRef.current && data.length > 0) {
            const ctx = chartRef.current.getContext('2d');
            if (!ctx) return;

            // Destroy previous chart instance if it exists
            if (chartInstance.current) {
                chartInstance.current.destroy();
            }

            // Prepare data for chart
            const labels = data.map(item => new Date(item.created_at).toLocaleTimeString());
            const datasets = [
                {
                    label: 'PM2.5 (µg/m³)',
                    data: data.map(item => item.pm2_5),
                    borderColor: 'rgb(75, 192, 192)',
                    tension: 0.1,
                },
                {
                    label: 'CO2 (ppm)',
                    data: data.map(item => item.co2),
                    borderColor: 'rgb(255, 99, 132)',
                    tension: 0.1,
                },
                {
                    label: 'Temperature (°C)',
                    data: data.map(item => item.temperature),
                    borderColor: 'rgb(255, 159, 64)',
                    tension: 0.1,
                },
            ];

            // Create new chart instance
            chartInstance.current = new Chart(ctx, {
                type: 'line',
                data: {
                    labels,
                    datasets,
                },
                options: {
                    responsive: true,
                    plugins: {
                        title: {
                            display: true,
                            text: `Air Quality Data - ${sensor.name}`,
                        },
                    },
                    scales: {
                        y: {
                            beginAtZero: true,
                        },
                    },
                },
            });
        }

        // Cleanup function
        return () => {
            if (chartInstance.current) {
                chartInstance.current.destroy();
            }
        };
    }, [data, sensor]);

    return (
        <div className="bg-white dark:bg-gray-800 shadow rounded-lg p-6">
            <canvas ref={chartRef}></canvas>
        </div>
    );
} 