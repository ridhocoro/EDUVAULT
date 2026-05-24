<?php
// app/Http/Controllers/Api/QuizController.php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Ebook;
use App\Models\Quiz;
use App\Models\QuizAttempt;
use App\Models\QuizQuestion;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class QuizController extends Controller
{
    // ─── USER ENDPOINTS ───────────────────────────────────────────────

    /**
     * Ambil quiz yang sudah published untuk sebuah buku
     * GET /api/v1/library/{ebookId}/quiz
     * (Middleware verify.book.ownership memastikan user sudah beli buku)
     */
    public function show(Request $request, int $ebookId): \Illuminate\Http\JsonResponse
    {
        $quiz = Quiz::where('ebook_id', $ebookId)
            ->where('status', 'published')
            ->with('questions')
            ->first();

        if (!$quiz) {
            return response()->json(['available' => false, 'quiz' => null]);
        }

        // Ambil best score user
        $bestAttempt = QuizAttempt::where('user_id', $request->user()->id)
            ->where('quiz_id', $quiz->id)
            ->orderByDesc('score')
            ->first();

        return response()->json([
            'available'    => true,
            'quiz'         => [
                'id'            => $quiz->id,
                'title'         => $quiz->title,
                'question_count' => $quiz->questions->count(),
                'questions'     => $quiz->questions->map(fn($q) => [
                    'id'             => $q->id,
                    'order'          => $q->order,
                    'question'       => $q->question,
                    'option_a'       => $q->option_a,
                    'option_b'       => $q->option_b,
                    'option_c'       => $q->option_c,
                    'option_d'       => $q->option_d,
                    // correct_answer & explanation TIDAK dikirim — dikirim hanya saat submit
                ]),
            ],
            'best_attempt' => $bestAttempt ? [
                'score'      => $bestAttempt->score,
                'total'      => $bestAttempt->total,
                'percentage' => $bestAttempt->percentage,
                'taken_at'   => $bestAttempt->created_at,
            ] : null,
        ]);
    }

    /**
     * Submit jawaban quiz dan hitung skor
     * POST /api/v1/library/{ebookId}/quiz/submit
     */
    public function submit(Request $request, int $ebookId): \Illuminate\Http\JsonResponse
    {
        $request->validate([
            'quiz_id'          => 'required|integer|exists:quizzes,id',
            'answers'          => 'required|array',
            'answers.*.question_id' => 'required|integer|exists:quiz_questions,id',
            'answers.*.answer' => 'required|in:a,b,c,d',
            'duration_seconds' => 'nullable|integer|min:0',
        ]);

        $quiz = Quiz::findOrFail($request->quiz_id);

        // Pastikan quiz milik buku yang benar & sudah published
        if ($quiz->ebook_id !== $ebookId || $quiz->status !== 'published') {
            return response()->json(['error' => 'Quiz tidak valid.'], 422);
        }

        $questions = QuizQuestion::where('quiz_id', $quiz->id)
            ->get()
            ->keyBy('id');

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

        $total = $questions->count();

        // Simpan attempt
        $attempt = QuizAttempt::create([
            'user_id'          => $request->user()->id,
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

    // ─── ADMIN ENDPOINTS ──────────────────────────────────────────────

    /**
     * Generate quiz dengan AI untuk sebuah buku
     * POST /api/v1/admin/ebooks/{ebookId}/quiz/generate
     */
    public function generate(Request $request, int $ebookId): \Illuminate\Http\JsonResponse
    {
        $request->validate([
            'question_count' => 'nullable|integer|min:3|max:20',
        ]);

        $book = Ebook::findOrFail($ebookId);
        $count = $request->input('question_count', 10);

        $prompt = $this->buildGenerationPrompt($book, $count);

        try {
            $response = Http::withHeaders([
                'Authorization' => 'Bearer ' . env('GROQ_API_KEY'),
                'Content-Type'  => 'application/json',
            ])->timeout(120)->post('https://api.groq.com/openai/v1/chat/completions', [
                'model' => env('GROQ_MODEL', 'llama3-8b-8192'),
                'messages' => [
                    ['role' => 'system', 'content' => 'Kamu adalah generator soal quiz akademik. Selalu balas HANYA dalam format JSON valid tanpa teks tambahan apapun.'],
                    ['role' => 'user',   'content' => $prompt],
                ],
                'temperature' => 0.6,
                'max_tokens'  => 4096,
            ]);

            if (!$response->successful()) {
                Log::error('Quiz Generation Error: ' . $response->body());
                return response()->json(['error' => 'AI gagal generate soal.'], 500);
            }

            $content = $response->json()['choices'][0]['message']['content'];

            // Bersihkan markdown code block jika ada
            $content = preg_replace('/```json\s*/i', '', $content);
            $content = preg_replace('/```\s*/', '', $content);
            $content = trim($content);

            $data = json_decode($content, true);
            if (!$data || !isset($data['questions'])) {
                Log::error('Invalid AI response format: ' . $content);
                return response()->json(['error' => 'Format respons AI tidak valid.'], 500);
            }

            // Hapus quiz lama jika ada (draft), buat yang baru
            Quiz::where('ebook_id', $ebookId)->where('status', 'draft')->delete();

            $quiz = Quiz::create([
                'ebook_id' => $ebookId,
                'title'    => "Quiz: {$book->title}",
                'status'   => 'draft',
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

            return response()->json([
                'success' => true,
                'quiz'    => $quiz->load('questions'),
                'message' => "Berhasil generate {$quiz->questions->count()} soal. Status: draft.",
            ]);

        } catch (\Exception $e) {
            Log::error('Quiz Generation Exception: ' . $e->getMessage());
            return response()->json(['error' => 'Terjadi kesalahan: ' . $e->getMessage()], 500);
        }
    }

    /**
     * Ambil quiz (draft/published) untuk admin edit
     * GET /api/v1/admin/ebooks/{ebookId}/quiz
     */
    public function adminShow(int $ebookId): \Illuminate\Http\JsonResponse
    {
        $quiz = Quiz::where('ebook_id', $ebookId)
            ->with('questions')
            ->latest()
            ->first();

        return response()->json([
            'quiz' => $quiz,
        ]);
    }

    /**
     * Update soal tertentu
     * PUT /api/v1/admin/quiz-questions/{questionId}
     */
    public function updateQuestion(Request $request, int $questionId): \Illuminate\Http\JsonResponse
    {
        $request->validate([
            'question'       => 'required|string',
            'option_a'       => 'required|string',
            'option_b'       => 'required|string',
            'option_c'       => 'required|string',
            'option_d'       => 'required|string',
            'correct_answer' => 'required|in:a,b,c,d',
            'explanation'    => 'nullable|string',
        ]);

        $question = QuizQuestion::findOrFail($questionId);
        $question->update($request->only([
            'question', 'option_a', 'option_b', 'option_c', 'option_d',
            'correct_answer', 'explanation',
        ]));

        return response()->json(['success' => true, 'question' => $question]);
    }

    /**
     * Publish quiz (dari draft → published)
     * PATCH /api/v1/admin/quizzes/{quizId}/publish
     */
    public function publish(int $quizId): \Illuminate\Http\JsonResponse
    {
        $quiz = Quiz::findOrFail($quizId);

        if ($quiz->questions()->count() === 0) {
            return response()->json(['error' => 'Quiz tidak boleh kosong.'], 422);
        }

        // Unpublish quiz lain untuk buku yang sama
        Quiz::where('ebook_id', $quiz->ebook_id)
            ->where('id', '!=', $quiz->id)
            ->update(['status' => 'draft']);

        $quiz->update(['status' => 'published']);

        return response()->json(['success' => true, 'quiz' => $quiz]);
    }

    /**
     * Hapus quiz
     * DELETE /api/v1/admin/quizzes/{quizId}
     */
    public function destroy(int $quizId): \Illuminate\Http\JsonResponse
    {
        $quiz = Quiz::findOrFail($quizId);
        $quiz->delete();

        return response()->json(['success' => true]);
    }

    // ─── PRIVATE ──────────────────────────────────────────────────────

    private function buildGenerationPrompt(Ebook $book, int $count): string
    {
        return <<<PROMPT
Buat {$count} soal pilihan ganda untuk quiz buku berikut:

Judul: {$book->title}
Penulis: {$book->author}
Deskripsi: {$book->description}

Persyaratan:
- Soal harus mencakup pemahaman konsep, analisis, dan aplikasi
- Tingkat kesulitan bervariasi (mudah, sedang, sulit)
- Setiap soal memiliki 4 pilihan (a, b, c, d) dengan 1 jawaban benar
- Berikan penjelasan singkat kenapa jawaban itu benar (explanation)
- Soal dan pilihan dalam bahasa Indonesia

Balas HANYA dengan JSON ini (tanpa teks lain):
{
  "questions": [
    {
      "question": "Pertanyaan lengkap di sini?",
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
