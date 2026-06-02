<?php
// database/migrations/2026_06_01_000003_add_source_type_to_user_library.php
// Menambah kolom source_type ke user_library agar bisa filter
// "beli satuan" vs "subscription" di halaman koleksi

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('user_library', function (Blueprint $table) {
            // 'purchase' = beli satuan, 'subscription' = dari paket langganan
            $table->enum('source_type', ['purchase', 'subscription', 'free'])
                  ->default('purchase')
                  ->after('license_type');

            // FK ke user_subscriptions (nullable, hanya diisi jika source = subscription)
            $table->foreignId('subscription_id')
                  ->nullable()
                  ->after('source_type')
                  ->constrained('user_subscriptions')
                  ->onDelete('set null');
        });

        Schema::table('orders', function (Blueprint $table) {
            // 'ebook' = beli satuan, 'subscription' = beli paket langganan
            $table->enum('order_type', ['ebook', 'subscription'])
                  ->default('ebook')
                  ->after('status');

            // FK ke subscription_plan (nullable, diisi jika order_type = subscription)
            $table->foreignId('subscription_plan_id')
                  ->nullable()
                  ->after('order_type')
                  ->constrained('subscription_plans')
                  ->onDelete('set null');
        });
    }

    public function down(): void
    {
        Schema::table('user_library', function (Blueprint $table) {
            $table->dropForeign(['subscription_id']);
            $table->dropColumn(['source_type', 'subscription_id']);
        });

        Schema::table('orders', function (Blueprint $table) {
            $table->dropForeign(['subscription_plan_id']);
            $table->dropColumn(['order_type', 'subscription_plan_id']);
        });
    }
};
