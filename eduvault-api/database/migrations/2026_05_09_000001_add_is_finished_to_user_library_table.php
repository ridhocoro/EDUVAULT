<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('user_library', function (Blueprint $table) {
            $table->boolean('is_finished')->default(false)->after('expires_at');
            $table->timestamp('finished_at')->nullable()->after('is_finished');
        });
    }

    public function down(): void
    {
        Schema::table('user_library', function (Blueprint $table) {
            $table->dropColumn(['is_finished', 'finished_at']);
        });
    }
};
