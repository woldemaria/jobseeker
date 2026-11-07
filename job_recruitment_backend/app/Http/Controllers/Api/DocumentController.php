<?php

namespace App\Http\Controllers\Api;

use App\Models\Application;
use App\Models\Document;
use App\Services\DocumentService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpFoundation\StreamedResponse;

class DocumentController extends BaseApiController
{
    public function __construct(
        protected DocumentService $documentService
    ) {}

    public function index(Request $request): JsonResponse
    {
        $docs = Document::where('user_id', $request->user()->id)
            ->latest()
            ->get();

        return $this->successResponse($docs, 'Documents retrieved successfully.');
    }

    public function store(Request $request): JsonResponse
    {
        $request->validate([
            'file' => 'nullable|file|max:10240', // 10MB
            'file_base64' => 'nullable|string',
            'file_name' => 'nullable|string',
            'document_type' => 'required|string|in:cv,certificate,transcript,verification,other',
        ]);

        if ($request->hasFile('file')) {
            $document = $this->documentService->uploadDocument(
                $request->user(),
                $request->file('file'),
                $request->input('document_type')
            );
        } elseif ($request->filled('file_base64')) {
            $fileName = $request->input('file_name', 'document.pdf');
            $document = $this->documentService->uploadDocumentData(
                $request->user(),
                $fileName,
                $request->input('file_base64'),
                $request->input('document_type')
            );
        } else {
            return $this->errorResponse('Please provide a file or base64 file data to upload.', 422);
        }

        return $this->successResponse($document, 'Document uploaded successfully.', 201);
    }

    public function show(Request $request, int $id): JsonResponse
    {
        $doc = Document::findOrFail($id);
        $user = $request->user();

        // RBAC authorization
        $isOwner = $doc->user_id === $user->id;
        $isAdmin = $user->isAdmin();
        $isReviewingEmployer = false;

        if ($user->isEmployer() && $user->employers()->exists()) {
            $employerIds = $user->employers()->pluck('employers.id')->toArray();
            $isReviewingEmployer = Application::where('cv_document_id', $doc->id)
                ->whereHas('job', fn($q) => $q->whereIn('employer_id', $employerIds))
                ->exists();
        }

        if (!$isOwner && !$isAdmin && !$isReviewingEmployer) {
            return $this->errorResponse('Access denied. You do not have permission to view this document.', 403);
        }

        return $this->successResponse($doc, 'Document retrieved successfully.');
    }

    private function resolveUserFromRequestOrQuery(Request $request)
    {
        $user = $request->user() ?: auth('sanctum')->user();
        if (!$user && $request->filled('token')) {
            $tokenModel = \Laravel\Sanctum\PersonalAccessToken::findToken($request->query('token'));
            if ($tokenModel) {
                $user = $tokenModel->tokenable;
            }
        }
        return $user;
    }

    public function download(Request $request, int $id): Response
    {
        $doc = Document::findOrFail($id);
        $user = $this->resolveUserFromRequestOrQuery($request);

        if (!$user) {
            return $this->errorResponse('Unauthenticated.', 401);
        }

        // RBAC authorization
        $isOwner = $doc->user_id === $user->id;
        $isAdmin = $user->isAdmin();
        $isReviewingEmployer = false;

        if ($user->isEmployer() && $user->employers()->exists()) {
            $employerIds = $user->employers()->pluck('employers.id')->toArray();
            $isReviewingEmployer = Application::where('cv_document_id', $doc->id)
                ->whereHas('job', fn($q) => $q->whereIn('employer_id', $employerIds))
                ->exists();
        }

        if (!$isOwner && !$isAdmin && !$isReviewingEmployer) {
            return $this->errorResponse('Access denied. You do not have permission to download this document.', 403);
        }

        $disk = Storage::disk('private')->exists($doc->storage_path) ? 'private' : 'local';
        if (!Storage::disk($disk)->exists($doc->storage_path)) {
            return $this->errorResponse('File not found in storage.', 404);
        }

        $headers = [
            'Content-Type' => $doc->mime_type ?: 'application/octet-stream',
        ];

        if ($request->boolean('inline') || $request->query('view') === '1') {
            $headers['Content-Disposition'] = 'inline; filename="' . $doc->original_name . '"';
            return response()->file(Storage::disk($disk)->path($doc->storage_path), $headers);
        }

        return Storage::disk($disk)->download($doc->storage_path, $doc->original_name);
    }

    public function destroy(Request $request, int $id): JsonResponse
    {
        $doc = Document::where('user_id', $request->user()->id)->findOrFail($id);

        $disk = Storage::disk('private')->exists($doc->storage_path) ? 'private' : 'local';
        Storage::disk($disk)->delete($doc->storage_path);

        $doc->delete();

        return $this->successResponse(null, 'Document deleted successfully.');
    }
}
