<?php

namespace Database\Seeders;

use App\Models\Permission;
use App\Models\Role;
use Illuminate\Database\Seeder;
use Spatie\Permission\PermissionRegistrar;

class RolePermissionSeeder extends Seeder
{
    public function run(): void
    {
        // Reset cached roles and permissions
        app()[PermissionRegistrar::class]->forgetCachedPermissions();

        // Create permissions
        $permissions = [
            'view_dashboard' => 'View dashboard',
            'manage_sensors' => 'Manage sensors',
            'view_reports' => 'View reports',
            'manage_users' => 'Manage users',
            'manage_roles' => 'Manage roles',
        ];

        foreach ($permissions as $name => $description) {
            Permission::create([
                'name' => $name,
                'description' => $description,
                'guard_name' => 'web',
            ]);
        }

        // Create roles
        $roles = [
            'admin' => [
                'description' => 'Administrator with full access',
                'permissions' => array_keys($permissions),
            ],
            'manager' => [
                'description' => 'Manager with limited access',
                'permissions' => ['view_dashboard', 'manage_sensors', 'view_reports'],
            ],
            'user' => [
                'description' => 'Regular user with basic access',
                'permissions' => ['view_dashboard', 'view_reports'],
            ],
        ];

        foreach ($roles as $name => $data) {
            $role = Role::create([
                'name' => $name,
                'description' => $data['description'],
                'guard_name' => 'web',
            ]);

            $role->syncPermissions($data['permissions']);
        }
    }
} 