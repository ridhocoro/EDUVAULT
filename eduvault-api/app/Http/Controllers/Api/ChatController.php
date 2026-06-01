<?php
// app/Http/Controllers/Api/ChatController.php
//
// PERUBAHAN:
// 1. getSystemPrompt() sekarang membaca ISI PDF/EPUB buku, bukan hanya deskripsi
// 2. Tambah sendStream() untuk streaming response
// 3. Tambah history() untuk riwayat chat per buku
// 4. Tambah helper: extractBookContent(), extractPdf(), extractEpub(), cleanAndTruncate()

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AiChat;
use App\Models\Ebook;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;

class ChatController extends Controller
{
    // ─────────────────────────────────────────────────────────────────
    // POST /api/v1/books/{book_id}/chat
    //
    // Kirim pesan ke AI. Jawaban AI berdasarkan ISI PDF/EPUB buku.
    // ─────────────────────────────────────────────────────────────────
    public function send(Request $request, int $book_id): \Illuminate\Http\JsonResponse
    {
        $request->validate([
            'message' => 'required|string|max:4000',
        ]);

        $user    = $request->user();
        $message = $request->message;
        $book    = Ebook::findOrFail($book_id);

        // Ambil isi buku + buat system prompt
        $bookContent  = $this->extractBookContent($book);
        $systemPrompt = $this->getSystemPrompt($book, $bookContent);

        try {
            $response = Http::withHeaders([
                'Authorization' => 'Bearer ' . env('GROQ_API_KEY'),
                'Content-Type'  => 'application/json',
            ])->timeout(60)->post('https://api.groq.com/openai/v1/chat/completions', [
                'model'    => env('GROQ_MODEL', 'llama3-8b-8192'),
                'messages' => [
                    ['role' => 'system', 'content' => $systemPrompt],
                    ['role' => 'user',   'content' => $message],
                ],
                'temperature' => 0.7,
                'max_tokens'  => 1024,
            ]);

            if (!$response->successful()) {
                Log::error('Groq Chat Error: ' . $response->body());
                return response()->json([
                    'success' => false,
                    'error'   => 'Maaf, AI sedang sibuk. Silakan coba lagi.',
                ], 500);
            }

            $aiResponse = $response->json()['choices'][0]['message']['content'];

            // Simpan ke riwayat chat
            AiChat::create([
                'user_id'  => $user->id,
                'ebook_id' => $book_id,
                'message'  => $message,
                'response' => $aiResponse,
            ]);

            return response()->json([
                'success'  => true,
                'response' => $aiResponse,
            ]);

        } catch (\Exception $e) {
            Log::error('Chat Exception: ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'error'   => 'Terjadi kesalahan. Silakan coba lagi.',
            ], 500);
        }
    }

    // ─────────────────────────────────────────────────────────────────
    // POST /api/v1/books/{book_id}/chat/stream
    //
    // Streaming response dari AI (Server-Sent Events).
    // Jawaban dikirim bertahap (chunk per chunk) saat AI masih mengetik.
    // ─────────────────────────────────────────────────────────────────
    public function sendStream(Request $request, int $book_id): \Symfony\Component\HttpFoundation\StreamedResponse
    {
        $request->validate([
            'message' => 'required|string|max:4000',
        ]);

        $user    = $request->user();
        $message = $request->message;
        $book    = Ebook::findOrFail($book_id);

        $bookContent  = $this->extractBookContent($book);
        $systemPrompt = $this->getSystemPrompt($book, $bookContent);

        return response()->stream(function () use ($user, $book_id, $message, $systemPrompt) {
            $fullResponse = '';

            try {
                $ch = curl_init();
                curl_setopt_array($ch, [
                    CURLOPT_URL            => 'https://api.groq.com/openai/v1/chat/completions',
                    CURLOPT_POST           => true,
                    CURLOPT_HTTPHEADER     => [
                        'Authorization: Bearer ' . env('GROQ_API_KEY'),
                        'Content-Type: application/json',
                    ],
                    CURLOPT_POSTFIELDS     => json_encode([
                        'model'    => env('GROQ_MODEL', 'llama3-8b-8192'),
                        'messages' => [
                            ['role' => 'system', 'content' => $systemPrompt],
                            ['role' => 'user',   'content' => $message],
                        ],
                        'temperature' => 0.7,
                        'max_tokens'  => 1024,
                        'stream'      => true,
                    ]),
                    CURLOPT_WRITEFUNCTION  => function ($ch, $data) use (&$fullResponse) {
                        $lines = explode("\n", $data);
                        foreach ($lines as $line) {
                            $line = trim($line);
                            if (empty($line) || $line === 'data: [DONE]') continue;
                            if (str_starts_with($line, 'data: ')) {
                                $json  = substr($line, 6);
                                $chunk = json_decode($json, true);
                                $token = $chunk['choices'][0]['delta']['content'] ?? '';
                                if ($token !== '') {
                                    $fullResponse .= $token;
                                    echo "data: " . json_encode(['token' => $token]) . "\n\n";
                                    ob_flush();
                                    flush();
                                }
                            }
                        }
                        return strlen($data);
                    },
                    CURLOPT_TIMEOUT        => 60,
                    CURLOPT_RETURNTRANSFER => false,
                ]);

                curl_exec($ch);
                curl_close($ch);

                // Simpan ke riwayat setelah streaming selesai
                if (!empty($fullResponse)) {
                    AiChat::create([
                        'user_id'  => $user->id,
                        'ebook_id' => $book_id,
                        'message'  => $message,
                        'response' => $fullResponse,
                    ]);
                }

                echo "data: [DONE]\n\n";
                ob_flush();
                flush();

            } catch (\Exception $e) {
                Log::error('Chat Stream Exception: ' . $e->getMessage());
                echo "data: " . json_encode(['error' => 'Terjadi kesalahan.']) . "\n\n";
                ob_flush();
                flush();
            }
        }, 200, [
            'Content-Type'      => 'text/event-stream',
            'Cache-Control'     => 'no-cache',
            'X-Accel-Buffering' => 'no',
        ]);
    }

    // ─────────────────────────────────────────────────────────────────
    // GET /api/v1/books/{book_id}/chat/history
    //
    // Ambil riwayat chat user untuk buku ini.
    // ─────────────────────────────────────────────────────────────────
    public function history(Request $request, int $book_id): \Illuminate\Http\JsonResponse
    {
        $history = AiChat::where('user_id', $request->user()->id)
            ->where('ebook_id', $book_id)
            ->orderBy('created_at')
            ->get(['message', 'response', 'created_at']);

        return response()->json([
            'success' => true,
            'history' => $history,
        ]);
    }

    // ─── PRIVATE HELPERS ─────────────────────────────────────────────

    /**
     * Build system prompt.
     * Jika ada konten buku (dari PDF/EPUB), gunakan sebagai konteks utama.
     * Jika tidak ada file, fallback ke deskripsi.
     */
    private function getSystemPrompt(Ebook $book, ?string $bookContent): string
    {
        if ($bookContent) {
            // ── Mode lengkap: punya isi buku ─────────────────────
            return <<<PROMPT
Anda adalah asisten AI untuk aplikasi EduVault yang membantu pembaca memahami isi buku digital.

Informasi Buku:
- Judul  : {$book->title}
- Penulis: {$book->author}

─────────────────────────────────
ISI BUKU (GUNAKAN SEBAGAI SUMBER UTAMA JAWABAN):
─────────────────────────────────
{$bookContent}
─────────────────────────────────

Instruksi:
1. Jawab pertanyaan BERDASARKAN ISI BUKU di atas — bukan pengetahuan umum
2. Jika pertanyaan tidak berkaitan dengan isi buku ini, sampaikan dengan sopan
3. Kutip atau rujuk bagian spesifik dari buku jika relevan
4. Gunakan bahasa Indonesia yang baik dan mudah dipahami
5. Jika informasi tidak ada di isi buku yang tersedia, akui dengan jujur

Tujuan Anda adalah membantu pembaca memahami buku yang telah mereka beli secara mendalam.
PROMPT;
        }

        // ── Mode terbatas: tidak ada file PDF/EPUB ────────────────
        return <<<PROMPT
Anda adalah asisten AI untuk aplikasi EduVault yang membantu pembaca memahami isi buku digital.

Informasi Buku:
- Judul      : {$book->title}
- Penulis    : {$book->author}
- Deskripsi  : {$book->description}

Catatan: File buku belum tersedia di sistem. Jawab berdasarkan informasi di atas dan pengetahuan umum tentang topik buku ini.

Instruksi:
1. Jawab pertanyaan sebaik mungkin berdasarkan konteks buku di atas
2. Gunakan bahasa Indonesia yang baik dan mudah dipahami
3. Jika tidak tahu jawabannya, akui dengan jujur

Tujuan Anda adalah membantu pembaca mendapatkan pemahaman lebih baik tentang buku ini.
PROMPT;
    }

    /**
     * Ekstrak teks dari file PDF atau EPUB buku.
     * Menggunakan getRawOriginal() karena file_url di-hidden di model.
     */
    private function extractBookContent(Ebook $book): ?string
    {
        $filePath = $book->getRawOriginal('file_url');
        if (empty($filePath)) return null;

        $absolutePath = Storage::disk('public')->path($filePath);
        if (!file_exists($absolutePath)) {
            Log::warning("Chat: file tidak ditemukan — {$absolutePath}");
            return null;
        }

        $ext = strtolower(pathinfo($absolutePath, PATHINFO_EXTENSION));

        try {
            return match($ext) {
                'pdf'   => $this->extractPdf($absolutePath),
                'epub'  => $this->extractEpub($absolutePath),
                default => null,
            };
        } catch (\Exception $e) {
            Log::warning("Chat: gagal ekstrak konten — " . $e->getMessage());
            return null;
        }
    }

    /**
     * Ekstrak teks dari PDF.
     * Prioritas: smalot/pdfparser (sudah di composer.json) → exec pdftotext
     */
    private function extractPdf(string $path): ?string
    {
        if (class_exists(\Smalot\PdfParser\Parser::class)) {
            $parser = new \Smalot\PdfParser\Parser();
            $pdf    = $parser->parseFile($path);
            return $this->cleanAndTruncate($pdf->getText());
        }

        if (function_exists('exec')) {
            $output = [];
            exec("pdftotext " . escapeshellarg($path) . " - 2>/dev/null", $output);
            if (!empty($output)) {
                return $this->cleanAndTruncate(implode("\n", $output));
            }
        }

        Log::warning('Chat: jalankan composer require smalot/pdfparser');
        return null;
    }

    /**
     * Ekstrak teks dari EPUB (ZIP berisi HTML/XHTML).
     * Tidak butuh library tambahan — pakai ZipArchive built-in PHP.
     */
    private function extractEpub(string $path): ?string
    {
        $zip = new \ZipArchive();
        if ($zip->open($path) !== true) return null;

        $text = '';
        for ($i = 0; $i < $zip->numFiles; $i++) {
            $name = $zip->getNameIndex($i);
            if (!preg_match('/\.(html?|xhtml?)$/i', $name)) continue;

            $html = $zip->getFromIndex($i);
            if ($html === false) continue;

            $stripped  = strip_tags($html);
            $stripped  = html_entity_decode($stripped, ENT_QUOTES | ENT_HTML5, 'UTF-8');
            $stripped  = preg_replace('/\s+/', ' ', $stripped);
            $text     .= trim($stripped) . "\n\n";

            if (strlen($text) > 20000) break;
        }

        $zip->close();
        return $this->cleanAndTruncate($text);
    }

    /**
     * Bersihkan dan potong teks maks 12.000 karakter.
     *
     * Context window Groq llama3-8b-8192 = 8.192 token ≈ 30k karakter.
     * Limit 12k menyisakan ruang untuk system prompt + conversation + output.
     */
    private function cleanAndTruncate(string $text, int $maxChars = 12000): ?string
    {
        $text = preg_replace('/[ \t]+/', ' ', $text);
        $text = preg_replace('/\n{3,}/', "\n\n", $text);
        $text = trim($text);

        if (empty($text)) return null;

        if (strlen($text) > $maxChars) {
            $text      = substr($text, 0, $maxChars);
            $lastSpace = strrpos($text, ' ');
            if ($lastSpace > $maxChars * 0.9) {
                $text = substr($text, 0, $lastSpace);
            }
            $text .= "\n\n[... konten dipotong ...]";
        }

        return $text;
    }
}
