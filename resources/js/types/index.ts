export interface Sensor {
    id: number;
    name: string;
    location: string;
    type: string;
    status: string;
    latitude: number | null;
    longitude: number | null;
    user_id: number;
    created_at: string;
    updated_at: string;
    air_quality_data?: AirQualityData[];
}

export interface AirQualityData {
    id: number;
    sensor_id: number;
    pm2_5: number | null;
    pm10: number | null;
    co2: number | null;
    voc: number | null;
    co: number | null;
    nh3: number | null;
    temperature: number | null;
    humidity: number | null;
    created_at: string;
    updated_at: string;
} 