import React from 'react';
import { AppSidebar } from './app-sidebar';
import { SidebarProvider } from './ui/sidebar';

interface LayoutProps {
    children: React.ReactNode;
}

const Layout: React.FC<LayoutProps> = ({ children }) => {
    return (
        <SidebarProvider>
            <div className="flex min-h-screen bg-[#F7F8FA]">
                {/* Sidebar */}
                <AppSidebar />
                {/* Main Content */}
                <div className="flex-1 flex flex-col">
                    <main className="flex-1 p-8">
                        <div className="bg-white rounded-2xl shadow p-8 min-h-[80vh]">
                            {children}
                        </div>
                    </main>
                    {/* Footer */}
                    <footer className="py-4 text-center text-gray-400 text-sm">
                        &copy; {new Date().getFullYear()} AirSense. All rights reserved.
                    </footer>
                </div>
            </div>
        </SidebarProvider>
    );
};

export default Layout; 