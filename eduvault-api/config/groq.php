<?php
// config/groq.php

return [
    'api_key' => env('GROQ_API_KEY', ''),
    'model' => env('GROQ_MODEL', 'llama3-8b-8192'),
];