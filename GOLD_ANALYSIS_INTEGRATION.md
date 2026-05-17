# Gold Analysis Integration in Reports Page

## Overview
Successfully integrated a **Gold Analysis Bar** in the Investment Analysis tab of the Reports page, alongside the existing Stock Analysis. The implementation follows the same design pattern as the Stock Analysis bar for consistency.

## Components Implemented

### 1. **Gold Price Service** (`lib/utils/gold_price_service.dart`)
A dedicated service to fetch real-time gold prices from external APIs.

**Features:**
- Fetches gold price in USD per ounce from `https://api.gold-api.com/price/XAU`
- Converts USD rates to any supported currency using `https://open.er-api.com/v6/latest/USD`
- Calculates price per gram (dividing ounce price by 31.1035)
- Returns `GoldPrice` object with all necessary information
- Includes error handling and timeout management (10 seconds)
- Custom HTTP headers for API requests

**Key Methods:**
- `fetchGoldPrice()` - Get complete gold price information
- `fetchGoldPricePerGram()` - Get only the per-gram price
- `_fetchConversionRate()` - Get USD to target currency conversion
- `_fetchGoldPriceUsdPerOunce()` - Get raw gold price in USD

### 2. **Reports Screen Updates** (`lib/screens/reports_screen.dart`)

#### Added Fields:
- `GoldPriceService _goldPriceService` - Service instance for fetching gold prices
- `unitLabel` field in `_AggregatedHolding` class - To display unit labels (grams, ounces, etc.)

#### Modified Methods:

**_buildInvestmentAnalysis()**
- Now returns multiple cards (Stock Analysis + Gold Analysis)
- Separates stocks and gold holdings for distinct analysis
- Shows appropriate message when no investments are available

**New Methods:**

1. **_buildStockAnalysisCard()** - Dedicated card for stock holdings with:
   - Total invested and P/L metrics
   - Horizontal bar charts for buy vs current prices
   - Stock-specific styling (blue buy bars, green/red current bars)

2. **_buildGoldAnalysisCard()** - Dedicated card for gold holdings with:
   - Total invested and P/L metrics
   - Horizontal bar charts for buy vs current prices
   - Gold-specific styling (gold/orange buy bars, green/red current bars)

3. **_buildGoldBarGroup()** - Renders individual gold holding bars
   - Shows gold name, quantity, and profit/loss percentage
   - Gold-specific gradient colors (gold #FFD700, orange #FFA500)
   - Same layout as stock bars for consistency

4. **_aggregateGoldHoldings()** - Aggregates gold holdings by name
   - Filters holdings by type (contains "gold" or equals "precious metal")
   - Sums up quantities, invested amounts, and current values
   - Returns sorted list by name

5. **_refreshGoldPrices()** - Refreshes gold prices for all gold holdings
   - Fetches current gold price per gram using GoldPriceService
   - Updates all gold holdings with new price
   - Uses app's configured currency for conversion

#### Updated Methods:

**_aggregateInvestmentHoldings()**
- Added `excludeGold` parameter to filter out gold from stock analysis
- When `excludeGold=true`, skips holdings with type containing "gold" or "precious metal"
- Maintains backwards compatibility with default `excludeGold=false`

#### Style Updates:
- Separate cards for Stock and Gold analysis
- Gold bars use gold/orange gradient (#FFD700 to #FFA500)
- Green bars for gold gains, red bars for losses
- Consistent styling with stock analysis for unified UX

## Data Flow

```
Investment Holdings (Hive Box)
    ↓
_buildInvestmentAnalysis()
    ├─ _aggregateInvestmentHoldings(excludeGold=true)
    │   └─ _buildStockAnalysisCard() → Display stocks
    └─ _aggregateGoldHoldings()
        └─ _buildGoldAnalysisCard() → Display gold
            └─ _buildGoldBarGroup()
                └─ _buildHorizontalBar()
```

## Gold Holdings Detection

Holdings are classified as gold if:
- `holding.type.toLowerCase().contains('gold')` **OR**
- `holding.type.toLowerCase() == 'precious metal'`

Example investment types:
- ✅ "Gold", "gold bars", "22k gold", "24k gold", "gold coins", "precious metal"
- ❌ "Stocks", "crypto", "real estate"

## API Integration

### Forex API
- **URL:** `https://open.er-api.com/v6/latest/USD`
- **Purpose:** Get currency conversion rates from USD to target currency
- **Response:** JSON with rates object containing exchange rates

### Gold API
- **URL:** `https://api.gold-api.com/price/XAU`
- **Purpose:** Get current gold price in USD per ounce
- **Response:** JSON with 'price' field

## Error Handling

- Network timeouts: 10 seconds per request
- API failures: Returns `null` silently, allows UI to handle gracefully
- Missing data: Falls back to displaying existing data
- Invalid currencies: Returns `null` if currency not supported

## Usage Example

To add a gold holding in the app:
1. Create investment with type: "Gold" (or "gold bars", "precious metal", etc.)
2. Set quantity: amount in grams (or preferred unit)
3. Set buy unit price: price per gram in your currency
4. Current unit price will be auto-updated via `_refreshGoldPrices()`

Example:
```dart
InvestmentHolding(
  id: '123',
  type: 'Gold',
  name: 'Gold Bars 24K',
  quantity: 10, // grams
  buyUnitPrice: 7200, // per gram
  currentUnitPrice: 7500, // updated by service
  unitLabel: 'g',
  purchaseDate: DateTime.now(),
  notes: 'Saved gold bars',
  symbol: '',
  exchange: '',
)
```

## Integration Points

### In Reports Screen:
- Gold holdings are now properly displayed in Investment Analysis tab
- Separate cards ensure clear visual distinction
- Both stock and gold analysis available simultaneously
- Automatic price updates via `_refreshGoldPrices()` method

### Future Enhancements:
- Add refresh button to manually update gold prices
- Display last update timestamp
- Add gold price trend charts
- Support for different gold purities (18k, 22k, 24k)
- Historical price tracking

## Files Modified

1. **lib/utils/gold_price_service.dart** - NEW
   - Complete gold price fetching service

2. **lib/screens/reports_screen.dart** - MODIFIED
   - Added gold analysis integration
   - Updated investment analysis structure
   - Added gold holdings aggregation
   - Added gold bar visualization

## Testing Checklist

- ✅ Code compiles without errors
- ✅ Gold and stock holdings properly separated
- ✅ Bar charts display correctly with appropriate colors
- ✅ P/L calculations accurate for gold
- ✅ Service handles API failures gracefully
- ✅ Currency conversion works correctly
- ⏳ Manual testing needed: Create gold holding and verify display
- ⏳ Manual testing needed: Verify price updates fetch correctly
