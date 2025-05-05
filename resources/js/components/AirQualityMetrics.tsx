import { AirQualityData, Sensor } from '@/types';

interface AirQualityMetricsProps {
    data: AirQualityData;
    sensor: Sensor;
}

export default function AirQualityMetrics({ data, sensor }: AirQualityMetricsProps) {
    const metrics = [
        {
            name: 'PM2.5',
            value: data.pm2_5,
            unit: 'µg/m³',
            good: 0,
            moderate: 12,
            unhealthy: 35,
        },
        {
            name: 'PM10',
            value: data.pm10,
            unit: 'µg/m³',
            good: 0,
            moderate: 54,
            unhealthy: 154,
        },
        {
            name: 'CO2',
            value: data.co2,
            unit: 'ppm',
            good: 0,
            moderate: 1000,
            unhealthy: 2000,
        },
        {
            name: 'Temperature',
            value: data.temperature,
            unit: '°C',
            good: 20,
            moderate: 25,
            unhealthy: 30,
        },
        {
            name: 'Humidity',
            value: data.humidity,
            unit: '%',
            good: 40,
            moderate: 60,
            unhealthy: 80,
        },
    ];

    const getQualityColor = (value: number | null, good: number, moderate: number, unhealthy: number) => {
        if (value === null) return 'bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-200';
        if (value <= good) return 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200';
        if (value <= moderate) return 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200';
        return 'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200';
    };

    return (
        <div className="bg-white dark:bg-gray-800 shadow rounded-lg p-6">
            <h2 className="text-lg font-medium text-gray-900 dark:text-white mb-4">
                Current Air Quality - {sensor.name}
            </h2>
            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
                {metrics.map((metric) => (
                    <div
                        key={metric.name}
                        className={`p-4 rounded-lg ${getQualityColor(
                            metric.value,
                            metric.good,
                            metric.moderate,
                            metric.unhealthy
                        )}`}
                    >
                        <h3 className="text-sm font-medium">{metric.name}</h3>
                        <p className="text-2xl font-semibold">
                            {metric.value !== null ? metric.value.toFixed(1) : 'N/A'} {metric.unit}
                        </p>
                    </div>
                ))}
            </div>
        </div>
    );
} 