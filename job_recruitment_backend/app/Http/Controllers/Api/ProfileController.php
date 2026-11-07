<?php

namespace App\Http\Controllers\Api;

use App\Http\Requests\ProfileRequest;
use App\Models\EducationRecord;
use App\Models\JobSeekerProfile;
use App\Models\JobSeekerSkill;
use App\Models\Skill;
use App\Models\WorkExperience;
use App\Services\ImageUploadService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ProfileController extends BaseApiController
{
    private function getOrCreateProfile($user): JobSeekerProfile
    {
        return JobSeekerProfile::firstOrCreate(
            ['user_id' => $user->id],
            ['experience_years' => 0]
        );
    }

    public function show(Request $request): JsonResponse
    {
        $profile = $this->getOrCreateProfile($request->user());
        $profile->load(['user', 'skills', 'educationRecords', 'workExperiences']);

        return $this->successResponse($profile, 'Profile retrieved successfully.');
    }

    public function update(ProfileRequest $request): JsonResponse
    {
        $profile = $this->getOrCreateProfile($request->user());
        $validated = $request->validated();

        $photoInput = $request->file('profile_photo_file')
            ?: ($request->file('photo')
            ?: ($request->file('file')
            ?: ($request->input('profile_photo') ?: $request->input('photo'))));

        if ($photoInput) {
            $photoUrl = ImageUploadService::storeImage($photoInput, 'profile_photos');
            if ($photoUrl) {
                $validated['profile_photo'] = $photoUrl;
            }
        }

        if (isset($validated['name']) || isset($validated['phone']) || array_key_exists('profile_photo', $validated)) {
            $user = $request->user();
            if (isset($validated['name'])) $user->name = $validated['name'];
            if (isset($validated['phone'])) $user->phone = $validated['phone'];
            if (array_key_exists('profile_photo', $validated)) $user->profile_photo = $validated['profile_photo'];
            $user->save();
        }

        $profile->update($validated);
        $profile->load(['user', 'skills', 'educationRecords', 'workExperiences']);

        return $this->successResponse($profile, 'Profile updated successfully.');
    }

    /**
     * Upload profile photo directly via file or base64.
     */
    public function uploadPhoto(Request $request): JsonResponse
    {
        $request->validate([
            'photo' => 'nullable',
            'file' => 'nullable',
            'profile_photo_file' => 'nullable|file|mimes:jpeg,jpg,png,webp,gif|max:5120',
            'profile_photo' => 'nullable|string',
        ]);

        $photoInput = $request->file('photo')
            ?: ($request->file('file')
            ?: ($request->file('profile_photo_file')
            ?: ($request->input('photo') ?: $request->input('profile_photo'))));

        if (!$photoInput) {
            return $this->errorResponse('No image file or photo payload provided.', 422);
        }

        $photoUrl = ImageUploadService::storeImage($photoInput, 'profile_photos');
        if (!$photoUrl) {
            return $this->errorResponse('Failed to process image upload.', 500);
        }

        $user = $request->user();
        $user->profile_photo = $photoUrl;
        $user->save();

        return $this->successResponse([
            'profile_photo' => $photoUrl,
            'user' => $user->fresh(),
        ], 'Profile photo uploaded and updated successfully.');
    }

    // Skills
    public function listSkills(): JsonResponse
    {
        $skills = Skill::orderBy('category')->orderBy('name')->get();
        return $this->successResponse($skills, 'Available skills list.');
    }

    public function getSkills(Request $request): JsonResponse
    {
        $profile = $this->getOrCreateProfile($request->user());
        return $this->successResponse($profile->skills, 'User skills retrieved.');
    }

    public function addSkill(Request $request): JsonResponse
    {
        $profile = $this->getOrCreateProfile($request->user());

        $validated = $request->validate([
            'skill_id' => 'required|exists:skills,id',
            'proficiency_level' => 'required|string|in:beginner,intermediate,advanced,expert',
            'years_experience' => 'nullable|numeric|min:0',
        ]);

        JobSeekerSkill::updateOrCreate(
            ['profile_id' => $profile->id, 'skill_id' => $validated['skill_id']],
            [
                'proficiency_level' => $validated['proficiency_level'],
                'years_experience' => $validated['years_experience'] ?? 0,
            ]
        );

        $profile->load('skills');
        return $this->successResponse($profile->skills, 'Skill added or updated.');
    }

    public function removeSkill(Request $request, int $skillId): JsonResponse
    {
        $profile = $this->getOrCreateProfile($request->user());
        JobSeekerSkill::where('profile_id', $profile->id)->where('skill_id', $skillId)->delete();

        return $this->successResponse(null, 'Skill removed successfully.');
    }

    // Education
    public function getEducation(Request $request): JsonResponse
    {
        $profile = $this->getOrCreateProfile($request->user());
        return $this->successResponse($profile->educationRecords, 'Education records.');
    }

    public function addEducation(Request $request): JsonResponse
    {
        $profile = $this->getOrCreateProfile($request->user());

        $validated = $request->validate([
            'institution_name' => 'required|string|max:200',
            'qualification' => 'required|string|max:150',
            'field_of_study' => 'nullable|string|max:150',
            'start_date' => 'nullable|date',
            'end_date' => 'nullable|date|after_or_equal:start_date',
            'grade' => 'nullable|string|max:50',
            'description' => 'nullable|string',
        ]);

        $record = $profile->educationRecords()->create($validated);
        return $this->successResponse($record, 'Education record added.', 201);
    }

    public function removeEducation(Request $request, int $id): JsonResponse
    {
        $profile = $this->getOrCreateProfile($request->user());
        $profile->educationRecords()->where('id', $id)->delete();

        return $this->successResponse(null, 'Education record removed.');
    }

    // Work Experience
    public function getExperience(Request $request): JsonResponse
    {
        $profile = $this->getOrCreateProfile($request->user());
        return $this->successResponse($profile->workExperiences, 'Work experience records.');
    }

    public function addExperience(Request $request): JsonResponse
    {
        $profile = $this->getOrCreateProfile($request->user());

        $validated = $request->validate([
            'company_name' => 'required|string|max:200',
            'job_title' => 'required|string|max:150',
            'employment_type' => 'nullable|string|max:50',
            'start_date' => 'nullable|date',
            'end_date' => 'nullable|date',
            'is_current' => 'nullable|boolean',
            'description' => 'nullable|string',
        ]);

        $record = $profile->workExperiences()->create($validated);
        return $this->successResponse($record, 'Work experience added.', 201);
    }

    public function removeExperience(Request $request, int $id): JsonResponse
    {
        $profile = $this->getOrCreateProfile($request->user());
        $profile->workExperiences()->where('id', $id)->delete();

        return $this->successResponse(null, 'Work experience removed.');
    }
}
