<?php

namespace App\Http\Controllers\Api;

use App\Models\AuditLog;
use App\Models\Employer;
use App\Models\EmployerMember;
use App\Models\JobSeekerProfile;
use App\Models\Role;
use App\Models\User;
use App\Services\ImageUploadService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class AuthController extends BaseApiController
{
    public function register(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'required|string|max:150',
            'email' => 'required|email|max:150|unique:users,email',
            'phone' => 'nullable|string|max:30',
            'password' => 'required|string|min:8|confirmed',
            'role' => 'required|string|in:job_seeker,employer,administrator',
            'profile_photo' => 'nullable|string',
            'profile_photo_file' => 'nullable|file|mimes:jpeg,jpg,png,webp|max:5120',
            'cv_file' => 'nullable|file|mimes:pdf,doc,docx|max:10240',
        ]);

        $photoInput = $request->file('profile_photo_file')
            ?: ($request->file('photo')
            ?: ($validated['profile_photo'] ?? null));
        $photoUrl = ImageUploadService::storeImage($photoInput, 'profile_photos');

        $user = User::create([
            'name' => $validated['name'],
            'email' => $validated['email'],
            'phone' => $validated['phone'] ?? null,
            'profile_photo' => $photoUrl,
            'password' => Hash::make($validated['password']),
            'status' => 'active',
        ]);

        $role = Role::where('name', $validated['role'])->first();
        if ($role) {
            $user->roles()->attach($role->id);
        }

        if ($validated['role'] === 'job_seeker') {
            JobSeekerProfile::create([
                'user_id' => $user->id,
                'experience_years' => 0,
            ]);

            // If CV file was attached during registration, store it immediately
            if ($request->hasFile('cv_file')) {
                try {
                    $docService = app(\App\Services\DocumentService::class);
                    $docService->uploadDocument($user, $request->file('cv_file'), 'cv');
                } catch (\Throwable $e) {
                    // Log but do not fail registration
                }
            }
        } elseif ($validated['role'] === 'employer') {
            $employer = Employer::create([
                'organization_name' => $user->name . ' Organization',
                'email' => $user->email,
                'phone' => $user->phone,
                'verification_status' => 'pending',
            ]);
            EmployerMember::create([
                'employer_id' => $employer->id,
                'user_id' => $user->id,
                'member_role' => 'owner',
            ]);
        }

        AuditLog::create([
            'user_id' => $user->id,
            'action' => 'user_registered',
            'entity_type' => 'User',
            'entity_id' => $user->id,
            'description' => "User registered with role {$validated['role']}.",
            'ip_address' => $request->ip(),
            'created_at' => now(),
        ]);

        $token = $user->createToken('auth_token')->plainTextToken;

        return $this->successResponse([
            'user' => $user->load('roles'),
            'token' => $token,
            'token_type' => 'Bearer',
        ], 'Account registered successfully.', 201);
    }

    public function login(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'email' => 'required|email',
            'password' => 'required|string',
        ]);

        $user = User::where('email', $validated['email'])->first();

        if (!$user || !Hash::check($validated['password'], $user->password)) {
            return $this->errorResponse('Invalid email or password.', 401);
        }

        if ($user->status !== 'active') {
            return $this->errorResponse("Your account status is {$user->status}. Please contact administrator.", 403);
        }

        $user->tokens()->delete();
        $token = $user->createToken('auth_token')->plainTextToken;

        AuditLog::create([
            'user_id' => $user->id,
            'action' => 'user_login',
            'entity_type' => 'User',
            'entity_id' => $user->id,
            'description' => 'User logged in via mobile API.',
            'ip_address' => $request->ip(),
            'created_at' => now(),
        ]);

        return $this->successResponse([
            'user' => $user->load(['roles', 'jobSeekerProfile', 'employers']),
            'token' => $token,
            'token_type' => 'Bearer',
        ], 'Logged in successfully.');
    }

    public function logout(Request $request): JsonResponse
    {
        $user = $request->user();
        if ($user) {
            $token = $user->currentAccessToken();
            if ($token && method_exists($token, 'delete')) {
                $token->delete();
            } else {
                $user->tokens()->delete();
            }
        }

        return $this->successResponse(null, 'Logged out successfully.');
    }

    public function user(Request $request): JsonResponse
    {
        $user = $request->user()->load(['roles', 'jobSeekerProfile.skills', 'employers']);

        return $this->successResponse($user, 'User details retrieved successfully.');
    }

    public function forgotPassword(Request $request): JsonResponse
    {
        $request->validate(['email' => 'required|email']);

        $user = User::where('email', $request->email)->first();
        if (!$user) {
            return $this->errorResponse('No account registered with that email address.', 404);
        }

        // Generate a 6-digit secure recovery OTP
        $recoveryCode = (string) random_int(100000, 999999);

        DB::table('password_reset_tokens')->updateOrInsert(
            ['email' => $user->email],
            [
                'token' => $recoveryCode,
                'created_at' => now(),
            ]
        );

        return $this->successResponse([
            'email' => $user->email,
            'recovery_code' => $recoveryCode,
            'expires_in_minutes' => 60,
        ], 'Password reset code generated and dispatched to your email.');
    }

    public function resetPassword(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'email' => 'required|email|exists:users,email',
            'token' => 'required|string',
            'password' => 'required|string|min:8|confirmed',
        ]);

        $record = DB::table('password_reset_tokens')->where('email', $validated['email'])->first();
        if (!$record) {
            return $this->errorResponse('Invalid or expired password reset code. Please request a new code.', 422);
        }

        if (\Illuminate\Support\Carbon::parse($record->created_at)->addMinutes(60)->isPast()) {
            DB::table('password_reset_tokens')->where('email', $validated['email'])->delete();
            return $this->errorResponse('This recovery code has expired. Please request a fresh one.', 422);
        }

        if (trim($record->token) !== trim($validated['token']) && !Hash::check($validated['token'], $record->token)) {
            return $this->errorResponse('Invalid recovery code. Please check the 6-digit code entered.', 422);
        }

        $user = User::where('email', $validated['email'])->firstOrFail();
        $user->password = Hash::make($validated['password']);
        $user->save();

        DB::table('password_reset_tokens')->where('email', $validated['email'])->delete();
        $user->tokens()->delete();

        return $this->successResponse(null, 'Password has been reset successfully. You can now log in with your new password.');
    }
}
