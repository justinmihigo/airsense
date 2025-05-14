import React from 'react';
import PublicLayout from '@/layouts/public-layout';

const About: React.FC = () => {
    const features = [
        {
            title: "Real-Time Monitoring",
            description: "Our system provides instant updates on air quality conditions in your area, helping you make informed decisions about your environment.",
            icon: "🌐"
        },
        {
            title: "Advanced Sensors",
            description: "We use state-of-the-art sensors to measure various air quality parameters including PM2.5, PM10, CO2, temperature, and humidity.",
            icon: "📡"
        },
        {
            title: "Health Insights",
            description: "Get personalized health recommendations based on current air quality conditions and your specific health needs.",
            icon: "💡"
        },
        {
            title: "Data Analytics",
            description: "Access historical data and trends to understand long-term air quality patterns in your area.",
            icon: "📊"
        }
    ];

    return (
        <PublicLayout>
            <div className="py-12 bg-white dark:bg-gray-900">
                <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
                    <div className="lg:text-center">
                        <h2 className="text-base text-blue-600 dark:text-blue-400 font-semibold tracking-wide uppercase">About AirSense</h2>
                        <p className="mt-2 text-3xl leading-8 font-extrabold tracking-tight text-gray-900 dark:text-white sm:text-4xl">
                            Monitoring Air Quality for a Healthier Future
                        </p>
                        <p className="mt-4 max-w-2xl text-xl text-gray-500 dark:text-gray-300 lg:mx-auto">
                            AirSense is dedicated to providing accurate, real-time air quality monitoring solutions to help individuals and communities make informed decisions about their environment.
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

                    <div className="mt-20">
                        <div className="bg-blue-50 dark:bg-gray-800 rounded-lg p-8">
                            <h3 className="text-2xl font-bold text-gray-900 dark:text-white mb-4">Our Mission</h3>
                            <p className="text-gray-600 dark:text-gray-300 mb-6">
                                At AirSense, we believe that everyone has the right to breathe clean air. Our mission is to empower individuals and communities with accurate, real-time air quality data and insights to make informed decisions about their environment and health.
                            </p>
                            <p className="text-gray-600 dark:text-gray-300">
                                Through our advanced monitoring system and user-friendly platform, we aim to raise awareness about air quality issues and contribute to creating healthier living environments for all.
                            </p>
                        </div>
                    </div>

                    <div className="mt-20">
                        <h3 className="text-2xl font-bold text-gray-900 dark:text-white mb-6">How It Works</h3>
                        <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
                            <div className="bg-white dark:bg-gray-800 p-6 rounded-lg shadow">
                                <div className="text-4xl mb-4">1</div>
                                <h4 className="text-lg font-semibold text-gray-900 dark:text-white mb-2">Data Collection</h4>
                                <p className="text-gray-600 dark:text-gray-300">
                                    Our network of sensors collects real-time air quality data from various locations.
                                </p>
                            </div>
                            <div className="bg-white dark:bg-gray-800 p-6 rounded-lg shadow">
                                <div className="text-4xl mb-4">2</div>
                                <h4 className="text-lg font-semibold text-gray-900 dark:text-white mb-2">Data Analysis</h4>
                                <p className="text-gray-600 dark:text-gray-300">
                                    Advanced algorithms process the data to provide accurate air quality measurements.
                                </p>
                            </div>
                            <div className="bg-white dark:bg-gray-800 p-6 rounded-lg shadow">
                                <div className="text-4xl mb-4">3</div>
                                <h4 className="text-lg font-semibold text-gray-900 dark:text-white mb-2">User Access</h4>
                                <p className="text-gray-600 dark:text-gray-300">
                                    Users can access real-time data and insights through our web platform and mobile app.
                                </p>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </PublicLayout>
    );
};

export default About; 