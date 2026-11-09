<?php

namespace App\Http\Controllers\Api;

use App\Models\Notification;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class NotificationController extends BaseApiController
{
    public function index(Request $request): JsonResponse
    {
        $notifications = Notification::where('user_id', $request->user()->id)
            ->latest()
            ->paginate($request->get('per_page', 20));

        return $this->successResponse($notifications->items(), 'Notifications retrieved.', 200, [
            'unread_count' => Notification::where('user_id', $request->user()->id)->where('is_read', false)->count(),
            'current_page' => $notifications->currentPage(),
            'total' => $notifications->total(),
        ]);
    }

    public function markAsRead(Request $request, int $id): JsonResponse
    {
        $notification = Notification::where('user_id', $request->user()->id)->findOrFail($id);
        $notification->update([
            'is_read' => true,
            'read_at' => now(),
        ]);

        return $this->successResponse($notification, 'Notification marked as read.');
    }

    public function markAllAsRead(Request $request): JsonResponse
    {
        Notification::where('user_id', $request->user()->id)
            ->where('is_read', false)
            ->update([
                'is_read' => true,
                'read_at' => now(),
            ]);

        return $this->successResponse(null, 'All notifications marked as read.');
    }

    /**
     * Register device push notification token (FCM / APNs).
     */
    public function registerDeviceToken(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'device_token' => 'required|string|max:255',
            'platform' => 'nullable|string|in:android,ios,web',
        ]);

        $user = $request->user();
        $user->update([
            'device_token' => $validated['device_token'],
            'device_platform' => $validated['platform'] ?? 'android',
        ]);

        return $this->successResponse([
            'device_token' => $user->device_token,
            'device_platform' => $user->device_platform,
        ], 'Device token registered successfully for push notifications.');
    }
}
