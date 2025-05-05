<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\AirQualityData;
use App\Models\Sensor;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Validator;

class AirQualityDataController extends Controller
{
    /**
     * Display a listing of the resource.
     */
    public function index(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'sensor_id' => 'required|exists:sensors,id',
            'start_date' => 'nullable|date',
            'end_date' => 'nullable|date|after_or_equal:start_date',
        ]);

        if ($validator->fails()) {
            return response()->json($validator->errors(), 422);
        }

        $sensor = Sensor::findOrFail($request->sensor_id);
        
        if ($sensor->user_id !== Auth::id()) {
            return response()->json(['message' => 'Unauthorized'], 403);
        }

        $query = $sensor->airQualityData();

        if ($request->has('start_date')) {
            $query->where('created_at', '>=', $request->start_date);
        }

        if ($request->has('end_date')) {
            $query->where('created_at', '<=', $request->end_date);
        }

        $data = $query->orderBy('created_at', 'desc')->get();

        return response()->json($data);
    }

    /**
     * Store a newly created resource in storage.
     */
    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'sensor_id' => 'required|exists:sensors,id',
            'pm2_5' => 'nullable|numeric|min:0',
            'pm10' => 'nullable|numeric|min:0',
            'co2' => 'nullable|numeric|min:0',
            'voc' => 'nullable|numeric|min:0',
            'co' => 'nullable|numeric|min:0',
            'nh3' => 'nullable|numeric|min:0',
            'temperature' => 'nullable|numeric',
            'humidity' => 'nullable|numeric|min:0|max:100',
        ]);

        if ($validator->fails()) {
            return response()->json($validator->errors(), 422);
        }

        $sensor = Sensor::findOrFail($request->sensor_id);
        
        if ($sensor->user_id !== Auth::id()) {
            return response()->json(['message' => 'Unauthorized'], 403);
        }

        $data = $sensor->airQualityData()->create($request->all());

        return response()->json($data, 201);
    }

    /**
     * Display the specified resource.
     */
    public function show(string $id)
    {
        //
    }

    /**
     * Update the specified resource in storage.
     */
    public function update(Request $request, string $id)
    {
        //
    }

    /**
     * Remove the specified resource from storage.
     */
    public function destroy(string $id)
    {
        //
    }

    public function latest(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'sensor_id' => 'required|exists:sensors,id',
        ]);

        if ($validator->fails()) {
            return response()->json($validator->errors(), 422);
        }

        $sensor = Sensor::findOrFail($request->sensor_id);
        
        if ($sensor->user_id !== Auth::id()) {
            return response()->json(['message' => 'Unauthorized'], 403);
        }

        $latestData = $sensor->airQualityData()
            ->orderBy('created_at', 'desc')
            ->first();

        return response()->json($latestData);
    }
}
