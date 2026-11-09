<?php

namespace App\Services;

class EthiopianLocationService
{
    /**
     * Complete Ethiopian Administrative & Metropolitan Hierarchy.
     */
    public static function getTargetingHierarchy(): array
    {
        return [
            [
                'name' => 'All Ethiopia',
                'code' => 'ET-ALL',
                'type' => 'nationwide',
                'description' => 'Target audiences across all 12 regional states and 2 chartered cities',
            ],
            [
                'name' => 'Addis Ababa',
                'code' => 'ET-AA',
                'type' => 'chartered_city',
                'subcities' => [
                    'Bole',
                    'Kirkos',
                    'Yeka',
                    'Arada',
                    'Lideta',
                    'Akaki Kality',
                    'Kolfe Keranio',
                    'Gulele',
                    'Nifas Silk-Lafto',
                    'Addis Ketema',
                    'Lemi Kura',
                ],
            ],
            [
                'name' => 'Dire Dawa',
                'code' => 'ET-DD',
                'type' => 'chartered_city',
                'subcities' => ['Sabian', 'Gende Kore', 'Melka Jebdu'],
            ],
            [
                'name' => 'Oromia',
                'code' => 'ET-OR',
                'type' => 'region',
                'cities' => ['Adama', 'Bishoftu', 'Jimma', 'Shashemene', 'Ambo', 'Nekemte', 'Asella'],
            ],
            [
                'name' => 'Amhara',
                'code' => 'ET-AM',
                'type' => 'region',
                'cities' => ['Bahir Dar', 'Gondar', 'Dessie', 'Debre Birhan', 'Kombolcha'],
            ],
            [
                'name' => 'Sidama',
                'code' => 'ET-SI',
                'type' => 'region',
                'cities' => ['Hawassa', 'Yirgalem', 'Aleta Wendo'],
            ],
            [
                'name' => 'Tigray',
                'code' => 'ET-TI',
                'type' => 'region',
                'cities' => ['Mekelle', 'Adigrat', 'Shire', 'Axum'],
            ],
            [
                'name' => 'Southern Ethiopia',
                'code' => 'ET-SE',
                'type' => 'region',
                'cities' => ['Arba Minch', 'Wolaita Sodo', 'Dilla', 'Hosaena'],
            ],
            [
                'name' => 'Central Ethiopia',
                'code' => 'ET-CE',
                'type' => 'region',
                'cities' => ['Butajira', 'Worabe'],
            ],
            [
                'name' => 'South West Ethiopia',
                'code' => 'ET-SW',
                'type' => 'region',
                'cities' => ['Bonga', 'Mizan Teferi'],
            ],
            [
                'name' => 'Somali',
                'code' => 'ET-SO',
                'type' => 'region',
                'cities' => ['Jijiga', 'Gode', 'Degehabur'],
            ],
            [
                'name' => 'Harari',
                'code' => 'ET-HA',
                'type' => 'region',
                'cities' => ['Harar'],
            ],
            [
                'name' => 'Afar',
                'code' => 'ET-AF',
                'type' => 'region',
                'cities' => ['Semera', 'Awash', 'Asaita'],
            ],
            [
                'name' => 'Benishangul-Gumuz',
                'code' => 'ET-BE',
                'type' => 'region',
                'cities' => ['Asosa'],
            ],
            [
                'name' => 'Gambella',
                'code' => 'ET-GA',
                'type' => 'region',
                'cities' => ['Gambella'],
            ],
        ];
    }

    /**
     * Flattened array of all valid selectable locations in Ethiopia.
     */
    public static function getAllValidLocations(): array
    {
        $locations = ['All Ethiopia'];
        foreach (self::getTargetingHierarchy() as $item) {
            $locations[] = $item['name'];
            if (!empty($item['subcities'])) {
                foreach ($item['subcities'] as $sub) {
                    $locations[] = "{$item['name']} - {$sub}";
                    $locations[] = $sub;
                }
            }
            if (!empty($item['cities'])) {
                foreach ($item['cities'] as $city) {
                    $locations[] = "{$item['name']} - {$city}";
                    $locations[] = $city;
                }
            }
        }
        return array_values(array_unique($locations));
    }

    /**
     * Validate an array of location targets.
     */
    public static function validateLocations(array $targets): bool
    {
        if (empty($targets)) {
            return true;
        }

        $validList = array_map('strtolower', self::getAllValidLocations());
        foreach ($targets as $target) {
            if (!is_string($target)) {
                return false;
            }
            if (!in_array(strtolower(trim($target)), $validList)) {
                return false;
            }
        }

        return true;
    }
}
