import React, { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '@/hooks/useAuth';
import { CheckCircle } from 'lucide-react';

const Profile: React.FC = () => {
  const { user, updateProfile } = useAuth();

  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (user) {
      setName(user.name);
      setEmail(user.email);
    }
  }, [user]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setSaved(false);
    setSaving(true);
    try {
      await updateProfile({ name, email });
      setSaved(true);
      setTimeout(() => setSaved(false), 3000);
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'Failed to update profile';
      setError(
        (err as { response?: { data?: { detail?: string } } }).response?.data?.detail ?? msg,
      );
    } finally {
      setSaving(false);
    }
  };

  const initials = user?.name
    ? user.name.trim().split(' ').filter(Boolean).map((p) => p[0]).slice(0, 2).join('').toUpperCase()
    : '??';

  return (
    <div className="bg-[#F6F6FA] min-h-screen p-8">
      <div className="max-w-5xl mx-auto">
        <h2 className="text-2xl font-semibold mb-1">
          Welcome Back, <span className="text-black">{user?.name?.split(' ')[0] ?? 'User'}</span>
        </h2>
        <h3 className="text-xl text-green-600 font-semibold mb-8">Your Profile</h3>

        <div className="bg-white rounded-xl shadow p-8 flex flex-col gap-8">
          {/* Avatar + basic info */}
          <div>
            <h4 className="text-lg font-bold mb-4">Basic Information</h4>
            <div className="flex flex-col md:flex-row gap-8 items-center">
              {/* Avatar placeholder */}
              <div className="flex h-28 w-28 flex-shrink-0 items-center justify-center rounded-full bg-[#22C55E]/15 text-3xl font-bold text-[#16A34A]">
                {initials}
              </div>

              <form onSubmit={handleSubmit} className="flex-1 w-full">
                {saved && (
                  <div className="mb-4 flex items-center gap-2 rounded-xl border border-green-200 bg-green-50 px-4 py-3 text-sm text-green-700">
                    <CheckCircle className="size-4" />
                    Profile updated successfully.
                  </div>
                )}
                {error && (
                  <div className="mb-4 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
                    {error}
                  </div>
                )}

                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                  <div>
                    <label className="block text-gray-500 text-sm mb-1">Full name</label>
                    <input
                      type="text"
                      value={name}
                      onChange={(e) => setName(e.target.value)}
                      required
                      className="w-full px-4 py-2 rounded-full bg-[#F6F6FA] border border-gray-200 text-gray-700 font-medium focus:outline-none focus:border-[#22C55E] focus:ring-2 focus:ring-[#22C55E]/20"
                    />
                  </div>
                  <div>
                    <label className="block text-gray-500 text-sm mb-1">Email</label>
                    <input
                      type="email"
                      value={email}
                      onChange={(e) => setEmail(e.target.value)}
                      required
                      className="w-full px-4 py-2 rounded-full bg-[#F6F6FA] border border-gray-200 text-gray-700 font-medium focus:outline-none focus:border-[#22C55E] focus:ring-2 focus:ring-[#22C55E]/20"
                    />
                  </div>
                  <div>
                    <label className="block text-gray-500 text-sm mb-1">Role</label>
                    <input
                      value={user?.role ?? '—'}
                      readOnly
                      className="w-full px-4 py-2 rounded-full bg-[#F6F6FA] border border-gray-200 text-gray-500 font-medium cursor-not-allowed"
                    />
                  </div>
                  <div>
                    <label className="block text-gray-500 text-sm mb-1">Member since</label>
                    <input
                      value={user?.created_at ? new Date(user.created_at).toLocaleDateString() : '—'}
                      readOnly
                      className="w-full px-4 py-2 rounded-full bg-[#F6F6FA] border border-gray-200 text-gray-500 font-medium cursor-not-allowed"
                    />
                  </div>
                </div>

                <button
                  type="submit"
                  disabled={saving}
                  className="mt-6 w-full py-3 rounded-full bg-[#6C2BD7] text-white font-semibold text-lg hover:bg-[#4B1A9A] disabled:opacity-60 transition-colors"
                >
                  {saving ? 'Saving…' : 'Update Profile'}
                </button>
              </form>
            </div>
          </div>

          {/* Quick links */}
          <div className="border-t border-gray-100 pt-6">
            <h4 className="text-lg font-bold mb-4">Quick Links</h4>
            <div className="flex flex-wrap gap-3">
              <Link
                to="/devices"
                className="rounded-full border border-[#6C2BD7] px-5 py-2 text-sm font-semibold text-[#6C2BD7] hover:bg-[#6C2BD7] hover:text-white transition-colors"
              >
                Manage Devices
              </Link>
              <Link
                to="/notifications"
                className="rounded-full border border-gray-300 px-5 py-2 text-sm font-semibold text-gray-600 hover:bg-gray-100 transition-colors"
              >
                Notifications
              </Link>
              <Link
                to="/dashboard"
                className="rounded-full border border-gray-300 px-5 py-2 text-sm font-semibold text-gray-600 hover:bg-gray-100 transition-colors"
              >
                Dashboard
              </Link>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Profile;
