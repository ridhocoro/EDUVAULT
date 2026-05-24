<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Tabel quiz (satu buku bisa punya satu quiz aktif)
        Schema::create('quizzes', function (Blueprint $table) {
            $table->id();
            $table->foreignId('ebook_id')->constrained()->onDelete('cascade');
            $table->string('title');
            $table->enum('status', ['draft', 'published'])->default('draft');
            $table->timestamps();

            $table->index('ebook_id');
        });

        // Tabel soal quiz (multiple choice, 4 pilihan)
        Schema::create('quiz_questions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('quiz_id')->constrained()->onDelete('cascade');
            $table->integer('order')->default(0);
            $table->text('question');
            $table->string('option_a');
            $table->string('option_b');
            $table->string('option_c');
            $table->string('option_d');
            $table->enum('correct_answer', ['a', 'b', 'c', 'd']);
            $table->text('explanation')->nullable(); // Penjelasan kenapa jawaban benar
            $table->timestamps();

            $table->index(['quiz_id', 'order']);
        });

        // Tabel hasil quiz user (track progress & skor)
        Schema::create('quiz_attempts', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->onDelete('cascade');
            $table->foreignId('quiz_id')->constrained()->onDelete('cascade');
            $table->integer('score');          // Jumlah jawaban benar
            $table->integer('total');          // Total soal
            $table->integer('duration_seconds')->nullable(); // Durasi pengerjaan
            $table->timestamps();

            $table->index(['user_id', 'quiz_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('quiz_attempts');
        Schema::dropIfExists('quiz_questions');
        Schema::dropIfExists('quizzes');
    }
};
