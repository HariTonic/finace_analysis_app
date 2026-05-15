# SMS Transaction Extraction - Implementation Guide

## Overview
The SMS transaction extraction feature allows users to import transactions from text messages (SMS/WhatsApp banking notifications) directly into the MoneyFlow app. The system automatically:
- Extracts transaction amounts
- Categorizes transactions intelligently
- Detects and prevents duplicate imports
- Maintains import history

---

## How to Use

### 1. **Extract Transactions from SMS**
- Open MoneyFlow app and go to Home screen
- Scroll down to find the **"Extract from SMS"** button (blue button with SMS icon)
- Tap the button to open the SMS Extraction screen

### 2. **Paste SMS Messages**
- In the extraction screen, paste your SMS messages in the text field
- You can paste:
  - Multiple messages (one per line)
  - Bank notifications with transaction details
  - WhatsApp/Telegram forwarded banking messages
- Example format:
  ```
  Bank has debited Rs 500 from your account for shopping
  Payment of Rs 1000 received from client
  Electricity bill of Rs 2500 charged to your account
  ```

### 3. **Parse Messages**
- Tap **"Parse SMS Messages"** button
- The app will:
  - Extract amounts from messages
  - Auto-detect transaction types (income/expense)
  - Assign categories based on keywords
  - Filter out duplicate transactions
- Successfully parsed transactions will appear in a list

### 4. **Review & Select Transactions**
- Each transaction shows:
  - Category (auto-detected)
  - Transaction type (INCOME/EXPENSE)
  - Amount
- Use checkboxes to select which transactions to import
- All are selected by default

### 5. **Import Transactions**
- Tap **"Import Selected Transactions"** button
- Transactions are added to your account
- A success message shows how many were imported
- App automatically returns to Home screen

---

## Smart Features

### Automatic Category Detection
The parser recognizes keywords and assigns categories:

| Keywords | Category |
|----------|----------|
| pizza, restaurant, cafe, burger | Food |
| grocery, supermarket, mart | Groceries |
| uber, taxi, petrol, fuel, parking | Transport |
| flight, hotel, ticket, booking | Travel |
| amazon, flipkart, mall, shop | Shopping |
| electricity, water, internet, bill | Utilities |
| movie, cinema, gaming, concert | Entertainment |
| hospital, doctor, pharmacy | Healthcare |
| stock, mutual, invest | Investment |

### Automatic Type Detection
- **EXPENSE**: Messages with "debit", "spent", "charged", "payment", "withdraw"
- **INCOME**: Messages with "credit", "received", "deposit", "salary", "transfer"

### Duplicate Prevention
- System checks for duplicates based on:
  - **Same Amount** (exact match)
  - **Same Type** (income/expense)
  - **Same Category** (category match)
  - **Same Date** (within 1 hour)
- Skipped duplicates are shown in warning message
- Import history tracks all imports to prevent re-imports

### Amount Extraction
Recognizes multiple formats:
- Rs 500 or Rs500
- ₹500
- 500.00
- 500,000.00 (with commas)

---

## Android Permissions

The app requires SMS reading permission:
- **Android Permission**: `android.permission.READ_SMS`
- Already added to AndroidManifest.xml
- User will be prompted on first extraction attempt
- Permission can be modified in Android Settings

---

## Import History

The system maintains a complete import history:
- Access via `ImportHistoryManager` class
- Tracks:
  - Date and time of import
  - Number of transactions imported
  - Source (SMS, CSV, manual, etc.)
  - Transaction IDs
  - Number of duplicates skipped

---

## Technical Details

### File Structure
```
lib/
├── utils/
│   ├── sms_service.dart              # SMS permission & message handling
│   ├── transaction_parser.dart        # Smart parsing logic
│   └── import_history.dart            # Import tracking
│
├── screens/
│   ├── home_screen.dart               # Updated with extraction button
│   └── sms_extraction_screen.dart     # Full extraction UI
│
└── main.dart                          # Added routes & initialization
```

### Key Classes

#### SmsService
- `requestSmsPermission()` - Request user permission
- `hasSmsPermission()` - Check if permission granted
- `parseSmsText()` - Parse raw SMS text into messages

#### TransactionParser
- `extractAmount()` - Extract amount from message
- `determineType()` - Classify as income/expense
- `determineCategory()` - Assign category
- `parseSms()` - Complete parsing
- `isDuplicate()` - Check for duplicates

#### ImportHistoryManager
- `initialize()` - Setup Hive storage
- `addImportRecord()` - Log import
- `getImportRecords()` - View history
- `getTotalImportedCount()` - Statistics

---

## Build & Deploy

### 1. Generate Hive Adapters
```bash
flutter pub run build_runner build
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Run App
```bash
flutter run
```

---

## Future Enhancements

Potential improvements:
1. **Native SMS Reading**: Directly read device SMS inbox (requires Kotlin/Swift code)
2. **Auto-Sync**: Periodic automatic sync from SMS inbox
3. **SMS Rules**: Custom regex patterns for specific banks
4. **Scheduled Import**: Background SMS monitoring
5. **Bank Parsing**: Pre-configured rules for major banks
6. **CSV Import**: Similar extraction for CSV files
7. **Webhook Integration**: Direct bank API integration

---

## Troubleshooting

### No transactions parsed?
- Ensure messages have clear amount and type indicators
- Check if amounts are recognized format (Rs, ₹, $)
- Review message content for keywords

### Duplicates being skipped?
- System prevents re-importing same transaction twice
- Check import history to verify previous imports
- Clear old history if needed via `ImportHistoryManager.clearOldRecords()`

### Permission denied?
- Go to Settings → Apps → MoneyFlow → Permissions → SMS
- Grant "Allow" for SMS reading
- Restart app

---

## Example SMS Messages

```
✅ Bank has debited Rs 500 from your account for shopping

✅ Payment of Rs 1000 received for project work

✅ Electricity bill of Rs 2500 charged successfully

✅ Coffee shop charged ₹350 to your credit card

✅ Salary credited: Rs 50,000 to your account

✅ Uber charged 450 for trip

✅ Amazon purchase of Rs 2,999 confirmed
```

---

## Support

For issues or enhancements, refer to:
- **Code**: Check sms_extraction_screen.dart for UI logic
- **Parsing**: See transaction_parser.dart for parsing rules
- **History**: Use ImportHistoryManager for tracking issues
