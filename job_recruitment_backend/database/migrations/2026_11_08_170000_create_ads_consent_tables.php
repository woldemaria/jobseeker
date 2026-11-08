<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('ads_consents', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->nullable()->unique()->constrained('users')->cascadeOnDelete();
            $table->string('consent_uuid', 64)->unique();
            $table->string('status', 20)->default('custom'); // accepted, rejected, custom, withdrawn
            $table->boolean('personalized_ads')->default(false);
            $table->boolean('non_personalized_ads')->default(false);
            $table->boolean('analytics')->default(false);
            $table->boolean('advertising_cookies')->default(false);
            $table->string('policy_version', 20)->default('1.0');
            $table->string('ip_address', 45)->nullable();
            $table->text('user_agent')->nullable();
            $table->timestamp('consented_at')->nullable();
            $table->timestamp('withdrawn_at')->nullable();
            $table->timestamps();

            $table->index(['consent_uuid', 'status']);
        });

        Schema::create('ads_consent_histories', function (Blueprint $table) {
            $table->id();
            $table->foreignId('ads_consent_id')->constrained('ads_consents')->cascadeOnDelete();
            $table->foreignId('user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('action', 30); // grant, update, withdraw, renew, link_account
            $table->string('policy_version', 20)->default('1.0');
            $table->string('status', 20);
            $table->json('preferences');
            $table->string('ip_address', 45)->nullable();
            $table->text('user_agent')->nullable();
            $table->timestamp('created_at')->useCurrent();

            $table->index(['ads_consent_id', 'action']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('ads_consent_histories');
        Schema::dropIfExists('ads_consents');
    }
};
