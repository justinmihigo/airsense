# AirSense - Air Quality Monitoring System

AirSense is a modern web application for monitoring and analyzing air quality data using advanced sensor technology. The platform provides real-time monitoring, detailed analytics, and support for multiple devices.

![AirSense](https://via.placeholder.com/800x400?text=AirSense+Dashboard)

## Features

- **Real-time Air Quality Monitoring**: Track various air quality metrics including PM2.5, PM10, CO2, VOC, CO, NH3, temperature, and humidity.
- **Interactive Dashboard**: Visualize air quality data through charts, graphs, and maps.
- **Location-based Monitoring**: View air quality data on a map with geolocation support.
- **Multiple Device Support**: Connect and manage multiple sensors across different locations.
- **Detailed Analytics**: Access comprehensive reports and trend analysis for better decision-making.
- **User Management**: Secure authentication and role-based access control.

## Tech Stack

- **Backend**: Laravel (PHP)
- **Frontend**: React with TypeScript
- **Styling**: Tailwind CSS
- **Maps**: Google Maps API
- **Charts**: Chart.js
- **Authentication**: Laravel Inertia.js

## Prerequisites

- PHP >= 8.1
- Composer
- Node.js >= 16.x
- npm or yarn
- MySQL or PostgreSQL

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/airsense.git
   cd airsense
   ```

2. Install PHP dependencies:
   ```bash
   composer install
   ```

3. Install JavaScript dependencies:
   ```bash
   npm install
   ```

4. Copy the environment file:
   ```bash
   cp .env.example .env
   ```

5. Generate application key:
   ```bash
   php artisan key:generate
   ```

6. Configure your database in the `.env` file:
   ```
   DB_CONNECTION=mysql
   DB_HOST=127.0.0.1
   DB_PORT=3306
   DB_DATABASE=airsense
   DB_USERNAME=root
   DB_PASSWORD=
   ```

7. Run database migrations:
   ```bash
   php artisan migrate
   ```

8. Optional: Seed the database with sample data:
   ```bash
   php artisan db:seed
   ```

9. Compile assets:
   ```bash
   npm run dev
   ```

10. Start the development server:
    ```bash
    php artisan serve
    ```

11. Visit `http://localhost:8000` in your browser.

## Development

### Running the Development Server

```bash
# Run Laravel server
php artisan serve

# In a separate terminal, run Vite for frontend assets
npm run dev
```

### Building for Production

```bash
npm run build
```

## API Documentation

AirSense provides a RESTful API for integrating with sensors and other applications. API endpoints include:

- `/api/sensors` - Manage sensors
- `/api/air-quality` - Access air quality data
- `/api/users` - User management

Detailed API documentation is available at `/api/documentation` after installation.

## Deployment

For production deployment, follow these additional steps:

1. Configure environment variables for production
2. Compile assets for production: `npm run build`
3. Set appropriate file permissions
4. Configure web server (Apache/Nginx) to point to the public directory

## Contributing

1. Fork the repository
2. Create your feature branch: `git checkout -b feature/amazing-feature`
3. Commit your changes: `git commit -m 'Add some amazing feature'`
4. Push to the branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- [Laravel](https://laravel.com)
- [React](https://reactjs.org)
- [Tailwind CSS](https://tailwindcss.com)
- [Chart.js](https://www.chartjs.org)
- [Google Maps API](https://developers.google.com/maps)

## Contact

For questions or support, please contact the development team at support@airsense.com.