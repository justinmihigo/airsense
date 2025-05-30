<?php

namespace App\Http\Controllers;

use App\Models\Device;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use Illuminate\Support\Facades\Auth;
use Inertia\Inertia;

class DeviceController extends Controller
{
    /**
     * Display a listing of the resource.
     */
    public function index()
    {
        $devices = Device::where('user_id', Auth::id())->get();
        return Inertia::render('devices', [
            'devices' => $devices
        ]);
    }

    public function create()
    {
        return Inertia::render('add-device');
    }

    public function edit(Device $device)
    {
        if ($device->user_id !== Auth::id()) {
            abort(403);
        }
        return Inertia::render('edit-device', [
            'device' => $device
        ]);
    }

    /**
     * Store a newly created resource in storage.
     */
    public function store(Request $request)
    {
        $request->validate([
            'name' => 'required|string|max:255',
            'location' => 'required|string|max:255',
            'sensors' => 'nullable|array'
        ]);

        $device = Device::create([
            'name' => $request->name,
            'location' => $request->location,
            'unique_id' => 'DEV' . Str::random(8),
            'user_id' => Auth::id(),
            'sensors' => $request->sensors
        ]);

        return redirect()->route('devices.index');
    }

    /**
     * Display the specified resource.
     */
    public function show(Device $device)
    {
        if ($device->user_id !== Auth::id()) {
            return response()->json(['message' => 'Unauthorized'], 403);
        }
        return response()->json($device);
    }

    /**
     * Update the specified resource in storage.
     */
    public function update(Request $request, Device $device)
    {
        if ($device->user_id !== Auth::id()) {
            abort(403);
        }

        $request->validate([
            'name' => 'required|string|max:255',
            'location' => 'required|string|max:255',
            'sensors' => 'nullable|array'
        ]);

        $device->update($request->only(['name', 'location', 'sensors']));
        return redirect()->route('devices.index');
    }

    /**
     * Remove the specified resource from storage.
     */
    public function destroy(Device $device)
    {
        if ($device->user_id !== Auth::id()) {
            abort(403);
        }

        $device->delete();
        return redirect()->route('devices.index');
    }
}
