<?php

namespace Database\Seeders;

use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class CategorySeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
    $categories = [
        ['name' => 'Ekonomi & Bisnis',       'slug' => 'ekonomi-bisnis',       'icon' => 'business'],
        ['name' => 'Teknik Informatika',      'slug' => 'teknik-informatika',   'icon' => 'computer'],
        ['name' => 'Hukum',                   'slug' => 'hukum',                'icon' => 'balance'],
        ['name' => 'Kedokteran & Kesehatan',  'slug' => 'kedokteran-kesehatan', 'icon' => 'medical'],
        ['name' => 'Pertanian & Lingkungan',  'slug' => 'pertanian-lingkungan', 'icon' => 'nature'],
        ['name' => 'Persiapan SNBT',          'slug' => 'persiapan-snbt',       'icon' => 'school'],
    ];

    foreach ($categories as $cat) {
        \App\Models\Category::create($cat);
    }
    }
}
