import React from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '@/hooks/useAuth';
import {
  Wind,
  Activity,
  Brain,
  TrendingUp,
  Bell,
  MapPin,
  Cpu,
  ArrowRight,
  ShieldCheck,
  GraduationCap,
} from 'lucide-react';

const FEATURES = [
  {
    icon: Activity,
    title: 'Real-Time Monitoring',
    text: 'Live CO₂, PM1.0, PM2.5, PM10, temperature and humidity streamed over MQTT every few seconds.',
  },
  {
    icon: Brain,
    title: 'AI-Powered Insights',
    text: 'Machine-learning models predict the Air Quality Index and turn raw readings into health guidance.',
  },
  {
    icon: TrendingUp,
    title: 'PM2.5 Forecasting',
    text: 'SARIMA time-series models forecast pollution trends so you can act before the air gets worse.',
  },
  {
    icon: Bell,
    title: 'Smart Alerts',
    text: 'Get notified the moment CO₂ or particulate levels cross WHO and EPA safety thresholds.',
  },
  {
    icon: MapPin,
    title: 'Live Sensor Map',
    text: 'See every device on an interactive map with its real-time location and current readings.',
  },
  {
    icon: Cpu,
    title: 'Multi-Device Ready',
    text: 'Sensors auto-register on first connection — manage every room from a single dashboard.',
  },
];

const STATS = [
  { value: '90%', label: 'of our time is spent indoors' },
  { value: '2–5×', label: 'higher pollutant levels indoors' },
  { value: '1000+', label: 'ppm CO₂ common in classrooms' },
  { value: '93%', label: 'of children breathe polluted air' },
];

const Landing: React.FC = () => {
  const { user } = useAuth();

  return (
    <div className="min-h-screen bg-white text-gray-900">
      {/* ---------------- Nav ---------------- */}
      <header className="sticky top-0 z-50 border-b border-gray-100 bg-white/80 backdrop-blur-md">
        <nav className="mx-auto flex max-w-6xl items-center justify-between px-6 py-4">
          <div className="flex items-center gap-2">
            <div className="flex size-9 items-center justify-center rounded-xl bg-[#22C55E]">
              <Wind className="size-5 text-white" />
            </div>
            <span className="text-xl font-bold tracking-tight">AirSense</span>
          </div>
          <div className="flex items-center gap-3">
            {user ? (
              <Link
                to="/dashboard"
                className="flex items-center gap-1.5 rounded-xl bg-[#22C55E] px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-[#16A34A]"
              >
                Go to Dashboard <ArrowRight className="size-4" />
              </Link>
            ) : (
              <>
                <Link
                  to="/login"
                  className="rounded-xl px-4 py-2 text-sm font-medium text-gray-600 transition-colors hover:bg-gray-100"
                >
                  Sign in
                </Link>
                <Link
                  to="/register"
                  className="rounded-xl bg-[#22C55E] px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-[#16A34A]"
                >
                  Get Started
                </Link>
              </>
            )}
          </div>
        </nav>
      </header>

      {/* ---------------- Hero ---------------- */}
      <section className="relative overflow-hidden">
        <div className="pointer-events-none absolute -right-32 -top-32 size-96 rounded-full bg-[#22C55E]/10 blur-3xl" />
        <div className="pointer-events-none absolute -left-32 top-40 size-96 rounded-full bg-emerald-200/30 blur-3xl" />

        <div className="mx-auto grid max-w-6xl items-center gap-12 px-6 py-20 lg:grid-cols-2 lg:py-28">
          {/* Copy */}
          <div>
            <span className="inline-flex items-center gap-1.5 rounded-full border border-[#22C55E]/30 bg-[#22C55E]/10 px-3 py-1 text-xs font-semibold text-[#16A34A]">
              <ShieldCheck className="size-3.5" /> WHO 2021 &amp; EPA 2024 standards
            </span>
            <h1 className="mt-5 text-4xl font-extrabold leading-tight tracking-tight sm:text-5xl">
              Make the air in your{' '}
              <span className="text-[#22C55E]">shared spaces</span> visible.
            </h1>
            <p className="mt-5 max-w-lg text-lg leading-relaxed text-gray-600">
              AirSense is an IoT platform that measures, predicts, and interprets
              indoor air quality in real time — so classrooms, offices, and public
              spaces can breathe easier.
            </p>
            <div className="mt-8 flex flex-wrap items-center gap-3">
              <Link
                to={user ? '/dashboard' : '/register'}
                className="flex items-center gap-2 rounded-xl bg-[#22C55E] px-6 py-3 text-sm font-semibold text-white shadow-lg shadow-[#22C55E]/25 transition-colors hover:bg-[#16A34A]"
              >
                {user ? 'Open Dashboard' : 'Start Monitoring'}
                <ArrowRight className="size-4" />
              </Link>
              <a
                href="#features"
                className="rounded-xl border border-gray-200 px-6 py-3 text-sm font-semibold text-gray-700 transition-colors hover:bg-gray-50"
              >
                See how it works
              </a>
            </div>
          </div>

          {/* Mock live card */}
          <div className="relative">
            <div className="rounded-3xl border border-gray-100 bg-white p-6 shadow-2xl shadow-gray-200/60">
              <div className="mb-4 flex items-center gap-2">
                <span className="size-2 animate-pulse rounded-full bg-[#22C55E]" />
                <span className="text-xs font-semibold uppercase tracking-wide text-gray-500">
                  Live — Classroom B
                </span>
              </div>
              <div className="grid grid-cols-3 gap-3">
                {[
                  { label: 'PM 2.5', value: '12.4', unit: 'µg/m³', color: '#F59E0B' },
                  { label: 'CO₂', value: '780', unit: 'ppm', color: '#8B5CF6' },
                  { label: 'Temp', value: '24.1', unit: '°C', color: '#22C55E' },
                  { label: 'PM 10', value: '18.7', unit: 'µg/m³', color: '#EF4444' },
                  { label: 'Humidity', value: '61', unit: '%', color: '#3B82F6' },
                  { label: 'PM 1.0', value: '5.2', unit: 'µg/m³', color: '#F97316' },
                ].map((m) => (
                  <div key={m.label} className="rounded-2xl bg-[#F6F6FA] p-3">
                    <p className="text-[10px] font-medium text-gray-500">{m.label}</p>
                    <p className="mt-1 text-lg font-bold" style={{ color: m.color }}>
                      {m.value}
                    </p>
                    <p className="text-[9px] text-gray-400">{m.unit}</p>
                  </div>
                ))}
              </div>
              <div className="mt-4 flex items-center justify-between rounded-2xl bg-[#22C55E]/10 px-4 py-3">
                <div>
                  <p className="text-xs text-gray-500">Air Quality Index</p>
                  <p className="text-2xl font-extrabold text-[#16A34A]">42</p>
                </div>
                <span className="rounded-full bg-[#22C55E] px-3 py-1 text-xs font-bold text-white">
                  Good
                </span>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* ---------------- Stats ---------------- */}
      <section className="border-y border-gray-100 bg-[#F6F6FA]">
        <div className="mx-auto grid max-w-6xl grid-cols-2 gap-8 px-6 py-12 md:grid-cols-4">
          {STATS.map((s) => (
            <div key={s.label} className="text-center">
              <p className="text-3xl font-extrabold text-[#22C55E] sm:text-4xl">
                {s.value}
              </p>
              <p className="mt-1 text-sm text-gray-600">{s.label}</p>
            </div>
          ))}
        </div>
      </section>

      {/* ---------------- Features ---------------- */}
      <section id="features" className="mx-auto max-w-6xl px-6 py-20">
        <div className="mx-auto max-w-2xl text-center">
          <h2 className="text-3xl font-extrabold tracking-tight sm:text-4xl">
            Everything you need to monitor air quality
          </h2>
          <p className="mt-4 text-gray-600">
            From live sensor data to machine-learning forecasts, AirSense gives you
            the full picture in one place.
          </p>
        </div>
        <div className="mt-14 grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
          {FEATURES.map(({ icon: Icon, title, text }) => (
            <div
              key={title}
              className="group rounded-2xl border border-gray-100 bg-white p-6 shadow-sm transition-all hover:-translate-y-1 hover:border-[#22C55E]/30 hover:shadow-lg"
            >
              <div className="flex size-12 items-center justify-center rounded-xl bg-[#22C55E]/10 transition-colors group-hover:bg-[#22C55E]">
                <Icon className="size-6 text-[#22C55E] transition-colors group-hover:text-white" />
              </div>
              <h3 className="mt-4 text-lg font-bold">{title}</h3>
              <p className="mt-2 text-sm leading-relaxed text-gray-600">{text}</p>
            </div>
          ))}
        </div>
      </section>

      {/* ---------------- Why schools ---------------- */}
      <section className="bg-[#F6F6FA]">
        <div className="mx-auto grid max-w-6xl items-center gap-12 px-6 py-20 lg:grid-cols-2">
          <div>
            <span className="inline-flex items-center gap-1.5 rounded-full bg-[#22C55E]/10 px-3 py-1 text-xs font-semibold text-[#16A34A]">
              <GraduationCap className="size-3.5" /> Built for schools
            </span>
            <h2 className="mt-5 text-3xl font-extrabold tracking-tight sm:text-4xl">
              Because clean air helps children learn
            </h2>
            <p className="mt-4 leading-relaxed text-gray-600">
              Classrooms pack 30 to 50 people into small, often poorly ventilated
              rooms. CO&#8322; builds up fast — and elevated CO&#8322; is proven to
              reduce concentration, lower test scores, and increase absenteeism.
            </p>
            <p className="mt-3 leading-relaxed text-gray-600">
              The fix is usually free: open a window at the right moment. AirSense
              makes that moment visible.
            </p>
          </div>
          <div className="grid gap-4">
            {[
              'Children breathe more air per body weight — and are far more vulnerable to pollutants.',
              'Elevated classroom CO₂ measurably impairs attention and decision-making.',
              'PM2.5 exposure drives asthma — a leading cause of school absenteeism.',
              'Simple, low-cost interventions work — once the problem can be seen.',
            ].map((point) => (
              <div
                key={point}
                className="flex items-start gap-3 rounded-2xl border border-gray-100 bg-white p-4"
              >
                <div className="mt-0.5 flex size-5 flex-shrink-0 items-center justify-center rounded-full bg-[#22C55E]">
                  <ShieldCheck className="size-3 text-white" />
                </div>
                <p className="text-sm leading-relaxed text-gray-700">{point}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ---------------- CTA ---------------- */}
      <section className="mx-auto max-w-6xl px-6 py-20">
        <div className="relative overflow-hidden rounded-3xl bg-[#22C55E] px-8 py-16 text-center">
          <div className="pointer-events-none absolute -right-16 -top-16 size-64 rounded-full bg-white/10 blur-2xl" />
          <div className="pointer-events-none absolute -bottom-16 -left-16 size-64 rounded-full bg-white/10 blur-2xl" />
          <h2 className="relative text-3xl font-extrabold text-white sm:text-4xl">
            Ready to see your air?
          </h2>
          <p className="relative mx-auto mt-4 max-w-xl text-white/90">
            Create an account, connect a sensor, and start monitoring indoor air
            quality in minutes.
          </p>
          <Link
            to={user ? '/dashboard' : '/register'}
            className="relative mt-8 inline-flex items-center gap-2 rounded-xl bg-white px-7 py-3 text-sm font-bold text-[#16A34A] shadow-lg transition-transform hover:scale-105"
          >
            {user ? 'Open Dashboard' : 'Get Started Free'}
            <ArrowRight className="size-4" />
          </Link>
        </div>
      </section>

      {/* ---------------- Footer ---------------- */}
      <footer className="border-t border-gray-100">
        <div className="mx-auto flex max-w-6xl flex-col items-center justify-between gap-4 px-6 py-8 sm:flex-row">
          <div className="flex items-center gap-2">
            <div className="flex size-7 items-center justify-center rounded-lg bg-[#22C55E]">
              <Wind className="size-4 text-white" />
            </div>
            <span className="font-bold">AirSense</span>
          </div>
          <p className="text-sm text-gray-500">
            &copy; {new Date().getFullYear()} AirSense — Indoor Air Quality Monitoring
          </p>
        </div>
      </footer>
    </div>
  );
};

export default Landing;
