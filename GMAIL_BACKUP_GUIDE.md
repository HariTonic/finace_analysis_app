# Gmail Backup Feature Documentation

## Overview

The Gmail Backup feature in MoneyFlow provides **WhatsApp-style backup functionality** for securely backing up and restoring your financial data using Gmail and Google Drive. This feature ensures your transactions, investments, and settings are always protected and recoverable.

## Features

### 1. **Dual Backup Options**
- **Google Drive Backup**: Secure encrypted backup stored in your Google Drive
- **Gmail Backup (WhatsApp-style)**: Backups sent as attachments to your Gmail inbox with email format

### 2. **Automatic Scheduling**
- **Never**: Manual backups only
- **Daily**: Automatic backup every day at 2:00 AM
- **Weekly**: Automatic backup every Sunday at 2:00 AM  
- **Monthly**: Automatic backup on the 1st of each month

### 3. **What Gets Backed Up**
- All transactions (income, expenses, investments)
- Investment holdings with current valuations
- Profile information (name, DOB, gender, occupation, photo)
- App settings (currency, spending limits, preferences)

### 4. **Easy Restore**
- Restore from Google Drive backup
- Restore from Gmail backup (list all available backups)
- One-click restore with confirmation

## How to Use

### Accessing Backup Features

1. **From Settings Screen**
   - Open the app and go to Settings
   - Look for "Backup & Restore" section
   - Choose from three options:
     - Back Up Data
     - Restore Data
     - Backup Settings

### Google Drive Backup

#### Create a Backup
1. Navigate to `Settings > Backup & Restore > Back Up Data`
2. Select the "Google Drive" tab
3. Tap "Back Up Now"
4. Sign in with your Google account if not already signed in
5. Confirmation message will appear when backup is complete

#### View Backup Status
- Last backup timestamp is displayed
- Account information is shown
- Connected status indicator

### Gmail Backup (WhatsApp-Style)

#### Create a Backup
1. Navigate to `Settings > Backup & Restore > Back Up Data`
2. Select the "Gmail (WhatsApp)" tab
3. Tap "Send Backup to Gmail"
4. Sign in with Gmail if not already signed in
5. Backup is sent as email attachment with timestamp
6. Check your Gmail inbox for backup confirmation

#### Advantages
- **Easy accessibility**: Backups visible in Gmail inbox
- **Email notifications**: You receive confirmation emails
- **Mobile-friendly**: Access backups from any Gmail-enabled device
- **Automatic archiving**: Keep historical backups in Gmail

### Automatic Backup Scheduling

#### Configure Scheduled Backups
1. Navigate to `Settings > Backup & Restore > Backup Settings`
2. Select your preferred backup frequency:
   - **Daily**: Every day at 2:00 AM
   - **Weekly**: Every Sunday at 2:00 AM
   - **Monthly**: 1st of each month at 2:00 AM
3. Settings are saved automatically

#### Schedule Requirements
- Internet connection required
- Google account must be authenticated
- Device must be on or connected periodically

### Restore Data

#### From Google Drive
1. Navigate to `Settings > Backup & Restore > Restore Data`
2. Select "Google Drive" tab
3. Sign in if needed (use the same Google account)
4. Tap "Restore from Google Drive"
5. Confirm the restore action
6. All data will be replaced with backup

#### From Gmail
1. Navigate to `Settings > Backup & Restore > Restore Data`
2. Select "Gmail" tab
3. Sign in if needed
4. View all available Gmail backups with timestamps
5. Select backup to restore
6. Confirm the restore action
7. Backup data will be restored

## Security & Privacy

### Data Protection
- ✅ Data encrypted by Google (Drive/Gmail)
- ✅ Stored in your personal Google account
- ✅ Private app data folder on Google Drive
- ✅ No third-party access to backups

### Account Security
- Authentication via Google Sign-In
- Secure OAuth 2.0 authentication
- Session tokens refreshed automatically
- Sign out option available anytime

### Backup Format
- JSON format with encryption at Google level
- Includes version information for compatibility
- Timestamped for easy identification
- Size information for backup management

## Backup Settings Details

### Google Drive
- **Storage**: Encrypted in app data folder
- **Scope**: Private to your account
- **Accessibility**: Via Google Drive or app

### Gmail
- **Storage**: Email attachments in your inbox
- **Subject**: `[MoneyFlow Backup] YYYY-MM-DD HH:MM:SS`
- **Size**: Typically 10-500 KB
- **Attachment**: `moneyflow_backup_[timestamp].json`

## Troubleshooting

### Backup Fails
1. Check internet connection
2. Verify Google account is active
3. Ensure sufficient Google Drive/Gmail storage
4. Try signing out and signing in again

### Can't Restore
1. Verify backup file exists
2. Use the same Google account
3. Check backup wasn't deleted from Gmail/Drive
4. Ensure sufficient device storage

### Automatic Backups Not Running
1. Verify scheduling is enabled in Backup Settings
2. Check internet connectivity
3. Ensure app has permission to access Google account
4. Check system time is correct

### Gmail Backups Not Appearing
1. Check email filters (may be in spam/archive)
2. Verify Gmail storage quota
3. Try creating manual backup first
4. Check authentication in Gmail tab

## Best Practices

1. **Regular Backups**
   - Create manual backup weekly
   - Or enable automatic daily backups

2. **Multiple Backup Locations**
   - Use both Google Drive and Gmail
   - Provides redundancy

3. **Account Safety**
   - Use strong Google account password
   - Enable 2-factor authentication on Google account
   - Regularly review connected apps

4. **Storage Management**
   - Monitor Google Drive quota
   - Archive old Gmail backups to folders
   - Clean up before quota limits

5. **Testing Restores**
   - Periodically test restore functionality
   - Verify data integrity after restore
   - Keep backup on new device installation

## Data Consistency

### Before Restore
- Current data will be completely replaced
- No merge or selective restore available
- Backup should be recent for accurate restore

### After Restore
- All transactions imported
- Profile data updated
- Settings applied
- Investment data restored

## API Integration

### Gmail API Scopes Required
- `https://mail.google.com/` - Full Gmail access
- `email` - Email retrieval
- `profile` - Profile information

### Google Drive API Scopes
- `drive.appdata` - App data folder access
- `email` - Email retrieval
- `profile` - Profile information

## Version Information

- **Backup Version**: 1 (compatible with future versions)
- **Created**: ISO 8601 timestamp
- **Compatible With**: MoneyFlow v1.0+

## Future Enhancements

- Incremental backups (backup only changed data)
- Backup encryption with password
- Cloud sync (real-time backup)
- Multi-account backup
- Backup verification tool
- Scheduled automatic cleanup

## Support

For issues or questions about the backup feature:
1. Check Backup Settings > Storage & Security info
2. Review troubleshooting section above
3. Ensure Google account has necessary permissions
4. Try creating manual backup as test

---

**Last Updated**: May 2026
**Feature**: Gmail & Google Drive Backup
**Status**: Active & Maintained
