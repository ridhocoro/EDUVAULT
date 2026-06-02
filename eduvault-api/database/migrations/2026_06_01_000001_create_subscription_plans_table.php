<?php
// database/migrations/2026_06_01_000001_create_subscription_plans_table.php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('subscription_plans', function (Blueprint $table) {
            $table->id();
            $table->string('name');                     // "Paket Basic", "Paket Premium"
            $table->text('description')->nullable();
            $table->decimal('price', 10, 2);
            $table->integer('duration_days')->default(30);
            $table->enum('status', ['active', 'inactive'])->default('active');
            $table->timestamps();
        });

        // Pivot: ebook apa saja yang termasuk dalam sebuah paket
        Schema::create('subscription_plan_ebooks', function (Blueprint $table) {
            $table->id();
            $table->foreignId('subscription_plan_id')
                  ->constrained()->onDelete('cascade');
            $table->foreignId('ebook_id')
                  ->constrained()->onDelete('cascade');
            $table->unique(['subscription_plan_id', 'ebook_id']);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('subscription_plan_ebooks');
        Schema::dropIfExists('subscription_plans');
    }
};
