<?php

namespace App\Http\Controllers\Api;

use App\Models\JobCategory;
use App\Models\JobTitle;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;

class JobCategoryController extends BaseApiController
{
    /**
     * List all Ethiopian job categories with vacancy and title counts.
     */
    public function index(Request $request): JsonResponse
    {
        $includeTitles = $request->boolean('include_titles', false);
        $cacheKey = 'job_categories_idx_' . ($includeTitles ? 'titles' : 'base');

        $categories = Cache::remember($cacheKey, 180, function () use ($includeTitles) {
            $query = JobCategory::orderBy('display_order', 'asc');

            if ($includeTitles) {
                $query->with(['titles' => function ($q) {
                    $q->orderBy('title', 'asc');
                }]);
            }

            $query->withCount([
                'titles',
                'jobs as published_jobs_count' => function ($q) {
                    $q->where('status', 'published');
                }
            ]);

            return $query->get();
        });

        return $this->successResponse($categories, 'Job categories retrieved successfully.');
    }

    /**
     * Show single job category with its titles.
     */
    public function show(Request $request, int $id): JsonResponse
    {
        $category = JobCategory::with(['titles' => function ($q) {
            $q->orderBy('title', 'asc');
        }])->withCount([
            'titles',
            'jobs as published_jobs_count' => function ($q) {
                $q->where('status', 'published');
            }
        ])->findOrFail($id);

        return $this->successResponse($category, 'Job category details retrieved.');
    }

    /**
     * List / search standard Ethiopian job titles.
     */
    public function titles(Request $request): JsonResponse
    {
        $query = JobTitle::with('category:id,name,slug,icon');

        if ($request->filled('category_id')) {
            $query->where('category_id', $request->category_id);
        }

        if ($request->filled('category')) {
            $cat = $request->category;
            $query->whereHas('category', function ($q) use ($cat) {
                $q->where('slug', $cat)->orWhere('name', 'like', "%{$cat}%");
            });
        }

        if ($request->filled('query') || $request->filled('keyword') || $request->filled('q')) {
            $searchTerm = $request->get('query') ?: ($request->get('keyword') ?: $request->get('q'));
            $query->where('title', 'like', "%{$searchTerm}%");
        }

        $limit = min((int)$request->get('limit', 50), 500);
        $titles = $query->orderBy('title', 'asc')->paginate($limit);

        return $this->successResponse($titles->items(), 'Job titles retrieved successfully.', 200, [
            'current_page' => $titles->currentPage(),
            'total' => $titles->total(),
            'per_page' => $titles->perPage(),
            'last_page' => $titles->lastPage(),
        ]);
    }

    /**
     * Lightweight title autocomplete suggestions.
     */
    public function suggestions(Request $request): JsonResponse
    {
        $searchTerm = trim($request->get('q', $request->get('query', '')));
        $categoryId = $request->get('category_id');
        $cacheKey = 'job_suggestions_' . md5($searchTerm . '_' . ($categoryId ?? 'all'));

        $suggestions = Cache::remember($cacheKey, 180, function () use ($categoryId, $searchTerm) {
            $query = JobTitle::query();

            if ($categoryId) {
                $query->where('category_id', $categoryId);
            }

            if ($searchTerm !== '') {
                $query->where('title', 'like', "%{$searchTerm}%");
            }

            return $query->limit(15)->pluck('title')->values();
        });

        return $this->successResponse($suggestions, 'Job title suggestions retrieved.');
    }
}
