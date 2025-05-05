<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class AirQualityData extends Model
{
    use HasFactory;

    protected $fillable = [
        'sensor_id',
        'pm2_5',
        'pm10',
        'co2',
        'voc',
        'co',
        'nh3',
        'temperature',
        'humidity'
    ];

    public function sensor()
    {
        return $this->belongsTo(Sensor::class);
    }
}
