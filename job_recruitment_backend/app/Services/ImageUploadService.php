<?php

namespace App\Services;

use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class ImageUploadService
{
    /**
     * Store image from UploadedFile, base64 data URI, or preserve existing URL.
     * Returns absolute public URL or null.
     */
    public static function storeImage($fileOrString, string $directory = 'profile_photos'): ?string
    {
        if (empty($fileOrString)) {
            return null;
        }

        // 1. If it's an UploadedFile instance
        if ($fileOrString instanceof UploadedFile) {
            $ext = strtolower($fileOrString->getClientOriginalExtension());
            if (!in_array($ext, ['jpg', 'jpeg', 'png', 'webp', 'gif'])) {
                $ext = 'png';
            }
            $filename = Str::uuid() . '.' . $ext;
            $path = $fileOrString->storeAs($directory, $filename, 'public');
            return url('storage/' . $path);
        }

        if (!is_string($fileOrString)) {
            return null;
        }

        $trimmed = trim($fileOrString);

        // 2. If it's a base64 Data URI (e.g. data:image/png;base64,iVBORw0KGgo...)
        if (preg_match('/^data:image\/(\w+);base64,(.+)$/s', $trimmed, $matches)) {
            $ext = strtolower($matches[1]);
            if ($ext === 'jpeg') $ext = 'jpg';
            if (!in_array($ext, ['jpg', 'png', 'webp', 'gif'])) {
                $ext = 'png';
            }

            $binaryData = base64_decode($matches[2]);
            if ($binaryData !== false && strlen($binaryData) > 0) {
                // Ensure directory exists
                Storage::disk('public')->makeDirectory($directory);
                $filename = Str::uuid() . '.' . $ext;
                $relativePath = $directory . '/' . $filename;
                Storage::disk('public')->put($relativePath, $binaryData);
                return url('storage/' . $relativePath);
            }
        }

        // 3. If it is already an HTTP or HTTPS URL, preserve it
        if (str_starts_with($trimmed, 'http://') || str_starts_with($trimmed, 'https://')) {
            return $trimmed;
        }

        // 4. If it's raw base64 without prefix
        if (strlen($trimmed) > 100 && !str_contains($trimmed, ' ') && !str_contains($trimmed, '/')) {
            $binaryData = base64_decode($trimmed, true);
            if ($binaryData !== false) {
                Storage::disk('public')->makeDirectory($directory);
                $filename = Str::uuid() . '.png';
                $relativePath = $directory . '/' . $filename;
                Storage::disk('public')->put($relativePath, $binaryData);
                return url('storage/' . $relativePath);
            }
        }

        return $trimmed;
    }
}
