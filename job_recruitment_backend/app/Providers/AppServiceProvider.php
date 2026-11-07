<?php

namespace App\Providers;

use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        // SQLite performance pragmas applied on connection
        if (config('database.default') === 'sqlite') {
            try {
                if (!app()->runningInConsole() || app()->runningUnitTests()) {
                    \Illuminate\Support\Facades\DB::connection()->getPdo()->exec('PRAGMA synchronous = NORMAL;');
                    \Illuminate\Support\Facades\DB::connection()->getPdo()->exec('PRAGMA temp_store = MEMORY;');
                }
            } catch (\Throwable $e) {}
        }
    }
}
