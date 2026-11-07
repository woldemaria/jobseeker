<?php

namespace Tests\Feature;

use App\Models\JobCategory;
use App\Models\JobTitle;
use App\Models\Job;
use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class JobCategoryAndTitlesTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed();
    }

    public function test_can_list_all_30_ethiopian_categories(): void
    {
        $response = $this->getJson('/api/v1/categories');

        $response->assertStatus(200)
                 ->assertJson([
                     'success' => true,
                     'message' => 'Job categories retrieved successfully.',
                 ]);

        $this->assertCount(30, $response->json('data'));
    }

    public function test_can_search_and_filter_job_titles(): void
    {
        // 1. Search by title keyword
        $response = $this->getJson('/api/v1/job-titles?query=Engineer');

        $response->assertStatus(200)
                 ->assertJson(['success' => true]);

        $items = $response->json('data');
        $this->assertNotEmpty($items);
        foreach ($items as $item) {
            $this->assertStringContainsStringIgnoringCase('Engineer', $item['title']);
        }

        // 2. Filter by category
        $agriCategory = JobCategory::where('name', 'Agriculture and Farming')->first();
        $responseAgri = $this->getJson('/api/v1/job-titles?category_id=' . $agriCategory->id);

        $responseAgri->assertStatus(200);
        $this->assertEquals(20, $responseAgri->json('meta.total'));
    }

    public function test_job_titles_suggestions_endpoint(): void
    {
        $response = $this->getJson('/api/v1/job-titles/suggestions?q=Farm');

        $response->assertStatus(200)
                 ->assertJson(['success' => true]);

        $suggestions = $response->json('data');
        $this->assertNotEmpty($suggestions);
    }

    public function test_can_filter_jobs_by_category(): void
    {
        $response = $this->getJson('/api/v1/jobs?category=Agriculture and Farming');

        $response->assertStatus(200)
                 ->assertJson(['success' => true]);

        $data = $response->json('data');
        $this->assertNotEmpty($data);
        $this->assertEquals('Agronomist', $data[0]['title']);
    }
}
