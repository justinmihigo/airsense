import React from 'react';
import PublicLayout from '@/layouts/public-layout';
import { Link } from '@inertiajs/react';

const features = [
    {
        title: "Real-Time Monitoring",
        description: "Get instant updates on air quality in your area with our advanced sensor network.",
        icon: "🌐"
    },
    {
        title: "Health Insights",
        description: "Receive personalized health recommendations based on current air quality conditions.",
        icon: "💡"
    },
    {
        title: "Smart Alerts",
        description: "Get notified when air quality reaches concerning levels in your area.",
        icon: "🔔"
    },
    {
        title: "Historical Data",
        description: "Track air quality trends over time with our comprehensive data analytics.",
        icon: "📊"
    }
];

const Home: React.FC = () => {
    return (
        <PublicLayout>
            {/* Hero Section */}
            <div className="relative bg-white dark:bg-gray-900 overflow-hidden">
                <div className="max-w-7xl mx-auto">
                    <div className="relative z-10 pb-8 bg-white dark:bg-gray-900 sm:pb-16 md:pb-20 lg:max-w-2xl lg:w-full lg:pb-28 xl:pb-32">
                        <main className="mt-10 mx-auto max-w-7xl px-4 sm:mt-12 sm:px-6 md:mt-16 lg:mt-20 lg:px-8 xl:mt-28">
                            <div className="sm:text-center lg:text-left">
                                <h1 className="text-4xl tracking-tight font-extrabold text-gray-900 dark:text-white sm:text-5xl md:text-6xl">
                                    <span className="block">Monitor Air Quality</span>
                                    <span className="block text-blue-600 dark:text-blue-400">For a Healthier Tomorrow</span>
                                </h1>
                                <p className="mt-3 text-base text-gray-500 dark:text-gray-300 sm:mt-5 sm:text-lg sm:max-w-xl sm:mx-auto md:mt-5 md:text-xl lg:mx-0">
                                    AirSense provides real-time air quality monitoring and health insights to help you make informed decisions about your environment.
                                </p>
                                <div className="mt-5 sm:mt-8 sm:flex sm:justify-center lg:justify-start">
                                    <div className="rounded-md shadow">
                                        <Link
                                            href="/register"
                                            className="w-full flex items-center justify-center px-8 py-3 border border-transparent text-base font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 md:py-4 md:text-lg md:px-10"
                                        >
                                            Get Started
                                        </Link>
                                    </div>
                                    <div className="mt-3 sm:mt-0 sm:ml-3">
                                        <Link
                                            href="/about"
                                            className="w-full flex items-center justify-center px-8 py-3 border border-transparent text-base font-medium rounded-md text-blue-700 bg-blue-100 hover:bg-blue-200 md:py-4 md:text-lg md:px-10"
                                        >
                                            Learn More
                                        </Link>
                                    </div>
                                </div>
                            </div>
                        </main>
                    </div>
                </div>
            </div>

            {/* Features Section */}
            <div className="py-12 bg-white dark:bg-gray-900">
                <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
                    <div className="lg:text-center">
                        <h2 className="text-base text-blue-600 dark:text-blue-400 font-semibold tracking-wide uppercase">Features</h2>
                        <p className="mt-2 text-3xl leading-8 font-extrabold tracking-tight text-gray-900 dark:text-white sm:text-4xl">
                            Everything you need to monitor air quality
                        </p>
                        <p className="mt-4 max-w-2xl text-xl text-gray-500 dark:text-gray-300 lg:mx-auto">
                            Our comprehensive platform provides all the tools you need to understand and respond to air quality conditions.
                        </p>
                    </div>

                    <div className="mt-10">
                        <div className="space-y-10 md:space-y-0 md:grid md:grid-cols-2 md:gap-x-8 md:gap-y-10">
                            {features.map((feature) => (
                                <div key={feature.title} className="relative">
                                    <div className="absolute flex items-center justify-center h-12 w-12 rounded-md bg-blue-500 text-white">
                                        <span className="text-2xl">{feature.icon}</span>
                                    </div>
                                    <div className="ml-16">
                                        <h3 className="text-lg leading-6 font-medium text-gray-900 dark:text-white">{feature.title}</h3>
                                        <p className="mt-2 text-base text-gray-500 dark:text-gray-300">
                                            {feature.description}
                                        </p>
                                    </div>
                                </div>
                            ))}
                        </div>
                    </div>
                </div>
            </div>
        </PublicLayout>
    );
};

export default Home; 