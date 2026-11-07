<?php

namespace Tests\Feature;

use App\Models\Document;
use App\Models\JobSeekerProfile;
use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class FileUploadAndStorageTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('public');
        Storage::fake('private');
    }

    private function createJobSeekerUser(): User
    {
        $role = Role::firstOrCreate(['name' => 'job_seeker'], ['description' => 'Job Seeker']);
        $user = User::factory()->create();
        $user->roles()->attach($role->id);
        JobSeekerProfile::create([
            'user_id' => $user->id,
            'first_name' => 'Abebe',
            'last_name' => 'Bikila',
            'experience_years' => 3,
        ]);
        return $user;
    }

    public function test_profile_photo_upload_endpoint_stores_image(): void
    {
        $user = $this->createJobSeekerUser();
        $file = UploadedFile::fake()->image('avatar.jpg', 300, 300);

        $response = $this->actingAs($user, 'sanctum')->postJson('/api/v1/profile/photo', [
            'photo' => $file,
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
            ]);

        $profilePhotoUrl = $response->json('data.profile_photo');
        $this->assertNotNull($profilePhotoUrl);
        $this->assertStringContainsString('/storage/profile_photos/', $profilePhotoUrl);

        $user->refresh();
        $this->assertEquals($profilePhotoUrl, $user->profile_photo);
    }

    public function test_profile_update_converts_base64_data_uri_to_stored_file(): void
    {
        $user = $this->createJobSeekerUser();
        // 1x1 transparent PNG data uri
        $base64Png = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

        $response = $this->actingAs($user, 'sanctum')->putJson('/api/v1/profile', [
            'first_name' => 'Abebe',
            'last_name' => 'Kebede',
            'profile_photo' => $base64Png,
        ]);

        $response->assertStatus(200)
            ->assertJson(['success' => true]);

        $user->refresh();
        $this->assertNotNull($user->profile_photo);
        $this->assertStringNotContainsString('data:image', $user->profile_photo);
        $this->assertStringContainsString('/storage/profile_photos/', $user->profile_photo);
    }

    public function test_document_download_and_view_works_with_query_token(): void
    {
        $user = $this->createJobSeekerUser();
        $token = $user->createToken('test_auth_token')->plainTextToken;

        $docPath = 'documents/cv_' . $user->id . '_test.pdf';
        Storage::disk('private')->put($docPath, '%PDF-1.4 test resume content');

        $document = Document::create([
            'user_id' => $user->id,
            'document_type' => 'cv',
            'original_name' => 'my_resume.pdf',
            'storage_path' => $docPath,
            'mime_type' => 'application/pdf',
            'file_size' => 2048,
        ]);

        // Access via download with ?token=
        $response = $this->get('/api/v1/documents/' . $document->id . '/download?token=' . $token);
        $response->assertStatus(200);

        // Access via view with ?token= and &view=1
        $viewResponse = $this->get('/api/v1/documents/' . $document->id . '/view?token=' . $token . '&view=1');
        $viewResponse->assertStatus(200);
        $this->assertEquals('application/pdf', $viewResponse->headers->get('Content-Type'));
        $this->assertStringContainsString('inline', $viewResponse->headers->get('Content-Disposition'));
    }
}
