import React from 'react';
import { Link } from '@inertiajs/react';

interface PublicLayoutProps {
    children: React.ReactNode;
}

const PublicLayout: React.FC<PublicLayoutProps> = ({ children }) => {
    return (
        <div className="min-h-screen bg-[#F7F8FA] flex flex-col">
            {/* Header */}
            <header className="bg-white dark:bg-gray-900">
                <nav className="container mx-auto px-6 py-3 flex justify-between items-center">
                    <div className="text-2xl font-bold text-gray-800 dark:text-white">AirSense.</div>
                    <div className="flex items-center">
                        <Link href="/" className="text-gray-800 dark:text-white px-3 py-2 rounded-md text-sm font-medium">Home</Link>
                        <Link href="/about" className="text-gray-800 dark:text-white px-3 py-2 rounded-md text-sm font-medium ml-4">About us</Link>
                        <Link href="/contact" className="text-gray-800 dark:text-white px-3 py-2 rounded-md text-sm font-medium ml-4">Contacts</Link>
                        <Link href="/register" className="ml-4 px-4 py-2 border border-transparent rounded-md text-white bg-purple-600 hover:bg-purple-700 text-sm font-medium">Sign up</Link>
                    </div>
                </nav>
            </header>

            <main className="flex-1 w-full">
                {children}
            </main>
            {/* Footer */}
            <footer className="py-8 text-gray-300 text-sm" style={{ backgroundColor: '#4a148c' }}>
                <div className="container mx-auto px-6 grid grid-cols-1 md:grid-cols-3 gap-8">
                    <div>
                        <h3 className="text-lg font-semibold text-white mb-4">Address</h3>
                        <p>Location: Kigali, Rwanda</p>
                        <p>Email: airsense@gmail.com</p>
                        <p>Phone: +250791352573</p>
                    </div>
                    <div>
                        <h3 className="text-lg font-semibold text-white mb-4">Important links</h3>
                        <ul>
                            <li><a href="#" className="hover:underline">Careers</a></li>
                            <li><a href="#" className="hover:underline">About us</a></li>
                            <li><a href="#" className="hover:underline">Contact us</a></li>
                            <li><a href="#" className="hover:underline">Terms of services</a></li>
                        </ul>
                    </div>
                    <div>
                        <h3 className="text-lg font-semibold text-white mb-4">Terms of services</h3>
                         <ul>
                            <li><a href="#" className="hover:underline">Terms of services</a></li>
                            <li><a href="#" className="hover:underline">Privacy policy</a></li>
                        </ul>
                    </div>
                </div>
                 <div className="mt-8 text-center text-gray-400">
                    &copy; 2025 AIPMS. All rights reserved.
                </div>
            </footer>
        </div>
    );
};

export default PublicLayout; 