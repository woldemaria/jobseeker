<?php

namespace App\Http\Controllers\Api;

use App\Models\AdvertisingPackage;
use App\Models\AuditLog;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class AdvertisingPackageController extends BaseApiController
{
    /**
     * Public / Employer: List all active advertising packages.
     */
    public function index(Request $request): JsonResponse
    {
        $packages = AdvertisingPackage::active()
            ->ordered()
            ->get();

        return $this->successResponse($packages, 'Advertising packages retrieved successfully.');
    }

    /**
     * Public / Employer: Get single advertising package details.
     */
    public function show(int $id): JsonResponse
    {
        $package = AdvertisingPackage::findOrFail($id);

        return $this->successResponse($package, 'Package details retrieved.');
    }

    /**
     * Admin: List all advertising packages (including inactive) with usage metrics.
     */
    public function adminIndex(Request $request): JsonResponse
    {
        $packages = AdvertisingPackage::withCount('advertisements')
            ->ordered()
            ->get();

        return $this->successResponse($packages, 'All advertising packages retrieved for administration.');
    }

    /**
     * Admin: Create a new advertising package with validation and audit logging.
     */
    public function adminStore(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'required|string|max:100',
            'slug' => 'nullable|string|max:100|unique:advertising_packages,slug',
            'description' => 'nullable|string',
            'duration_days' => 'required|integer|min:1|max:365',
            'price_etb' => 'required|numeric|min:0',
            'allowed_placements' => 'required|array|min:1',
            'allowed_placements.*' => 'string|in:hero,dashboard,job_list,sidebar,search_sponsored,category_specific',
            'allowed_categories' => 'required|array|min:1',
            'allowed_categories.*' => 'string|in:featured_jobs,company_promotions,recruitment_campaigns,sponsored_vacancies,announcements',
            'benefits' => 'nullable|array',
            'benefits.*' => 'string|max:255',
            'badge_label' => 'nullable|string|max:50',
            'is_active' => 'nullable|boolean',
            'priority_level' => 'nullable|integer|min:0|max:100',
        ]);

        if (empty($validated['slug'])) {
            $baseSlug = Str::slug($validated['name']);
            $slug = $baseSlug;
            $count = 1;
            while (AdvertisingPackage::where('slug', $slug)->exists()) {
                $slug = "{$baseSlug}-{$count}";
                $count++;
            }
            $validated['slug'] = $slug;
        }

        $validated['is_active'] = $validated['is_active'] ?? true;
        $validated['priority_level'] = $validated['priority_level'] ?? 0;

        $package = DB::transaction(function () use ($validated, $request) {
            $pkg = AdvertisingPackage::create($validated);

            AuditLog::create([
                'user_id' => $request->user()->id,
                'action' => 'advertising_package_created',
                'entity_type' => 'AdvertisingPackage',
                'entity_id' => $pkg->id,
                'description' => "Created package '{$pkg->name}' with duration {$pkg->duration_days} days at {$pkg->price_etb} ETB.",
                'ip_address' => $request->ip(),
                'created_at' => now(),
            ]);

            return $pkg;
        });

        return $this->successResponse($package, 'Advertising package created successfully.', 201);
    }

    /**
     * Admin: Update an advertising package (pricing, duration, placements, active status).
     */
    public function adminUpdate(Request $request, int $id): JsonResponse
    {
        $package = AdvertisingPackage::findOrFail($id);

        $validated = $request->validate([
            'name' => 'sometimes|required|string|max:100',
            'slug' => "sometimes|required|string|max:100|unique:advertising_packages,slug,{$id}",
            'description' => 'nullable|string',
            'duration_days' => 'sometimes|required|integer|min:1|max:365',
            'price_etb' => 'sometimes|required|numeric|min:0',
            'allowed_placements' => 'sometimes|required|array|min:1',
            'allowed_placements.*' => 'string|in:hero,dashboard,job_list,sidebar,search_sponsored,category_specific',
            'allowed_categories' => 'sometimes|required|array|min:1',
            'allowed_categories.*' => 'string|in:featured_jobs,company_promotions,recruitment_campaigns,sponsored_vacancies,announcements',
            'benefits' => 'nullable|array',
            'benefits.*' => 'string|max:255',
            'badge_label' => 'nullable|string|max:50',
            'is_active' => 'nullable|boolean',
            'priority_level' => 'nullable|integer|min:0|max:100',
        ]);

        $package = DB::transaction(function () use ($package, $validated, $request) {
            $package->update($validated);

            AuditLog::create([
                'user_id' => $request->user()->id,
                'action' => 'advertising_package_updated',
                'entity_type' => 'AdvertisingPackage',
                'entity_id' => $package->id,
                'description' => "Updated package '{$package->name}' (Price: {$package->price_etb} ETB, Active: " . ($package->is_active ? 'Yes' : 'No') . ").",
                'ip_address' => $request->ip(),
                'created_at' => now(),
            ]);

            return $package;
        });

        return $this->successResponse($package->fresh(), 'Advertising package updated successfully.');
    }

    /**
     * Admin: Quick toggle active / inactive status.
     */
    public function adminToggleStatus(Request $request, int $id): JsonResponse
    {
        $package = AdvertisingPackage::findOrFail($id);

        $package->is_active = !$package->is_active;
        $package->save();

        AuditLog::create([
            'user_id' => $request->user()->id,
            'action' => 'advertising_package_status_toggled',
            'entity_type' => 'AdvertisingPackage',
            'entity_id' => $package->id,
            'description' => "Package '{$package->name}' set to " . ($package->is_active ? 'Active' : 'Inactive') . ".",
            'ip_address' => $request->ip(),
            'created_at' => now(),
        ]);

        return $this->successResponse(
            $package,
            "Package status toggled to " . ($package->is_active ? 'active' : 'inactive') . "."
        );
    }

    /**
     * Admin: Delete advertising package safely.
     */
    public function adminDestroy(Request $request, int $id): JsonResponse
    {
        $package = AdvertisingPackage::withCount('advertisements')->findOrFail($id);

        if ($package->advertisements_count > 0) {
            return $this->errorResponse(
                "Cannot delete package '{$package->name}' because {$package->advertisements_count} campaign(s) are associated with it. You can deactivate it instead.",
                400
            );
        }

        DB::transaction(function () use ($package, $request) {
            AuditLog::create([
                'user_id' => $request->user()->id,
                'action' => 'advertising_package_deleted',
                'entity_type' => 'AdvertisingPackage',
                'entity_id' => $package->id,
                'description' => "Deleted package '{$package->name}'.",
                'ip_address' => $request->ip(),
                'created_at' => now(),
            ]);

            $package->delete();
        });

        return $this->successResponse(null, "Package '{$package->name}' deleted successfully.");
    }
}
