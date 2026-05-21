import { Link, useLocation } from 'react-router-dom';
import { BarChart2, Bell, Cpu, LayoutGrid, LogOut, User, Wind } from 'lucide-react';
import { useAuth } from '@/hooks/useAuth';

const navItems = [
  { title: 'Dashboard', href: '/dashboard', icon: LayoutGrid },
  { title: 'Analytics', href: '/analytics', icon: BarChart2 },
  { title: 'Devices', href: '/devices', icon: Cpu },
  { title: 'Notifications', href: '/notifications', icon: Bell },
  { title: 'Profile', href: '/profile', icon: User },
];

export default function AppSidebar() {
  const { pathname } = useLocation();
  const { user, logout } = useAuth();

  const initials = user?.name
    ? user.name.trim().split(' ').filter(Boolean).map((p) => p[0]).slice(0, 2).join('').toUpperCase()
    : '??';

  return (
    <aside className="flex h-screen w-60 flex-col border-r border-gray-100 bg-white">
      <div className="border-b border-gray-100 p-4">
        <Link to="/dashboard" className="flex items-center gap-2">
          <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-[#22C55E]">
            <Wind className="size-4 text-white" />
          </div>
          <span className="text-lg font-bold text-gray-900">AirSense</span>
        </Link>
      </div>

      <nav className="flex-1 space-y-0.5 p-3">
        {navItems.map((item) => {
          const isActive = pathname.startsWith(item.href);
          return (
            <Link
              key={item.href}
              to={item.href}
              className={`flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium transition-colors ${
                isActive
                  ? 'bg-[#22C55E]/10 text-[#16A34A]'
                  : 'text-gray-600 hover:bg-gray-100 hover:text-gray-900'
              }`}
            >
              <item.icon className={`size-4 flex-shrink-0 ${isActive ? 'text-[#22C55E]' : ''}`} />
              <span>{item.title}</span>
              {isActive && <span className="ml-auto size-1.5 rounded-full bg-[#22C55E]" />}
            </Link>
          );
        })}
      </nav>

      <div className="border-t border-gray-100 p-4">
        <div className="mb-3 flex items-center gap-3">
          <div className="flex h-8 w-8 flex-shrink-0 items-center justify-center rounded-full bg-[#22C55E]/15 text-xs font-bold text-[#16A34A]">
            {initials}
          </div>
          <div className="min-w-0 flex-1">
            <p className="truncate text-sm font-medium text-gray-900">{user?.name}</p>
            <p className="truncate text-xs text-gray-500">{user?.email}</p>
          </div>
        </div>
        <button
          onClick={logout}
          className="flex w-full items-center gap-2 rounded-xl px-3 py-2 text-sm text-gray-600 hover:bg-gray-100 transition-colors"
        >
          <LogOut className="size-4" />
          Sign out
        </button>
      </div>
    </aside>
  );
}
