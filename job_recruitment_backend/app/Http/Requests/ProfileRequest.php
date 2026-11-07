<?php

namespace App\Http\Requests;

use Illuminate\Contracts\Validation\Validator;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Http\Exceptions\HttpResponseException;

class ProfileRequest extends FormRequest
{
    /**
     * Determine if the user is authorized to make this request.
     */
    public function authorize(): bool
    {
        return $this->user() !== null;
    }

    /**
     * Get the validation rules that apply to the request.
     *
     * @return array<string, \Illuminate\Contracts\Validation\ValidationRule|array<mixed>|string>
     */
    public function rules(): array
    {
        return [
            'name' => 'sometimes|string|min:2|max:150',
            'phone' => ['nullable', 'string', 'max:30', 'regex:/^[0-9\+\-\s\(\)]+$/'],
            'profile_photo' => 'nullable|string',
            'profile_photo_file' => 'nullable|file|mimes:jpeg,jpg,png,webp,gif|max:5120',
            'photo' => 'nullable',
            'file' => 'nullable',
            'date_of_birth' => 'nullable|date|before:today',
            'gender' => 'nullable|string|in:male,female,other,Male,Female,Other',
            'education_level' => 'nullable|string|max:100',
            'field_of_study' => 'nullable|string|max:150',
            'preferred_job_title' => 'nullable|string|max:200',
            'preferred_category_id' => 'nullable|integer|exists:job_categories,id',
            'experience_years' => 'nullable|numeric|min:0|max:60',
            'location' => 'nullable|string|max:150',
            'biography' => 'nullable|string|max:5000',
        ];
    }

    /**
     * Custom friendly validation error messages.
     */
    public function messages(): array
    {
        return [
            'name.min' => 'Full name must contain at least 2 characters.',
            'name.max' => 'Full name cannot exceed 150 characters.',
            'phone.regex' => 'Please provide a valid phone number (e.g., +251911223344).',
            'date_of_birth.before' => 'Date of birth must be a valid date in the past.',
            'gender.in' => 'Gender must be either male, female, or other.',
            'experience_years.numeric' => 'Experience years must be a valid numeric value.',
            'experience_years.min' => 'Experience years cannot be negative.',
            'experience_years.max' => 'Experience years cannot exceed 60 years.',
            'biography.max' => 'Biography cannot exceed 5000 characters.',
        ];
    }

    /**
     * Handle failed validation to return standardized JSON error response.
     */
    protected function failedValidation(Validator $validator)
    {
        throw new HttpResponseException(response()->json([
            'success' => false,
            'message' => 'The profile details provided are invalid.',
            'data' => null,
            'errors' => $validator->errors(),
        ], 422));
    }
}
