<?php
// app/Http/Controllers/Api/QuizController.php
//
// PERUBAHAN SISTEM:
// - Admin TIDAK lagi mengelola quiz
// - User generate quiz sendiri dari isi PDF/EPUB buku yang mereka miliki
// - User bisa pilih: 'full' (seluruh buku) atau 'chapter' (per bab)
// - Semua routes quiz dipindah ke bawah middleware verify.book.ownership
// - Soal dibuat dari konten PDF/EPUB, bukan dari deskripsi buku

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Ebook;
use App\Models\Quiz;
use App\Models\QuizAttempt;
use App\Models\QuizQuestion;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;

class QuizController extends Controller
{
    // ─────────────────────────────────────────────────────────────────
    // GET /api/v1/library/{book_id}/quiz
    //
    // Ambil semua quiz yang pernah dibuat user untuk buku ini.
    // Juga mengembalikan has_file agar Flutter bisa tampilkan info
    // jika buku tidak punya file PDF/EPUB.
    // ─────────────────────────────────────────────────────────────────
    public function index(Request $request, int $book_id): \Illuminate\Http\JsonResponse
    {
        $userId = $request->user()->id;

        $quizzes = Quiz::where('ebook_id', $book_id)
            ->where('user_id', $userId)
            ->where('status', 'published')
            ->with('questions')
            ->orderBy('quiz_type')
            ->orderBy('chapter_number')
            ->orderByDesc('created_at')
            ->get();

        $result = $quizzes->map(function (Quiz $quiz) use ($userId) {
            $best = QuizAttempt::where('user_id', $userId)
                ->where('quiz_id', $quiz->id)
                ->orderByDesc('score')
                ->first();

            return [
                'id'             => $quiz->id,
                'title'          => $quiz->title,
                'quiz_type'      => $quiz->quiz_type,
                'chapter_number' => $quiz->chapter_number,
                'chapter_title'  => $quiz->chapter_title,
                'question_count' => $quiz->questions->count(),
                'questions'      => $quiz->questions->map(fn($q) => [
                    'id'       => $q->id,
                    'order'    => $q->order,
                    'question' => $q->question,
                    'option_a' => $q->option_a,
                    'option_b' => $q->option_b,
                    'option_c' => $q->option_c,
                    'option_d' => $q->option_d,
                    // correct_answer & explanation TIDAK dikirim di sini
                ]),
                'best_attempt'   => $best ? [
                    'score'      => $best->score,
                    'total'      => $best->total,
                    'percentage' => $best->percentage,
                    'taken_at'   => $best->created_at,
                ] : null,
                'created_at'     => $quiz->created_at,
            ];
        });

        $book    = Ebook::find($book_id);
        $hasFile = $book && !empty($book->getRawOriginal('file_url'));

        return response()->json([
            'quizzes'  => $result,
            'has_file' => $hasFile,
        ]);
    }

    // ─────────────────────────────────────────────────────────────────
    // POST /api/v1/library/{book_id}/quiz/generate
    //
    // User generate quiz baru dari isi PDF/EPUB.
    // Body:
    //   question_count  int     3–20  (default 10)
    //   quiz_type       string  'full' | 'chapter'  (default 'full')
    //   chapter_number  int     wajib jika quiz_type = 'chapter'
    //   chapter_title   string  opsional
    // ─────────────────────────────────────────────────────────────────
    public function generate(Request $request, int $book_id): \Illuminate\Http\JsonResponse
    {
        $request->validate([
            'question_count' => 'nullable|integer|min:3|max:20',
            'quiz_type'      => 'nullable|in:full,chapter',
            'chapter_number' => 'required_if:quiz_type,chapter|nullable|integer|min:1',
            'chapter_title'  => 'nullable|string|max:255',
        ]);

        $book         = Ebook::findOrFail($book_id);
        $userId       = $request->user()->id;
        $count        = $request->input('question_count', 10);
        $quizType     = $request->input('quiz_type', 'full');
        $chapterNo    = $request->input('chapter_number');
        $chapterTitle = $request->input('chapter_title');

        if ($quizType === 'chapter' && !$chapterNo) {
            return response()->json([
                'error' => 'chapter_number wajib diisi untuk quiz per bab.',
            ], 422);
        }

        // Ekstrak isi buku dari PDF/EPUB
        $bookContent = $this->extractBookContent($book);

        if (!$bookContent) {
            return response()->json([
                'error' => 'Buku ini belum memiliki file PDF/EPUB. Hubungi admin untuk upload file terlebih dahulu.',
            ], 422);
        }

        // Build prompt dan kirim ke Groq
        $prompt = $this->buildPrompt(
            $book, $count, $quizType, $chapterNo, $chapterTitle, $bookContent
        );

        try {
            $response = Http::withHeaders([
                'Authorization' => 'Bearer ' . env('GROQ_API_KEY'),
                'Content-Type'  => 'application/json',
            ])->timeout(120)->post('https://api.groq.com/openai/v1/chat/completions', [
                'model'    => env('GROQ_MODEL', 'llama3-8b-8192'),
                'messages' => [
                    [
                        'role'    => 'system',
                        'content' => 'Kamu adalah generator soal quiz akademik. Selalu balas HANYA dalam format JSON valid tanpa teks tambahan apapun.',
                    ],
                    ['role' => 'user', 'content' => $prompt],
                ],
                'temperature' => 0.6,
                'max_tokens'  => 4096,
            ]);

            if (!$response->successful()) {
                Log::error('Quiz Generate Error: ' . $response->body());
                return response()->json(['error' => 'AI gagal membuat soal. Coba lagi.'], 500);
            }

            $content = $response->json()['choices'][0]['message']['content'];
            $content = preg_replace('/```json\s*/i', '', $content);
            $content = preg_replace('/```\s*/',      '', $content);
            $content = trim($content);

            $data = json_decode($content, true);
            if (!$data || empty($data['questions'])) {
                Log::error('Invalid AI quiz response: ' . $content);
                return response()->json(['error' => 'Format respons AI tidak valid. Coba lagi.'], 500);
            }

            // Buat judul otomatis
            $title = $quizType === 'chapter'
                ? 'Quiz Bab ' . $chapterNo . ($chapterTitle ? ": {$chapterTitle}" : '') . " — {$book->title}"
                : "Quiz: {$book->title}";

            // Simpan quiz (langsung published, milik user)
            $quiz = Quiz::create([
                'ebook_id'       => $book_id,
                'user_id'        => $userId,
                'title'          => $title,
                'status'         => 'published',
                'quiz_type'      => $quizType,
                'chapter_number' => $quizType === 'chapter' ? $chapterNo    : null,
                'chapter_title'  => $quizType === 'chapter' ? $chapterTitle : null,
            ]);

            foreach ($data['questions'] as $i => $q) {
                QuizQuestion::create([
                    'quiz_id'        => $quiz->id,
                    'order'          => $i + 1,
                    'question'       => $q['question'],
                    'option_a'       => $q['option_a'],
                    'option_b'       => $q['option_b'],
                    'option_c'       => $q['option_c'],
                    'option_d'       => $q['option_d'],
                    'correct_answer' => strtolower($q['correct_answer']),
                    'explanation'    => $q['explanation'] ?? null,
                ]);
            }

            $quiz->load('questions');

            return response()->json([
                'success' => true,
                'quiz'    => [
                    'id'             => $quiz->id,
                    'title'          => $quiz->title,
                    'quiz_type'      => $quiz->quiz_type,
                    'chapter_number' => $quiz->chapter_number,
                    'chapter_title'  => $quiz->chapter_title,
                    'question_count' => $quiz->questions->count(),
                    'questions'      => $quiz->questions->map(fn($q) => [
                        'id'       => $q->id,
                        'order'    => $q->order,
                        'question' => $q->question,
                        'option_a' => $q->option_a,
                        'option_b' => $q->option_b,
                        'option_c' => $q->option_c,
                        'option_d' => $q->option_d,
                    ]),
                ],
            ]);

        } catch (\Exception $e) {
            Log::error('Quiz Generate Exception: ' . $e->getMessage());
            return response()->json(['error' => 'Terjadi kesalahan: ' . $e->getMessage()], 500);
        }
    }

    // ─────────────────────────────────────────────────────────────────
    // POST /api/v1/library/{book_id}/quiz/submit
    //
    // Submit jawaban dan hitung skor.
    // ─────────────────────────────────────────────────────────────────
    public function submit(Request $request, int $book_id): \Illuminate\Http\JsonResponse
    {
        $request->validate([
            'quiz_id'               => 'required|integer|exists:quizzes,id',
            'answers'               => 'required|array',
            'answers.*.question_id' => 'required|integer|exists:quiz_questions,id',
            'answers.*.answer'      => 'required|in:a,b,c,d',
            'duration_seconds'      => 'nullable|integer|min:0',
        ]);

        $userId = $request->user()->id;
        $quiz   = Quiz::findOrFail($request->quiz_id);

        // Pastikan quiz milik user ini dan untuk buku yang benar
        if ($quiz->ebook_id !== $book_id || $quiz->user_id !== $userId) {
            return response()->json(['error' => 'Quiz tidak valid.'], 422);
        }

        $questions = QuizQuestion::where('quiz_id', $quiz->id)->get()->keyBy('id');

        $results = [];
        $correct = 0;

        foreach ($request->answers as $answer) {
            $question = $questions->get($answer['question_id']);
            if (!$question) continue;

            $isCorrect = $question->correct_answer === $answer['answer'];
            if ($isCorrect) $correct++;

            $results[] = [
                'question_id'    => $question->id,
                'your_answer'    => $answer['answer'],
                'correct_answer' => $question->correct_answer,
                'is_correct'     => $isCorrect,
                'explanation'    => $question->explanation,
            ];
        }

        $total   = $questions->count();
        $attempt = QuizAttempt::create([
            'user_id'          => $userId,
            'quiz_id'          => $quiz->id,
            'score'            => $correct,
            'total'            => $total,
            'duration_seconds' => $request->duration_seconds,
        ]);

        return response()->json([
            'success'    => true,
            'score'      => $correct,
            'total'      => $total,
            'percentage' => $attempt->percentage,
            'results'    => $results,
        ]);
    }

    // ─────────────────────────────────────────────────────────────────
    // DELETE /api/v1/library/{book_id}/quiz/{quizId}
    //
    // Hapus quiz milik user sendiri.
    // ─────────────────────────────────────────────────────────────────
    public function destroy(Request $request, int $book_id, int $quizId): \Illuminate\Http\JsonResponse
    {
        $quiz = Quiz::where('id', $quizId)
            ->where('ebook_id', $book_id)
            ->where('user_id', $request->user()->id)
            ->firstOrFail();

        $quiz->delete();

        return response()->json(['success' => true]);
    }

    // ─── PRIVATE HELPERS ─────────────────────────────────────────────

    /**
     * Ekstrak teks dari file PDF atau EPUB.
     * Return null jika tidak ada file atau gagal ekstrak.
     */
    private function extractBookContent(Ebook $book): ?string
    {
        $filePath = $book->getRawOriginal('file_url');
        if (empty($filePath)) return null;

        $absolutePath = Storage::disk('public')->path($filePath);
        if (!file_exists($absolutePath)) {
            Log::warning("Quiz: file tidak ditemukan — {$absolutePath}");
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
            Log::warning("Quiz: gagal ekstrak konten — " . $e->getMessage());
            return null;
        }
    }

    /**
     * Ekstrak teks dari PDF.
     * Prioritas: smalot/pdfparser → exec pdftotext (fallback).
     *
     * Install library: composer require smalot/pdfparser
     */
    private function extractPdf(string $path): ?string
    {
        // Prioritas 1: smalot/pdfparser
        if (class_exists(\Smalot\PdfParser\Parser::class)) {
            $parser = new \Smalot\PdfParser\Parser();
            $pdf    = $parser->parseFile($path);
            return $this->cleanAndTruncate($pdf->getText());
        }

        // Prioritas 2: pdftotext (tersedia di server Linux dengan poppler-utils)
        if (function_exists('exec')) {
            $output = [];
            exec("pdftotext " . escapeshellarg($path) . " - 2>/dev/null", $output);
            if (!empty($output)) {
                return $this->cleanAndTruncate(implode("\n", $output));
            }
        }

        Log::warning('Quiz: install smalot/pdfparser dengan: composer require smalot/pdfparser');
        return null;
    }

    /**
     * Ekstrak teks dari EPUB (format ZIP berisi HTML/XHTML).
     * Tidak memerlukan library tambahan — pakai ZipArchive built-in PHP.
     */
    private function extractEpub(string $path): ?string
    {
        $zip = new \ZipArchive();
        if ($zip->open($path) !== true) return null;

        $text = '';

        for ($i = 0; $i < $zip->numFiles; $i++) {
            $name = $zip->getNameIndex($i);
            // Hanya proses file HTML/XHTML (bab isi buku)
            if (!preg_match('/\.(html?|xhtml?)$/i', $name)) continue;

            $html = $zip->getFromIndex($i);
            if ($html === false) continue;

            $stripped  = strip_tags($html);
            $stripped  = html_entity_decode($stripped, ENT_QUOTES | ENT_HTML5, 'UTF-8');
            $stripped  = preg_replace('/\s+/', ' ', $stripped);
            $text     .= trim($stripped) . "\n\n";

            if (strlen($text) > 20000) break; // cukup teks
        }

        $zip->close();
        return $this->cleanAndTruncate($text);
    }

    /**
     * Bersihkan whitespace dan potong teks maks 12.000 karakter.
     * Context window Groq llama3-8b-8192 = 8192 token ≈ 30k karakter.
     * Limit 12k menyisakan ruang untuk instruksi + output JSON soal.
     */
    private function cleanAndTruncate(string $text, int $maxChars = 12000): ?string
    {
        $text = preg_replace('/[ \t]+/', ' ', $text);
        $text = preg_replace('/\n{3,}/', "\n\n", $text);
        $text = trim($text);

        if (empty($text)) return null;

        if (strlen($text) > $maxChars) {
            $text       = substr($text, 0, $maxChars);
            $lastSpace  = strrpos($text, ' ');
            if ($lastSpace > $maxChars * 0.9) {
                $text = substr($text, 0, $lastSpace);
            }
            $text .= "\n\n[... konten dipotong ...]";
        }

        return $text;
    }

    /**
     * Build prompt berdasarkan isi buku dan pilihan user.
     */
    private function buildPrompt(
        Ebook   $book,
        int     $count,
        string  $quizType,
        ?int    $chapterNo,
        ?string $chapterTitle,
        string  $bookContent
    ): string {
        $scope = $quizType === 'chapter'
            ? "Bab {$chapterNo}" . ($chapterTitle ? " ({$chapterTitle})" : '')
            : 'keseluruhan buku';

        $focusNote = $quizType === 'chapter'
            ? "PENTING: Buat soal HANYA dari materi {$scope}. Jangan buat soal dari bab lain."
            : 'Buat soal yang mencakup topik-topik utama dari seluruh isi buku secara merata.';

        return <<<PROMPT
Buat {$count} soal pilihan ganda untuk quiz {$scope} dari buku berikut:

Judul  : {$book->title}
Penulis: {$book->author}

─────────────────────────────────
ISI BUKU (GUNAKAN SEBAGAI SUMBER UTAMA SOAL — BUKAN PENGETAHUAN UMUM):
─────────────────────────────────
{$bookContent}
─────────────────────────────────

{$focusNote}

KETENTUAN SOAL:
- Soal WAJIB berdasarkan isi buku di atas
- Variasikan tingkat kesulitan: mudah, sedang, sulit
- Setiap soal punya 4 pilihan (a, b, c, d) dengan 1 jawaban benar
- Sertakan penjelasan singkat untuk setiap jawaban (explanation)
- Soal, pilihan, dan penjelasan HARUS dalam bahasa Indonesia

Balas HANYA dengan JSON berikut (tanpa teks atau markdown lain):
{
  "questions": [
    {
      "question": "Pertanyaan di sini?",
      "option_a": "Pilihan A",
      "option_b": "Pilihan B",
      "option_c": "Pilihan C",
      "option_d": "Pilihan D",
      "correct_answer": "a",
      "explanation": "Penjelasan singkat kenapa A benar."
    }
  ]
}
PROMPT;
    }
}
