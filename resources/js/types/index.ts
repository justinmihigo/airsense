import { LucideIcon } from 'lucide-react';
import type { Config } from 'ziggy-js';

export interface Auth {
    user: User;
}

export interface BreadcrumbItem {
    title: string;
    href: string;
}

export interface NavGroup {
    title: string;
    items: NavItem[];
}

export interface NavItem {
    title: string;
    href: string;
    icon?: LucideIcon | null;
    isActive?: boolean;
}

export interface SharedData {
    name: string;
    quote: { message: string; author: string };
    auth: Auth;
    ziggy: Config & { location: string };
    sidebarOpen: boolean;
    [key: string]: unknown;
}

export interface User {
    id: number;
    name: string;
    email: string;
    avatar?: string;
    email_verified_at: string | null;
    created_at: string;
    updated_at: string;
    [key: string]: unknown;
}

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