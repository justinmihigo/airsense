import { NavUser } from '@/components/nav-user';
import { Sidebar, SidebarContent, SidebarFooter, SidebarHeader, SidebarMenu, SidebarMenuButton, SidebarMenuItem, SidebarTrigger } from '@/components/ui/sidebar';
import { Link } from '@inertiajs/react';
import { LayoutGrid, BarChart2, User, Cpu, Bell, Settings, LogOut } from 'lucide-react';
import AppLogo from './app-logo';

const navItems = [
    { title: 'Dashboard', href: '/dashboard', icon: LayoutGrid },
    { title: 'Analytics', href: '/analytics', icon: BarChart2 },
    { title: 'Profile', href: '/profile', icon: User },
    { title: 'Devices', href: '/devices', icon: Cpu },
    { title: 'Notifications', href: '/notifications', icon: Bell },
    { title: 'Settings', href: '/settings/appearance', icon: Settings },
    { title: 'Logout', href: '/logout', icon: LogOut },
];

export function AppSidebar() {
    return (
        <Sidebar collapsible="icon" variant="inset" className="bg-[#E6F7EC] text-[#22C55E] border-r-0">
            <SidebarHeader>
                <div className="flex items-center gap-2 mb-2">
                    <SidebarTrigger />
                </div>
                <SidebarMenu>
                    <SidebarMenuItem>
                        <SidebarMenuButton size="lg" asChild>
                            <Link href="/dashboard" prefetch>
                                <AppLogo />
                            </Link>
                        </SidebarMenuButton>
                    </SidebarMenuItem>
                </SidebarMenu>
            </SidebarHeader>
            <SidebarContent>
                <SidebarMenu>
                    {navItems.map((item) => (
                        <SidebarMenuItem key={item.title}>
                            <SidebarMenuButton asChild>
                                <Link href={item.href} className="flex items-center gap-3 px-4 py-3 rounded-lg hover:bg-[#22C55E]/10 hover:text-[#22C55E] transition-colors">
                                    <item.icon className="size-5" />
                                    <span className="font-medium text-base">{item.title}</span>
                                </Link>
                            </SidebarMenuButton>
                        </SidebarMenuItem>
                    ))}
                </SidebarMenu>
            </SidebarContent>
            <SidebarFooter>
                <div className="mt-auto mb-4 flex flex-col items-center">
                    <NavUser />
                </div>
            </SidebarFooter>
        </Sidebar>
    );
}
