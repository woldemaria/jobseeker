<?php

namespace App\Http\Controllers\Api;

use App\Models\ChatGroup;
use App\Models\ChatGroupMember;
use App\Models\ChatMessage;
use App\Models\Job;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class ChatController extends BaseApiController
{
    /**
     * List user's active groups and explore public discoverable groups.
     */
    public function index(Request $request): JsonResponse
    {
        $userId = $request->user()->id;

        $groups = ChatGroup::with(['latestMessage.user', 'creator'])
            ->withCount('members')
            ->orderBy('updated_at', 'desc')
            ->get()
            ->map(function ($group) use ($userId) {
                $isMember = $group->members()->where('user_id', $userId)->exists();
                $group->is_member = $isMember;
                return $group;
            });

        return $this->successResponse($groups, 'Chat groups retrieved successfully.');
    }

    /**
     * Create a new chat group.
     */
    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'required|string|min:3|max:120',
            'description' => 'nullable|string|max:1000',
            'icon_url' => 'nullable|string|max:255',
            'is_private' => 'nullable|boolean',
        ]);

        $group = DB::transaction(function () use ($request, $validated) {
            $chatGroup = ChatGroup::create([
                'name' => $validated['name'],
                'description' => $validated['description'] ?? null,
                'icon_url' => $validated['icon_url'] ?? null,
                'created_by' => $request->user()->id,
                'is_private' => $validated['is_private'] ?? false,
            ]);

            // Automatically add creator as owner
            ChatGroupMember::create([
                'group_id' => $chatGroup->id,
                'user_id' => $request->user()->id,
                'role' => 'owner',
                'joined_at' => now(),
            ]);

            // Post welcome message
            ChatMessage::create([
                'group_id' => $chatGroup->id,
                'user_id' => $request->user()->id,
                'message' => "Welcome to {$chatGroup->name}! Feel free to share vacancies, discuss career paths, and support each other.",
                'message_type' => 'text',
            ]);

            return $chatGroup;
        });

        $group->loadCount('members')->load(['latestMessage.user', 'creator']);
        $group->is_member = true;

        return $this->successResponse($group, 'Chat group created successfully.', 201);
    }

    /**
     * View single group details with members.
     */
    public function show(Request $request, int $id): JsonResponse
    {
        $group = ChatGroup::with(['creator', 'members.user'])->withCount('members')->findOrFail($id);
        $group->is_member = $group->members()->where('user_id', $request->user()->id)->exists();

        return $this->successResponse($group, 'Chat group details retrieved.');
    }

    /**
     * Join group.
     */
    public function join(Request $request, int $id): JsonResponse
    {
        $group = ChatGroup::findOrFail($id);
        $user = $request->user();

        $member = ChatGroupMember::firstOrCreate(
            ['group_id' => $group->id, 'user_id' => $user->id],
            ['role' => 'member', 'joined_at' => now()]
        );

        return $this->successResponse($member, "Successfully joined {$group->name}.");
    }

    /**
     * Leave group.
     */
    public function leave(Request $request, int $id): JsonResponse
    {
        $group = ChatGroup::findOrFail($id);
        $user = $request->user();

        ChatGroupMember::where('group_id', $group->id)->where('user_id', $user->id)->delete();

        return $this->successResponse(null, "Left {$group->name} successfully.");
    }

    /**
     * Retrieve messages for a group.
     */
    public function messages(Request $request, int $id): JsonResponse
    {
        $group = ChatGroup::findOrFail($id);

        $messages = ChatMessage::where('group_id', $group->id)
            ->with(['user', 'sharedJob.employer'])
            ->orderBy('created_at', 'asc')
            ->limit(100)
            ->get();

        return $this->successResponse($messages, 'Chat messages retrieved.');
    }

    /**
     * Send a message or share a vacancy into the group.
     */
    public function sendMessage(Request $request, int $id): JsonResponse
    {
        $group = ChatGroup::findOrFail($id);
        $user = $request->user();

        // Ensure user is member
        ChatGroupMember::firstOrCreate(
            ['group_id' => $group->id, 'user_id' => $user->id],
            ['role' => 'member', 'joined_at' => now()]
        );

        $validated = $request->validate([
            'message' => 'required|string|max:5000',
            'message_type' => 'nullable|string|in:text,job_share,image',
            'shared_job_id' => 'nullable|integer|exists:jobs,id',
        ]);

        $msgType = $validated['message_type'] ?? 'text';
        if (!empty($validated['shared_job_id'])) {
            $msgType = 'job_share';
        }

        $message = ChatMessage::create([
            'group_id' => $group->id,
            'user_id' => $user->id,
            'message' => $validated['message'],
            'message_type' => $msgType,
            'shared_job_id' => $validated['shared_job_id'] ?? null,
        ]);

        $group->touch(); // updates updated_at so group bubbles to top

        $message->load(['user', 'sharedJob.employer']);

        return $this->successResponse($message, 'Message sent successfully.', 201);
    }
}
