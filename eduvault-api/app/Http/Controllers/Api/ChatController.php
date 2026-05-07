<?php
// app/Http/Controllers/Api/ChatController.php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Ebook;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class ChatController extends Controller
{
    /**
     * Kirim pesan ke AI
     * POST /api/v1/books/{book_id}/chat
     */
    public function send(Request $request, $bookId)
    {
        // 1. Validasi input
        $request->validate([
            'message' => 'required|string|max:4000',
        ]);

        // 2. Ambil data user dan pesan
        $user = $request->user();
        $message = $request->message;

        // 3. Ambil data buku
        $book = Ebook::findOrFail($bookId);

        // 4. Siapkan prompt untuk AI
        $systemPrompt = $this->getSystemPrompt($book);

        try {
            // 5. Panggil API Groq
            $response = Http::withHeaders([
                'Authorization' => 'Bearer ' . env('GROQ_API_KEY'),
                'Content-Type' => 'application/json',
            ])->timeout(60)->post('https://api.groq.com/openai/v1/chat/completions', [
                'model' => env('GROQ_MODEL', 'llama3-8b-8192'),
                'messages' => [
                    [
                        'role' => 'system',
                        'content' => $systemPrompt
                    ],
                    [
                        'role' => 'user',
                        'content' => $message
                    ]
                ],
                'temperature' => 0.7,
                'max_tokens' => 1024,
            ]);

            // 6. Cek apakah request berhasil
            if ($response->successful()) {
                $aiResponse = $response->json()['choices'][0]['message']['content'];
                
                return response()->json([
                    'success' => true,
                    'response' => $aiResponse,
                ]);
            } else {
                // Log error untuk debugging
                Log::error('Groq API Error: ' . $response->body());
                
                return response()->json([
                    'success' => false,
                    'error' => 'Maaf, AI sedang sibuk. Silakan coba lagi.',
                ], 500);
            }
            
        } catch (\Exception $e) {
            // Tangani exception
            Log::error('Chat Error: ' . $e->getMessage());
            
            return response()->json([
                'success' => false,
                'error' => 'Maaf, terjadi kesalahan. Silakan coba lagi.',
            ], 500);
        }
    }

    /**
     * Buat prompt untuk AI berdasarkan konteks buku
     */
    private function getSystemPrompt($book): string
    {
        $prompt = "Anda adalah asisten AI untuk aplikasi EduVault yang membantu pembaca memahami isi buku digital.\n\n";
        $prompt .= "Konteks Buku:\n";
        $prompt .= "- Judul: " . ($book->title ?? 'Tidak diketahui') . "\n";
        $prompt .= "- Penulis: " . ($book->author ?? 'Tidak diketahui') . "\n";
        $prompt .= "- Deskripsi: " . ($book->description ?? 'Tidak ada deskripsi') . "\n\n";
        $prompt .= "Instruksi:\n";
        $prompt .= "1. Jawab pertanyaan berdasarkan konteks buku di atas\n";
        $prompt .= "2. Jika pertanyaan di luar konteks buku, sampaikan bahwa Anda hanya bisa menjawab tentang buku ini\n";
        $prompt .= "3. Gunakan bahasa Indonesia yang baik dan mudah dipahami\n";
        $prompt .= "4. Berikan jawaban yang membantu, informatif, dan akurat\n";
        $prompt .= "5. Jika tidak tahu jawabannya, akui dengan jujur dan sarankan membaca buku lebih lanjut\n\n";
        $prompt .= "Tujuan Anda adalah membantu pembaca mendapatkan pemahaman lebih baik tentang buku yang telah mereka beli.";
        
        return $prompt;
    }
}