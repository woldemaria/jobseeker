<?php

namespace App\Services;

use App\Models\Document;
use App\Models\User;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class DocumentService
{
    protected array $allowedTypes = ['cv', 'certificate', 'transcript', 'verification', 'other'];
    protected array $allowedExtensions = ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png', 'webp'];

    /**
     * Store uploaded document with randomized name in private storage.
     */
    public function uploadDocument(User $user, UploadedFile $file, string $documentType): Document
    {
        if (!in_array($documentType, $this->allowedTypes)) {
            throw ValidationException::withMessages(['document_type' => ['Invalid document type.']]);
        }

        $extension = strtolower($file->getClientOriginalExtension());
        if (empty($extension)) {
            $mime = strtolower($file->getClientMimeType() ?: '');
            if (str_contains($mime, 'pdf')) $extension = 'pdf';
            elseif (str_contains($mime, 'wordprocessingml') || str_contains($mime, 'docx')) $extension = 'docx';
            elseif (str_contains($mime, 'msword') || str_contains($mime, 'doc')) $extension = 'doc';
            elseif (str_contains($mime, 'png')) $extension = 'png';
            elseif (str_contains($mime, 'jpeg') || str_contains($mime, 'jpg')) $extension = 'jpg';
            else $extension = 'pdf';
        }

        if (!in_array($extension, $this->allowedExtensions)) {
            throw ValidationException::withMessages(['file' => ['Only PDF, DOC, DOCX, and image documents (JPG/PNG) are permitted.']]);
        }

        // 10 MB maximum
        if ($file->getSize() > 10 * 1024 * 1024) {
            throw ValidationException::withMessages(['file' => ['File size cannot exceed 10 MB.']]);
        }

        $filename = Str::uuid() . '.' . $extension;
        Storage::disk('private')->makeDirectory('documents/' . $user->id);
        $path = $file->storeAs('documents/' . $user->id, $filename, 'private');

        return Document::create([
            'user_id' => $user->id,
            'original_name' => $file->getClientOriginalName() ?: ($filename),
            'storage_path' => $path,
            'mime_type' => $file->getClientMimeType() ?: 'application/pdf',
            'file_size' => $file->getSize(),
            'document_type' => $documentType,
        ]);
    }

    /**
     * Store document from raw binary bytes or base64 string.
     */
    public function uploadDocumentData(User $user, string $originalName, string $binaryOrBase64, string $documentType, ?string $mimeType = null): Document
    {
        if (!in_array($documentType, $this->allowedTypes)) {
            throw ValidationException::withMessages(['document_type' => ['Invalid document type.']]);
        }

        $data = $binaryOrBase64;
        if (preg_match('/^data:([a-zA-Z0-9\/\-\.]+);base64,(.+)$/s', $binaryOrBase64, $matches)) {
            $mimeType = $mimeType ?: $matches[1];
            $data = base64_decode($matches[2]);
        } elseif (strlen($binaryOrBase64) > 100 && !str_contains($binaryOrBase64, ' ') && preg_match('/^[a-zA-Z0-9\/\r\n+]+=*$/', substr($binaryOrBase64, 0, 100))) {
            $decoded = base64_decode($binaryOrBase64, true);
            if ($decoded !== false) {
                $data = $decoded;
            }
        }

        $extension = strtolower(pathinfo($originalName, PATHINFO_EXTENSION));
        if (empty($extension)) {
            if ($mimeType && str_contains($mimeType, 'pdf')) $extension = 'pdf';
            elseif ($mimeType && str_contains($mimeType, 'docx')) $extension = 'docx';
            elseif ($mimeType && str_contains($mimeType, 'doc')) $extension = 'doc';
            elseif ($mimeType && str_contains($mimeType, 'png')) $extension = 'png';
            elseif ($mimeType && (str_contains($mimeType, 'jpeg') || str_contains($mimeType, 'jpg'))) $extension = 'jpg';
            else $extension = 'pdf';
            $originalName .= '.' . $extension;
        }

        if (!in_array($extension, $this->allowedExtensions)) {
            throw ValidationException::withMessages(['file' => ['Only PDF, DOC, DOCX, and image documents (JPG/PNG) are permitted.']]);
        }

        $size = strlen($data);
        if ($size > 10 * 1024 * 1024) {
            throw ValidationException::withMessages(['file' => ['File size cannot exceed 10 MB.']]);
        }

        $filename = Str::uuid() . '.' . $extension;
        Storage::disk('private')->makeDirectory('documents/' . $user->id);
        $relativePath = 'documents/' . $user->id . '/' . $filename;
        Storage::disk('private')->put($relativePath, $data);

        return Document::create([
            'user_id' => $user->id,
            'original_name' => $originalName,
            'storage_path' => $relativePath,
            'mime_type' => $mimeType ?: 'application/octet-stream',
            'file_size' => $size,
            'document_type' => $documentType,
        ]);
    }
}
