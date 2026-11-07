<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        Schema::create('employers', function (Blueprint $table) {
            $table->id();
            $table->string('organization_name', 200);
            $table->string('organization_type', 100)->nullable();
            $table->string('registration_number', 100)->nullable();
            $table->string('email', 150)->nullable();
            $table->string('phone', 30)->nullable();
            $table->string('website', 255)->nullable();
            $table->text('address')->nullable();
            $table->string('verification_status', 30)->default('pending');
            $table->timestamps();
        });
    }

    public function down(): void {
        Schema::dropIfExists('employers');
    }
};