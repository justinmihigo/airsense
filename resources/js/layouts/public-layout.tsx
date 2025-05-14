import React from 'react';

interface PublicLayoutProps {
    children: React.ReactNode;
}

const PublicLayout: React.FC<PublicLayoutProps> = ({ children }) => {
    return (
        <div className="min-h-screen w-full bg-[#F7F8FA] flex flex-col">
            <main className="flex-1 w-full">
                {children}
            </main>
            <footer className="w-full py-4 text-center text-gray-400 text-sm bg-white border-t">
                &copy; {new Date().getFullYear()} AirSense. All rights reserved.
            </footer>
        </div>
    );
};

export default PublicLayout; 