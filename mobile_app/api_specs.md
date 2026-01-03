
# API Specifications for Linguistic Analysis & Lucky Numbers

## 1. Linguistic Analysis (Solar System)

**Endpoint:** `GET /api/analyze`

**Parameters:**
- `name` (required): The Thai name to analyze (e.g., "สมชาย").
- `day` (optional): The day of birth in English (e.g., "monday", "thursday"). Defaults to "thursday".
- `section` (optional): Set to `solar` to get only the necessary data for this view.

**Response (JSON):**

```json
{
  "solar_system": {
    "cleaned_name": "สมชาย",
    "input_day": "วันพฤหัสบดี",
    "sun_display_name_html": [
      { "char": "ส", "is_bad": false },
      { "char": "ม", "is_bad": false },
      { "char": "ช", "is_bad": true }, 
      { "char": "า", "is_bad": false },
      { "char": "ย", "is_bad": false }
    ],
    "numerology_pairs": [
      { "pair_number": "15", "meaning": { "color": "#2E7D32", "pair_type": "D10", "miracle_desc": "..." } },
      { "pair_number": "59", "meaning": { ... } }
    ],
    "shadow_pairs": [
      { "pair_number": "64", "meaning": { ... } }
    ],
    "grand_total_score": 95,
    "category_breakdown": {
      "การงาน": {
        "good": 1,
        "bad": 0,
        "color": "#4158D0",
        "keywords": ["งานศิลป์", "มองโลกแง่ดี", "รอบรู้"]
      },
      "การเงิน": {
        "good": 2,
        "bad": 0,
        "color": "#FB8C00",
        "keywords": ["เงินคล่อง", "เพื่อนมาก", "เมตตามหานิยม"]
      },
      "ความรัก": {
        "good": 0,
        "bad": 1,
        "color": "#D4145A",
        "keywords": ["รักซ้อน"]
      },
      "สุขภาพ": {
        "good": 0,
        "bad": 0,
        "color": "#00DBDE",
        "keywords": []
      }
    }
  },
  "is_vip": false
}
```

### Calculations for UI

To render the UI shown in the design, the Flutter app must calculate the following:

1.  **Total Pairs Count** (`N`):
    ```dart
    int totalPairs = (data['solar_system']['numerology_pairs'] as List).length +
                     (data['solar_system']['shadow_pairs'] as List).length;
    ```
    *If `totalPairs` is 0, handle division by zero.*

2.  **Category Percentages**:
    For each category (e.g., "การงาน"):
    ```dart
    var catParams = data['solar_system']['category_breakdown']['การงาน'];
    double goodPercent = (catParams['good'] / totalPairs) * 100;
    double badPercent = (catParams['bad'] / totalPairs) * 100;
    ```

3.  **Total Score % (Bottom Banner)**:
    ```dart
    int totalGood = 0;
    int totalBad = 0;
    ['การงาน', 'การเงิน', 'ความรัก', 'สุขภาพ'].forEach((cat) {
      totalGood += data['solar_system']['category_breakdown'][cat]['good'];
      totalBad += data['solar_system']['category_breakdown'][cat]['bad'];
    });
    
    double totalPercent = ((totalGood - totalBad) / totalPairs) * 100;
    ```

---

## 2. Get Lucky Number (Supplement)

**Endpoint:** `GET /api/lucky-number`

**Parameters:**
- `category` (required): The category name in Thai (e.g., "การงาน", "การเงิน", "ความรัก", "สุขภาพ").

**Response (JSON):**

```json
{
  "number": "151",
  "keywords": ["ผู้ใหญ่เมตตา", "สติปัญญา", "ความสำเร็จ"]
}
```

**Usage:**
- Call this API when the user taps on the "เสริมเบอร์ 100% ✨" button for a specific category.
- Show a modal or popup displaying the returned `number` and `keywords`.
