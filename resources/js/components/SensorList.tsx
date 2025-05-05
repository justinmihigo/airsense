import { Sensor } from '@/types';

interface SensorListProps {
    sensors: Sensor[];
    selectedSensor: Sensor | null;
    onSelectSensor: (sensor: Sensor) => void;
}

export default function SensorList({ sensors, selectedSensor, onSelectSensor }: SensorListProps) {
    return (
        <div className="bg-white dark:bg-gray-800 shadow rounded-lg p-6">
            <h2 className="text-lg font-medium text-gray-900 dark:text-white mb-4">
                Sensors
            </h2>
            <div className="space-y-4">
                {sensors.map((sensor) => (
                    <button
                        key={sensor.id}
                        onClick={() => onSelectSensor(sensor)}
                        className={`w-full p-4 rounded-lg transition-colors ${
                            selectedSensor?.id === sensor.id
                                ? 'bg-blue-50 dark:bg-blue-900 border-blue-500'
                                : 'bg-gray-50 dark:bg-gray-700 hover:bg-gray-100 dark:hover:bg-gray-600'
                        } border`}
                    >
                        <div className="flex items-center justify-between">
                            <div>
                                <h3 className="text-sm font-medium text-gray-900 dark:text-white">
                                    {sensor.name}
                                </h3>
                                <p className="text-sm text-gray-500 dark:text-gray-400">
                                    {sensor.location}
                                </p>
                            </div>
                            <span
                                className={`px-2 py-1 text-xs rounded-full ${
                                    sensor.status === 'active'
                                        ? 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200'
                                        : 'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200'
                                }`}
                            >
                                {sensor.status}
                            </span>
                        </div>
                    </button>
                ))}
            </div>
        </div>
    );
} 