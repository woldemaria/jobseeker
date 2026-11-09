<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Third Party Services
    |--------------------------------------------------------------------------
    |
    | This file is for storing the credentials for third party services such
    | as Resend, Postmark, AWS, and more. This file provides the de facto
    | location for this type of information, allowing packages to have
    | a conventional file to locate the various service credentials.
    |
    */

    'postmark' => [
        'key' => env('POSTMARK_API_KEY'),
    ],

    'resend' => [
        'key' => env('RESEND_API_KEY'),
    ],

    'ses' => [
        'key' => env('AWS_ACCESS_KEY_ID'),
        'secret' => env('AWS_SECRET_ACCESS_KEY'),
        'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    ],

    'slack' => [
        'notifications' => [
            'bot_user_oauth_token' => env('SLACK_BOT_USER_OAUTH_TOKEN'),
            'channel' => env('SLACK_BOT_USER_DEFAULT_CHANNEL'),
        ],
    ],

    'chapa' => [
        'public_key' => env('CHAPA_PUBLIC_KEY'),
        'secret_key' => env('CHAPA_SECRET_KEY'),
        'webhook_secret' => env('CHAPA_WEBHOOK_SECRET'),
        'base_url' => env('CHAPA_BASE_URL', 'https://api.chapa.global/v2'),
        'mode' => env('CHAPA_MODE', 'sandbox'),
    ],

    'telebirr' => [
        'app_id' => env('TELEBIRR_APP_ID'),
        'app_key' => env('TELEBIRR_APP_KEY'),
        'short_code' => env('TELEBIRR_SHORT_CODE'),
        'public_key' => env('TELEBIRR_PUBLIC_KEY'),
        'private_key' => env('TELEBIRR_PRIVATE_KEY'),
    ],

    'cbe_birr' => [
        'till_number' => env('CBE_BIRR_TILL_NUMBER'),
        'app_id' => env('CBE_BIRR_APP_ID'),
        'app_secret' => env('CBE_BIRR_APP_SECRET'),
        'public_key' => env('CBE_BIRR_PUBLIC_KEY'),
    ],

];
