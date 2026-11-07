<?php

namespace Tests\Feature;

use App\Models\ChatGroup;
use App\Models\Job;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ChatApiTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed();
    }

    public function test_user_can_list_chat_groups(): void
    {
        $user = User::where('email', 'jobseeker@example.com')->first();

        $response = $this->actingAs($user, 'sanctum')->getJson('/api/v1/chat/groups');

        $response->assertStatus(200)
                 ->assertJson(['success' => true])
                 ->assertJsonStructure([
                     'data' => [
                         '*' => ['id', 'name', 'description', 'members_count', 'is_member']
                     ]
                 ]);
    }

    public function test_user_can_create_group_and_send_message(): void
    {
        $user = User::where('email', 'jobseeker@example.com')->first();
        $job = Job::first();

        // 1. Create group
        $createResp = $this->actingAs($user, 'sanctum')->postJson('/api/v1/chat/groups', [
            'name' => 'Addis Software Innovators',
            'description' => 'Discussion group for developers in Addis Ababa.',
        ]);

        $createResp->assertStatus(201)
                   ->assertJson(['success' => true]);

        $groupId = $createResp->json('data.id');

        // 2. Send text message
        $msgResp = $this->actingAs($user, 'sanctum')->postJson("/api/v1/chat/groups/{$groupId}/messages", [
            'message' => 'Hello team, check out this great opportunity!',
            'shared_job_id' => $job->id,
        ]);

        $msgResp->assertStatus(201)
                ->assertJson(['success' => true])
                ->assertJson([
                    'data' => [
                        'message_type' => 'job_share',
                        'shared_job_id' => $job->id,
                    ]
                ]);

        // 3. Retrieve messages
        $getMsgsResp = $this->actingAs($user, 'sanctum')->getJson("/api/v1/chat/groups/{$groupId}/messages");
        $getMsgsResp->assertStatus(200)
                    ->assertJson(['success' => true]);

        $this->assertCount(2, $getMsgsResp->json('data')); // welcome msg + job share msg
    }
}
