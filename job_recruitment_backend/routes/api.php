<?php

use App\Http\Controllers\Api\AdminController;
use App\Http\Controllers\Api\AdvertisementController;
use App\Http\Controllers\Api\ApplicationController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\ChatController;
use App\Http\Controllers\Api\DocumentController;
use App\Http\Controllers\Api\EmployerController;
use App\Http\Controllers\Api\EthiopianFeaturesController;
use App\Http\Controllers\Api\JobCategoryController;
use App\Http\Controllers\Api\JobController;
use App\Http\Controllers\Api\NotificationController;
use App\Http\Controllers\Api\ProfileController;
use App\Http\Controllers\Api\RecommendationController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| API Routes: v1
| Compliant with System Design Chapter 8 & Implementation Chapter 7
|--------------------------------------------------------------------------
*/

Route::prefix('v1')->group(function () {

    // Public Authentication Endpoints
    Route::post('auth/register', [AuthController::class, 'register']);
    Route::post('register', [AuthController::class, 'register']); // alias
    Route::post('auth/login', [AuthController::class, 'login']);
    Route::post('login', [AuthController::class, 'login']); // alias
    Route::post('auth/forgot-password', [AuthController::class, 'forgotPassword']);
    Route::post('password/forgot', [AuthController::class, 'forgotPassword']); // alias
    Route::post('auth/reset-password', [AuthController::class, 'resetPassword']);
    Route::post('password/reset', [AuthController::class, 'resetPassword']); // alias

    // Public Skills, Categories, Job Titles & Jobs Listing
    Route::get('skills', [ProfileController::class, 'listSkills']);
    Route::get('categories', [JobCategoryController::class, 'index']);
    Route::get('categories/{id}', [JobCategoryController::class, 'show'])->where('id', '[0-9]+');
    Route::get('job-titles', [JobCategoryController::class, 'titles']);
    Route::get('job-titles/suggestions', [JobCategoryController::class, 'suggestions']);
    Route::get('jobs', [JobController::class, 'index']);
    Route::get('jobs/search', [JobController::class, 'search']);
    Route::get('jobs/{id}', [JobController::class, 'show'])->where('id', '[0-9]+');

    // Public Advertisements
    Route::get('advertisements', [AdvertisementController::class, 'index']);
    Route::post('advertisements/{id}/impression', [AdvertisementController::class, 'recordImpression'])->where('id', '[0-9]+');
    Route::post('advertisements/{id}/click', [AdvertisementController::class, 'recordClick'])->where('id', '[0-9]+');

    // Document Download & View (supports Bearer token header or ?token= query parameter)
    Route::get('documents/{id}/download', [DocumentController::class, 'download'])->where('id', '[0-9]+');
    Route::get('documents/{id}/view', [DocumentController::class, 'download'])->where('id', '[0-9]+');

    // Ethiopian Context & Localization (Notice Board QR, Commute Radar, Salary Benchmarks)
    Route::get('jobs/{id}/poster', [EthiopianFeaturesController::class, 'noticeBoardPoster'])->where('id', '[0-9]+');
    Route::get('jobs/radar', [EthiopianFeaturesController::class, 'hyperlocalRadar']);
    Route::get('salary-benchmarks', [EthiopianFeaturesController::class, 'salaryBenchmarks']);

    // Authenticated Endpoints
    Route::middleware('auth:sanctum')->group(function () {

        // Current User & Logout
        Route::get('auth/user', [AuthController::class, 'user']);
        Route::get('user', [AuthController::class, 'user']); // alias
        Route::post('auth/logout', [AuthController::class, 'logout']);
        Route::post('logout', [AuthController::class, 'logout']); // alias

        // Job Seeker Profile Endpoints
        Route::get('profile', [ProfileController::class, 'show']);
        Route::put('profile', [ProfileController::class, 'update']);
        Route::post('profile', [ProfileController::class, 'update']); // alias for multipart/form-data
        Route::post('profile/photo', [ProfileController::class, 'uploadPhoto']);
        Route::get('profile/skills', [ProfileController::class, 'getSkills']);
        Route::post('profile/skills', [ProfileController::class, 'addSkill']);
        Route::delete('profile/skills/{id}', [ProfileController::class, 'removeSkill']);
        Route::get('profile/education', [ProfileController::class, 'getEducation']);
        Route::post('profile/education', [ProfileController::class, 'addEducation']);
        Route::delete('profile/education/{id}', [ProfileController::class, 'removeEducation']);
        Route::get('profile/experience', [ProfileController::class, 'getExperience']);
        Route::post('profile/experience', [ProfileController::class, 'addExperience']);
        Route::delete('profile/experience/{id}', [ProfileController::class, 'removeExperience']);

        // Employer Endpoints
        Route::post('employers', [EmployerController::class, 'registerOrganization']);
        Route::get('employers/profile', [EmployerController::class, 'showProfile']);
        Route::put('employers/profile', [EmployerController::class, 'updateProfile']);
        Route::post('employers/verification', [EmployerController::class, 'submitVerification']);
        Route::get('employers/verification', [EmployerController::class, 'getVerificationStatus']);
        Route::get('employers/jobs', [JobController::class, 'employerJobs']);

        // Job Management (Employer / Author)
        Route::post('jobs', [JobController::class, 'store']);
        Route::put('jobs/{id}', [JobController::class, 'update'])->where('id', '[0-9]+');
        Route::delete('jobs/{id}', [JobController::class, 'destroy'])->where('id', '[0-9]+');
        Route::get('jobs/{id}/applicants', [JobController::class, 'applicants'])->where('id', '[0-9]+');

        // Saved Jobs (Bookmarks)
        Route::post('jobs/{id}/save', [JobController::class, 'saveJob'])->where('id', '[0-9]+');
        Route::delete('jobs/{id}/save', [JobController::class, 'unsaveJob'])->where('id', '[0-9]+');
        Route::get('saved-jobs', [JobController::class, 'listSaved']);

        // Applications
        Route::post('jobs/{id}/applications', [ApplicationController::class, 'store'])->where('id', '[0-9]+');
        Route::post('jobs/{id}/apply', [ApplicationController::class, 'store'])->where('id', '[0-9]+'); // alias
        Route::get('applications', [ApplicationController::class, 'index']);
        Route::get('applications/{id}', [ApplicationController::class, 'show'])->where('id', '[0-9]+');
        Route::patch('applications/{id}/status', [ApplicationController::class, 'updateStatus'])->where('id', '[0-9]+');
        Route::post('applications/{id}/withdraw', [ApplicationController::class, 'withdraw'])->where('id', '[0-9]+');
        Route::post('applications/{id}/interview', [ApplicationController::class, 'scheduleInterview'])->where('id', '[0-9]+');
        Route::post('applications/{id}/interview/confirm', [ApplicationController::class, 'confirmInterview'])->where('id', '[0-9]+');
        Route::post('applications/{id}/interview/reschedule', [ApplicationController::class, 'rescheduleInterview'])->where('id', '[0-9]+');

        // Skills-Based Matching & Recommendations
        Route::get('recommendations/jobs', [RecommendationController::class, 'recommendations']);
        Route::get('jobs/{id}/match', [RecommendationController::class, 'matchDetails'])->where('id', '[0-9]+');

        // Documents
        Route::get('documents', [DocumentController::class, 'index']);
        Route::post('documents', [DocumentController::class, 'store']);
        Route::get('documents/{id}', [DocumentController::class, 'show'])->where('id', '[0-9]+');
        Route::delete('documents/{id}', [DocumentController::class, 'destroy'])->where('id', '[0-9]+');

        // Notifications
        Route::get('notifications', [NotificationController::class, 'index']);
        Route::patch('notifications/{id}/read', [NotificationController::class, 'markAsRead'])->where('id', '[0-9]+');
        Route::patch('notifications/read-all', [NotificationController::class, 'markAllAsRead']);

        // Community & Friends Group Chat
        Route::get('chat/groups', [ChatController::class, 'index']);
        Route::post('chat/groups', [ChatController::class, 'store']);
        Route::get('chat/groups/{id}', [ChatController::class, 'show'])->where('id', '[0-9]+');
        Route::post('chat/groups/{id}/join', [ChatController::class, 'join'])->where('id', '[0-9]+');
        Route::post('chat/groups/{id}/leave', [ChatController::class, 'leave'])->where('id', '[0-9]+');
        Route::get('chat/groups/{id}/messages', [ChatController::class, 'messages'])->where('id', '[0-9]+');
        Route::post('chat/groups/{id}/messages', [ChatController::class, 'sendMessage'])->where('id', '[0-9]+');

        // Reports
        Route::post('reports', [AdminController::class, 'submitReport']);

        // Skills Verification Quizzes & Badges
        Route::get('quizzes', [EthiopianFeaturesController::class, 'listQuizzes']);
        Route::get('quizzes/{id}', [EthiopianFeaturesController::class, 'showQuiz'])->where('id', '[0-9]+');
        Route::post('quizzes/{id}/submit', [EthiopianFeaturesController::class, 'submitQuiz'])->where('id', '[0-9]+');
        Route::get('user/badges', [EthiopianFeaturesController::class, 'userBadges']);

        // Recruiter Candidate Dossier Export
        Route::post('jobs/{id}/export-candidates', [EthiopianFeaturesController::class, 'exportCandidatePack'])->where('id', '[0-9]+');

        // Administrator Routes (Protected with Role Middleware RBAC)
        Route::prefix('admin')->middleware('role:administrator')->group(function () {
            Route::get('users', [AdminController::class, 'users']);
            Route::patch('users/{id}/status', [AdminController::class, 'updateUserStatus'])->where('id', '[0-9]+');
            Route::get('verifications', [AdminController::class, 'verifications']);
            Route::patch('verifications/{id}', [AdminController::class, 'reviewVerification'])->where('id', '[0-9]+');
            Route::get('statistics', [AdminController::class, 'statistics']);
            Route::get('reports', [AdminController::class, 'reports']);
        });

        // Advertisements & Promotional Campaigns (Admin & Employer Management)
        Route::prefix('admin')->middleware('role:administrator,employer')->group(function () {
            Route::get('advertisements', [AdvertisementController::class, 'adminIndex']);
            Route::post('advertisements', [AdvertisementController::class, 'adminStore']);
            Route::get('advertisements/analytics', [AdvertisementController::class, 'adminAnalytics']);
            Route::get('advertisements/{id}', [AdvertisementController::class, 'adminShow'])->where('id', '[0-9]+');
            Route::put('advertisements/{id}', [AdvertisementController::class, 'adminUpdate'])->where('id', '[0-9]+');
            Route::patch('advertisements/{id}/status', [AdvertisementController::class, 'adminToggleStatus'])->where('id', '[0-9]+');
            Route::delete('advertisements/{id}', [AdvertisementController::class, 'adminDestroy'])->where('id', '[0-9]+');
        });
    });
});
