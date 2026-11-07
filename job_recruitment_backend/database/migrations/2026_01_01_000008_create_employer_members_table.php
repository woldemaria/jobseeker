<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        Schema::create('employer_members', function (Blueprint $table) {
            $table->id();
            $table->foreignId('employer_id')->constrained('employers')->onDelete('cascade');
            $table->foreignId('user_id')->constrained('users')->onDelete('restrict');
            $table->string('member_role', 50)->default('recruiter');
            $table->timestamps();
            $table->unique(['employer_id', 'user_id'], 'uq_employer_member');
        });
    }

    public function down(): void {
        Schema::dropIfExists('employer_members');
    }
};