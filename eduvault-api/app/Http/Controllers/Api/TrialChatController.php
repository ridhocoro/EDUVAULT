<?php
// app/Http/Controllers/Api/TrialChatController.php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AiTrialChat;
use App\Models\Ebook;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class TrialChatController extends Controller
{
    const MAX_TRIALS = 3;

    /**
     * Cek status trial untuk buku tertentu
     * GET /api/v1/ebooks/{ebookId}/trial-chat/status
     */
    public function status(Request $request, int $ebookId): \Illuminate\Http\JsonResponse
    {
        $user  = $request->user();
        $used  = AiTrialChat::countTrials($user->id, $ebookId);
        $remaining = max(0, self::MAX_TRIALS - $used);

        return response()->json([
            'used'      => $used,
            'max'       => self::MAX_TRIALS,
            'remaining' => $remaining,
            'exhausted' => $remaining === 0,
        ]);
    }

    /**
     * Kirim pertanyaan trial AI
     * POST /api/v1/ebooks/{ebookId}/trial-chat
     */
    public function send(Request $request, int $ebookId): \Illuminate\Http\JsonResponse
    {
        $request->validate([
            'message' => 'required|string|max:1000',
        ]);

        $user = $request->user();

        // Cek limit
        $used = AiTrialChat::countTrials($user->id, $ebookId);
        if ($used >= self::MAX_TRIALS) {
            return response()->json([
                'success' => false,
                'error'   => 'Batas trial AI sudah habis. Beli buku ini untuk akses penuh.',
                'exhausted' => true,
            ], 403);
        }

        // Ambil data buku
        $book = Ebook::findOrFail($ebookId);

        // Sistem prompt khusus trial — lebih terbatas, mendorong pembelian
        $systemPrompt = $this->getTrialSystemPrompt($book);

        try {
            $response = Http::withHeaders([
                'Authorization' => 'Bearer ' . env('GROQ_API_KEY'),
                'Content-Type'  => 'application/json',
            ])->timeout(60)->post('https://api.groq.com/openai/v1/chat/completions', [
                'model' => env('GROQ_MODEL', 'llama3-8b-8192'),
                'messages' => [
                    ['role' => 'system', 'content' => $systemPrompt],
                    ['role' => 'user',   'content' => $request->message],
                ],
                'temperature' => 0.7,
                'max_tokens'  => 512, // Lebih pendek dari full chat
            ]);

            if (!$response->successful()) {
                Log::error('Groq Trial Chat Error: ' . $response->body());
                return response()->json([
                    'success' => false,
                    'error'   => 'AI sedang sibuk, silakan coba lagi.',
                ], 500);
            }

            $aiResponse = $response->json()['choices'][0]['message']['content'];

            // Simpan ke database (track usage)
            AiTrialChat::create([
                'user_id'  => $user->id,
                'ebook_id' => $ebookId,
                'message'  => $request->message,
                'response' => $aiResponse,
            ]);

            $newUsed      = $used + 1;
            $remaining    = self::MAX_TRIALS - $newUsed;

            return response()->json([
                'success'   => true,
                'response'  => $aiResponse,
                'used'      => $newUsed,
                'max'       => self::MAX_TRIALS,
                'remaining' => $remaining,
                'exhausted' => $remaining === 0,
            ]);

        } catch (\Exception $e) {
            Log::error('Trial Chat Exception: ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'error'   => 'Terjadi kesalahan, silakan coba lagi.',
            ], 500);
        }
    }

    /**
     * Riwayat trial chat user untuk buku ini
     * GET /api/v1/ebooks/{ebookId}/trial-chat/history
     */
    public function history(Request $request, int $ebookId): \Illuminate\Http\JsonResponse
    {
        $user    = $request->user();
        $history = AiTrialChat::where('user_id', $user->id)
            ->where('ebook_id', $ebookId)
            ->orderBy('created_at')
            ->get(['message', 'response', 'created_at']);

        $used = $history->count();

        return response()->json([
            'history'   => $history,
            'used'      => $used,
            'max'       => self::MAX_TRIALS,
            'remaining' => max(0, self::MAX_TRIALS - $used),
            'exhausted' => $used >= self::MAX_TRIALS,
        ]);
    }

    private function getTrialSystemPrompt(Ebook $book): string
    {
        $remaining = self::MAX_TRIALS; // Akan dikurangi di caller, ini hanya untuk prompt

        return <<<PROMPT
Anda adalah asisten AI untuk aplikasi EduVault yang membantu calon pembaca memahami gambaran isi buku digital.

Konteks Buku:
- Judul: {$book->title}
- Penulis: {$book->author}
- Deskripsi: {$book->description}

Instruksi:
1. Berikan gambaran umum tentang isi atau topik buku berdasarkan konteks di atas.
2. Jawab pertanyaan yang berkaitan dengan buku secara ringkas dan menarik.
3. Gunakan bahasa Indonesia yang baik, ramah, dan antusias.
4. Jika ditanya tentang detail konten yang sangat spesifik, sampaikan bahwa detail lengkapnya ada di dalam buku.
5. Dorong pembaca untuk membeli buku jika mereka terlihat tertarik — tapi dengan cara yang natural, tidak memaksa.
6. Batasi jawaban sekitar 2-3 paragraf agar ringkas.

Tujuan Anda adalah membantu calon pembaca memutuskan apakah buku ini sesuai dengan kebutuhan mereka.
PROMPT;
    }
}
