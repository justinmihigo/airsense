use App\Http\Controllers\API\SensorController;
use App\Http\Controllers\API\AirQualityDataController;
use Illuminate\Support\Facades\Route;

Route::middleware('auth:sanctum')->group(function () {
    // Sensor routes
    Route::apiResource('sensors', SensorController::class);

    // Air Quality Data routes
    Route::get('air-quality-data', [AirQualityDataController::class, 'index']);
    Route::post('air-quality-data', [AirQualityDataController::class, 'store']);
    Route::get('air-quality-data/latest', [AirQualityDataController::class, 'latest']);
}); 