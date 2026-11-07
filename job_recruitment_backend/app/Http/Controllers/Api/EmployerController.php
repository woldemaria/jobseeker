<?php

namespace App\Http\Controllers\Api;

use App\Models\AuditLog;
use App\Models\Employer;
use App\Models\EmployerMember;
use App\Models\EmployerVerification;
use App\Models\Role;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class EmployerController extends BaseApiController
{
    private function getEmployerForUser($user): ?Employer
    {
        return $user->employers()->first();
    }

    public function registerOrganization(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'organization_name' => 'required|string|max:200',
            'organization_type' => 'nullable|string|max:100',
            'registration_number' => 'nullable|string|max:100',
            'email' => 'nullable|email|max:150',
            'phone' => 'nullable|string|max:30',
            'website' => 'nullable|string|max:255',
            'address' => 'nullable|string',
        ]);

        $user = $request->user();

        // Check if user already has an employer organization
        $existing = $this->getEmployerForUser($user);
        if ($existing) {
            return $this->errorResponse('You already manage an employer organization.', 409);
        }

        $employer = DB::transaction(function () use ($user, $validated, $request) {
            $emp = Employer::create(array_merge($validated, ['verification_status' => 'pending']));

            EmployerMember::create([
                'employer_id' => $emp->id,
                'user_id' => $user->id,
                'member_role' => 'owner',
            ]);

            // Ensure role is assigned
            $employerRole = Role::where('name', 'employer')->first();
            if ($employerRole) {
                $user->roles()->syncWithoutDetaching([$employerRole->id]);
            }

            AuditLog::create([
                'user_id' => $user->id,
                'action' => 'employer_registered',
                'entity_type' => 'Employer',
                'entity_id' => $emp->id,
                'description' => "Organization '{$emp->organization_name}' registered.",
                'ip_address' => $request->ip(),
                'created_at' => now(),
            ]);

            return $emp;
        });

        return $this->successResponse($employer, 'Organization registered successfully.', 201);
    }

    public function showProfile(Request $request): JsonResponse
    {
        $employer = $this->getEmployerForUser($request->user());
        if (!$employer) {
            return $this->errorResponse('No associated employer profile found.', 404);
        }

        $employer->load(['members.user', 'verifications']);
        return $this->successResponse($employer, 'Employer profile retrieved.');
    }

    public function updateProfile(Request $request): JsonResponse
    {
        $employer = $this->getEmployerForUser($request->user());
        if (!$employer) {
            return $this->errorResponse('No associated employer profile found.', 404);
        }

        $validated = $request->validate([
            'organization_name' => 'sometimes|string|max:200',
            'organization_type' => 'nullable|string|max:100',
            'registration_number' => 'nullable|string|max:100',
            'email' => 'nullable|email|max:150',
            'phone' => 'nullable|string|max:30',
            'website' => 'nullable|string|max:255',
            'address' => 'nullable|string',
        ]);

        $employer->update($validated);
        return $this->successResponse($employer, 'Employer organization updated.');
    }

    public function submitVerification(Request $request): JsonResponse
    {
        $employer = $this->getEmployerForUser($request->user());
        if (!$employer) {
            return $this->errorResponse('Employer organization required.', 404);
        }

        $validated = $request->validate([
            'document_id' => 'nullable|exists:documents,id',
            'review_notes' => 'nullable|string',
        ]);

        $verification = EmployerVerification::create([
            'employer_id' => $employer->id,
            'document_id' => $validated['document_id'] ?? null,
            'submitted_by' => $request->user()->id,
            'status' => 'pending',
            'review_notes' => $validated['review_notes'] ?? null,
            'submitted_at' => now(),
        ]);

        $employer->verification_status = 'pending';
        $employer->save();

        return $this->successResponse($verification, 'Verification request submitted.', 201);
    }

    public function getVerificationStatus(Request $request): JsonResponse
    {
        $employer = $this->getEmployerForUser($request->user());
        if (!$employer) {
            return $this->errorResponse('Employer organization required.', 404);
        }

        $verifications = $employer->verifications()->latest()->get();
        return $this->successResponse([
            'verification_status' => $employer->verification_status,
            'history' => $verifications,
        ], 'Verification status retrieved.');
    }
}
