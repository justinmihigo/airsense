import React from 'react';
import PublicLayout from '@/layouts/public-layout';
import { Link, router } from '@inertiajs/react';

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

// Define the colors based on the image
const primaryColor = '#6f42c1'; // A shade of purple from the image
const darkPurple = '#4a148c'; // Dark purple for the footer
const lightGrey = '#F7F8FA'; // Light grey background color

const Home: React.FC = () => {
    return (
        <PublicLayout>
            {/* Hero Section */}
            <div className="relative bg-cover bg-center h-[600px]" style={{ backgroundImage: "url('https://images.pexels.com/photos/2404420/pexels-photo-2404420.jpeg?auto=compress&cs=tinysrgb&w=1920')" }}>
                <div className="absolute inset-0 bg-black opacity-50"></div>
                <div className="relative z-10 flex items-center justify-center h-full">
                    <div className="text-center text-white">
                        <h1 className="text-4xl md:text-5xl font-bold leading-tight">Nowadays Air pollution is the<br/>source of many 50% of diseases</h1>
                        {/* Slider indicators/arrows would go here if implementing full slider */}
                    </div>
                </div>
            </div>

            {/* Content Section 1 */}
            <div className="py-12" style={{ backgroundColor: lightGrey }}>
                <div className="container mx-auto px-6 flex flex-col md:flex-row items-center">
                    <div className="md:w-1/2">
                        <img src="https://images.pexels.com/photos/3184465/pexels-photo-3184465.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1" alt="Students in a classroom" className="rounded-lg shadow-lg"/>
                    </div>
                    <div className="md:w-1/2 md:ml-12 mt-8 md:mt-0">
                        <p className="text-2xl text-gray-800 leading-relaxed">Students spend 60% at school, and the air quality of the air is not that good why not be a change.</p>
                        <button onClick={() => router.visit('/register')} className="mt-6 px-6 py-3 rounded-md text-white bg-purple-600 hover:bg-purple-700 text-lg font-medium">Be a part of change</button>
                    </div>
                </div>
            </div>

            {/* Content Section 2 */}
            <div className="py-12 bg-white">
                <div className="container mx-auto px-6 flex flex-col md:flex-row items-center">
                     <div className="md:w-1/2 md:mr-12 mt-8 md:mt-0">
                        <p className="text-2xl text-gray-800 leading-relaxed">Our mission is to reduce the effects of air pollution by delivering, and AI powered solution that will help them be aware of their surroundings</p>
                        <button onClick={() => router.visit('/about')} className="mt-6 px-6 py-3 rounded-md text-white bg-purple-600 hover:bg-purple-700 text-lg font-medium">Learn more</button>
                    </div>
                    <div className="md:w-1/2">
                        <img src="https://images.pexels.com/photos/1181244/pexels-photo-1181244.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1" alt="AI Technology" className="rounded-lg shadow-lg"/>
                    </div>
                </div>
            </div>

            {/* Features Section (keeping existing for now, will adjust colors) */}
            <div className="py-12 bg-white dark:bg-gray-900">
                <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
                    <div className="lg:text-center">
                        <h2 className="text-base text-purple-600 dark:text-purple-400 font-semibold tracking-wide uppercase">Features</h2>
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
                                    <div className="absolute flex items-center justify-center h-12 w-12 rounded-md bg-purple-500 text-white">
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
