<?php

namespace App\Http\Controllers\Api;

use App\Services\CareerAssistantService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class CareerAssistantController extends BaseApiController
{
    /**
     * Ask career guidance question (bilingual English / Amharic).
     */
    public function ask(Request $request, CareerAssistantService $service): JsonResponse
    {
        $validated = $request->validate([
            'question' => 'required|string|min:3|max:1000',
            'locale' => 'nullable|string|in:en,am',
        ]);

        $user = $request->user();
        $response = $service->askCareerQuestion(
            question: $validated['question'],
            user: $user,
            locale: $validated['locale'] ?? 'en'
        );

        return $this->successResponse($response, 'Career guidance generated successfully.');
    }

    /**
     * Generate customized cover letter draft tailored to candidate profile and target job.
     */
    public function generateCoverLetter(Request $request, CareerAssistantService $service): JsonResponse
    {
        $validated = $request->validate([
            'job_id' => 'required|integer|exists:jobs,id',
            'tone' => 'nullable|string|in:professional,confident,enthusiastic',
            'custom_notes' => 'nullable|string|max:1000',
        ]);

        $response = $service->generateCoverLetter(
            jobId: $validated['job_id'],
            user: $request->user(),
            tone: $validated['tone'] ?? 'professional',
            customNotes: $validated['custom_notes'] ?? null
        );

        return $this->successResponse($response, 'Tailored cover letter draft generated successfully.');
    }

    /**
     * Role-specific interview practice and model STAR answers.
     */
    public function interviewPractice(Request $request, CareerAssistantService $service): JsonResponse
    {
        $validated = $request->validate([
            'job_id' => 'required|integer|exists:jobs,id',
            'role_title' => 'nullable|string|max:150',
        ]);

        $response = $service->generateInterviewPractice(
            jobId: $validated['job_id'],
            roleTitle: $validated['role_title'] ?? null
        );

        return $this->successResponse($response, 'Interview practice questions and answers generated.');
    }

    /**
     * Skill-gap analysis comparing seeker's skills to job requirements.
     */
    public function skillGap(Request $request, int $jobId, CareerAssistantService $service): JsonResponse
    {
        $response = $service->analyzeSkillGap($jobId, $request->user());
        return $this->successResponse($response, 'Skill-gap analysis computed successfully.');
    }
}
