<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class Sensor extends Model
{
    use HasFactory;

    protected $fillable = [
        'name',
        'location',
        'type',
        'status',
        'latitude',
        'longitude',
        'user_id'
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function airQualityData()
    {
        return $this->hasMany(AirQualityData::class);
    }
}
