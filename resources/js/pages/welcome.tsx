import { type SharedData } from '@/types';
import { Head, Link, usePage } from '@inertiajs/react';

export default function Welcome() {
    const { auth } = usePage<SharedData>().props;

    return (
        <>
            <Head title="Welcome">
                <link rel="preconnect" href="https://fonts.bunny.net" />
                <link href="https://fonts.bunny.net/css?family=instrument-sans:400,500,600" rel="stylesheet" />
            </Head>
            <div className="w-full bg-[#F8FAFB] dark:bg-[#0a0a0a]">
                <header className="w-full border-b border-gray-200 bg-white px-6 py-4 dark:border-gray-800 dark:bg-gray-900">
                    <nav className="flex justify-end gap-4">
                        {auth.user ? (
                            <Link
                                href={route('dashboard')}
                                className="rounded-lg border border-green-200 bg-white px-5 py-2 text-sm hover:bg-green-50 dark:border-green-800 dark:bg-gray-800 dark:text-white dark:hover:bg-green-900"
                            >
                                Dashboard
                            </Link>
                        ) : (
                            <>
                                <Link
                                    href={route('login')}
                                    className="rounded-lg border border-transparent px-5 py-2 text-sm hover:bg-green-50 dark:text-white dark:hover:bg-green-900"
                                >
                                    Log in
                                </Link>
                                <Link
                                    href={route('register')}
                                    className="rounded-lg border border-green-200 bg-white px-5 py-2 text-sm hover:bg-green-50 dark:border-green-800 dark:bg-gray-800 dark:text-white dark:hover:bg-green-900"
                                >
                                    Register
                                </Link>
                            </>
                        )}
                    </nav>
                </header>
                <main className="grid w-full grid-cols-1 lg:grid-cols-2">
                    <div className="flex w-full flex-col justify-center bg-white p-6 shadow-lg dark:bg-gray-800 lg:p-20">
                        <h1 className="mb-4 text-4xl font-bold text-gray-900 dark:text-white">Welcome to AirSense</h1>
                        <p className="mb-6 text-lg text-gray-600 dark:text-gray-300">
                            Monitor and improve your air quality with our advanced sensor technology.
                            <br />
                            Get started with these features:
                        </p>
                        <ul className="mb-8 flex w-full flex-col gap-4">
                            <li className="flex items-center gap-4">
                                <span className="flex h-8 w-8 items-center justify-center rounded-full bg-green-100 text-green-600 dark:bg-green-900 dark:text-green-300">
                                    <svg className="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M5 13l4 4L19 7" />
                                    </svg>
                                </span>
                                <span className="text-gray-700 dark:text-gray-300">
                                    Real-time air quality monitoring
                                </span>
                            </li>
                            <li className="flex items-center gap-4">
                                <span className="flex h-8 w-8 items-center justify-center rounded-full bg-green-100 text-green-600 dark:bg-green-900 dark:text-green-300">
                                    <svg className="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M5 13l4 4L19 7" />
                                    </svg>
                                </span>
                                <span className="text-gray-700 dark:text-gray-300">
                                    Detailed analytics and reports
                                </span>
                            </li>
                            <li className="flex items-center gap-4">
                                <span className="flex h-8 w-8 items-center justify-center rounded-full bg-green-100 text-green-600 dark:bg-green-900 dark:text-green-300">
                                    <svg className="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M5 13l4 4L19 7" />
                                    </svg>
                                </span>
                                <span className="text-gray-700 dark:text-gray-300">
                                    Multiple device support
                                </span>
                            </li>
                        </ul>
                        <div className="flex w-full gap-4">
                            <Link
                                href={route('register')}
                                className="rounded-lg bg-green-600 px-6 py-3 text-sm font-semibold text-white hover:bg-green-700 dark:bg-green-500 dark:hover:bg-green-600"
                            >
                                Get Started
                            </Link>
                            <Link
                                href="https://docs.airsense.com"
                                target="_blank"
                                className="rounded-lg border border-gray-200 px-6 py-3 text-sm font-semibold text-gray-700 hover:bg-gray-50 dark:border-gray-700 dark:text-gray-300 dark:hover:bg-gray-800"
                            >
                                Documentation
                            </Link>
                        </div>
                    </div>
                    <div className="flex w-full items-center justify-center bg-green-50 p-6 dark:bg-green-900">
                        <div className="text-center">
                            <div className="mb-4 text-8xl">🌱</div>
                            <h2 className="mb-2 text-3xl font-bold text-green-800 dark:text-green-200">AirSense</h2>
                            <p className="text-xl text-green-600 dark:text-green-300">Breathe Better, Live Better</p>
                        </div>
                    </div>
                </main>
            </div>
        </>
    );
}
