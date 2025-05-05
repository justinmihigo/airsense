<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class CheckPermission
{
    /**
     * Handle an incoming request.
     *
     * @param  \Closure(\Illuminate\Http\Request): (\Symfony\Component\HttpFoundation\Response)  $next
     */
    public function handle(Request $request, Closure $next, string $permission): Response
    {
        // Temporarily bypass permission check for development
        return $next($request);
        
        // Uncomment this code when you want to implement actual permission checks
        /*
        if (!$request->user() || !$request->user()->hasPermissionTo($permission)) {
            abort(403, 'Unauthorized action.');
        }
        */
    }
} 