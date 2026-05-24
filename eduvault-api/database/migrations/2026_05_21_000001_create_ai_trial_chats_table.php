<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('ai_trial_chats', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->onDelete('cascade');
            $table->foreignId('ebook_id')->constrained()->onDelete('cascade');
            $table->text('message');
            $table->text('response');
            $table->timestamps();

            // Index untuk query cek jumlah trial per user per buku
            $table->index(['user_id', 'ebook_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('ai_trial_chats');
    }
};
