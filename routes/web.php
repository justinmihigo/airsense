<?php

use App\Http\Controllers\Settings\ProfileController;
use App\Http\Controllers\ContactController;
use Illuminate\Support\Facades\Route;
use Inertia\Inertia;

Route::get('/', function () {
    return Inertia::render('Home');
})->name('home');

Route::get('/about', function () {
    return Inertia::render('About');
})->name('about');

Route::get('/contact', function () {
    return Inertia::render('Contact');
})->name('contact');

Route::post('/contact', [ContactController::class, 'store'])->name('contact.store');

// Dashboard route moved outside of middleware
// Route::get('/dashboard', function () {
//     return Inertia::render('Dashboard');
// })->name('dashboard');

Route::middleware(['auth'])->group(function () {
    Route::middleware(['permission:view_dashboard'])->group(function () {
    Route::get('/dashboard', function () {
            return Inertia::render('Dashboard');
        })->name('dashboard');
    });

    Route::get('/profile', function () {
        return Inertia::render('profile');
    });

    Route::patch('/profile', [ProfileController::class, 'update'])->name('profile.update');
    Route::delete('/profile', [ProfileController::class, 'destroy'])->name('profile.destroy');

    // Admin routes
    Route::middleware(['role:admin'])->group(function () {
        Route::get('/admin/users', function () {
            return Inertia::render('Admin/Users');
        })->name('admin.users');
        
        Route::get('/admin/roles', function () {
            return Inertia::render('Admin/Roles');
        })->name('admin.roles');
    });

    // Manager routes
    Route::middleware(['role:manager'])->group(function () {
        Route::get('/manager/sensors', function () {
            return Inertia::render('Manager/Sensors');
        })->name('manager.sensors');
    });

    Route::get('/notifications', function () {
        return Inertia::render('notifications');
    });

    Route::get('/devices', function () {
        return Inertia::render('devices');
    });

    Route::get('/analytics', function () {
        return Inertia::render('analytics');
    });
});

require __DIR__.'/settings.php';
require __DIR__.'/auth.php';
