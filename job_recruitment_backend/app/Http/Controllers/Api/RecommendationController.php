<?php

namespace App\Http\Controllers\Api;

use App\Models\Job;
use App\Services\MatchingService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class RecommendationController extends BaseApiController
{
    public function __construct(
        protected MatchingService $matchingService
    ) {}

    /**
     * Get recommended vacancies for the authenticated job seeker.
     */
    public function recommendations(Request $request): JsonResponse
    {
        $profile = $request->user()->jobSeekerProfile;

        if (!$profile) {
            return $this->errorResponse('Job seeker profile required to view recommendations.', 403);
        }

        $recommendations = $this->matchingService->getRecommendations($profile, $request->get('limit', 20));

        $user = $request->user();
        if ($user) {
            $savedJobIds = \App\Models\SavedJob::where('user_id', $user->id)->pluck('job_id')->flip();
            $appliedJobIds = $profile->applications()->pluck('status', 'job_id')->toArray();

            foreach ($recommendations as $job) {
                $job->is_saved = isset($savedJobIds[$job->id]);
                $job->has_applied = isset($appliedJobIds[$job->id]);
                if (isset($appliedJobIds[$job->id])) {
                    $job->application_status = $appliedJobIds[$job->id];
                }
            }
        }

        return $this->successResponse($recommendations, 'Recommended vacancies retrieved based on skills matching.');
    }

    /**
     * Get transparent match score and detailed explanation for a specific vacancy.
     */
    public function matchDetails(Request $request, int $id): JsonResponse
    {
        $job = Job::with(['skills', 'employer'])->findOrFail($id);
        $profile = $request->user()->jobSeekerProfile;

        if (!$profile) {
            return $this->errorResponse('Job seeker profile required to calculate match.', 403);
        }

        $analysis = $this->matchingService->calculateMatch($profile, $job);

        return $this->successResponse([
            'job' => $job,
            'match_analysis' => $analysis,
        ], 'Skills match explanation generated successfully.');
    }
}
