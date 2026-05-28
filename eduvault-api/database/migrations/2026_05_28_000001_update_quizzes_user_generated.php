<?php
// database/migrations/2026_05_28_000001_update_quizzes_user_generated.php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('quizzes', function (Blueprint $table) {
            // Quiz sekarang milik user tertentu, bukan global per buku
            $table->foreignId('user_id')
                  ->nullable()   // nullable agar data lama tidak error
                  ->after('ebook_id')
                  ->constrained()
                  ->onDelete('cascade');

            // 'full' = seluruh buku, 'chapter' = per bab tertentu
            $table->enum('quiz_type', ['full', 'chapter'])
                  ->default('full')
                  ->after('title');

            // Nomor bab (hanya diisi jika quiz_type = 'chapter')
            $table->unsignedSmallInteger('chapter_number')
                  ->nullable()
                  ->after('quiz_type');

            // Judul bab opsional, untuk label tampilan
            $table->string('chapter_title')
                  ->nullable()
                  ->after('chapter_number');

            $table->index(['ebook_id', 'user_id']);
        });
    }

    public function down(): void
    {
        Schema::table('quizzes', function (Blueprint $table) {
            $table->dropForeign(['user_id']);
            $table->dropIndex(['ebook_id', 'user_id']);
            $table->dropColumn(['user_id', 'quiz_type', 'chapter_number', 'chapter_title']);
        });
    }
};
