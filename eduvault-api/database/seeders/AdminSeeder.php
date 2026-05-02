<?php
// database/seeders/AdminSeeder.php
// Jalankan dengan: php artisan db:seed --class=AdminSeeder

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class AdminSeeder extends Seeder
{
    public function run(): void
    {
        User::updateOrCreate(
            ['email' => 'admin@eduvault.id'],
            [
                'name'     => 'Admin EduVault',
                'password' => Hash::make('admin123!'),
                'role'     => 'admin',
            ]
        );

        $this->command->info('Admin berhasil dibuat:');
        $this->command->info('  Email   : admin@eduvault.id');
        $this->command->info('  Password: admin123!');
        $this->command->warn('  ⚠ Segera ganti password setelah login pertama!');
    }
}
