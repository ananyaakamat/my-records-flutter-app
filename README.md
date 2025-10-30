# My Records - Personal Records Management App

A comprehensive Flutter application for organizing and managing personal documents, certificates, educational records, and other important information in a secure, folder-based system with automated backup capabilities.

## 🌟 Key Features

### 📂 Core Organization

- **Folder-Based Organization**: Create custom folders to categorize your records
- **� Customizable Folders**: Choose from multiple colors and icons for folder personalization
- **📊 Record Count Tracking**: Visual indicators showing number of records in each folder
- **🔄 Drag & Drop Reordering**: Organize folders by dragging them to preferred positions
### 📋 Bulk Operations**: Delete all folders and records with comprehensive safety warnings

### 🔍 Advanced Search & Navigation

- **Global Search**: Search across all folders and records with real-time results
- **Smart Filtering**: Filter search results by specific folders
- **Debounced Search**: Optimized search with 500ms delay for better performance
- **Search Result Context**: Shows which folder contains each found record

### 📅 Intelligent Date Processing

- **Dynamic Date Interpretation**: ✨ **NEW** - Automatic recognition of dates in 6+ different formats
- **Smart Age Calculation**: Calculates age from birth dates with years/months precision
- **Expiry Tracking**: Shows time remaining until document/certificate expiry
- **Multi-Format Support**: Handles numeric, text-based, and concatenated date formats
- **Visual Status Indicators**: Red "Expired" text for current date matches
- **Interactive Record Details**: Tap any record to see detailed information with date interpretation

### 🔐 Security & Authentication

- **PIN Protection**: 6-digit PIN for secure access to all data
- **Biometric Authentication**: Fingerprint support for quick access
- **Security Wrapper**: Seamless authentication flow with splash screen
- **Optimized Loading**: Eliminates blank screens during authentication and data loading

### 💾 Backup & Restore System

- **Automated Backups**: Daily or weekly automatic backups using WorkManager
- **Background Processing**: Backups run automatically in the background without device constraints
- **Manual Backup**: Create instant backups on demand (requires at least one folder)
- **Accurate Statistics**: ✨ **NEW** - Backup dialogs show precise record counts with automatic orphaned record cleanup
- **Data Integrity**: ✨ **NEW** - Automatic cleanup of orphaned records during backup creation
- **Smart File Management**: Automatically maintains 3 most recent backups
- **Cloud Compatibility**: JSON format backups saved to Downloads/my_records folder
- **One-Click Restore**: Select and restore from any previous backup
- **Backup Sharing**: Share backup files directly from the app

### 🎨 User Experience

- **🌙 Dark/Light Theme**: Default dark mode with toggle support for user preference
- **📱 Mobile-First Design**: Optimized for mobile devices with responsive UI
- **Consistent UI**: Professional design with Material 3 theming
- **Contextual Help**: Comprehensive help screens for all features
- **Progress Indicators**: Loading states and progress feedback throughout the app

## 🛠️ Tech Stack

- **Framework**: Flutter 3.24.3
- **Language**: Dart 3.5.3
- **Database**: SQLite with sqflite package for local storage
- **State Management**: Riverpod for reactive state management
- **Architecture**: Clean Architecture with feature-based organization
- **Background Processing**: WorkManager for automated backup tasks
- **Security**: Local Authentication (PIN + Biometric)
- **File Operations**: Path Provider, Share Plus for backup management
- **UI/UX**: Material 3 Design System with custom theming

## 📦 Key Dependencies

- `flutter_riverpod`: State management
- `sqlite3_flutter_libs` & `sqflite`: Local database
- `workmanager`: Background task scheduling
- `local_auth`: Biometric authentication
- `flutter_secure_storage`: Secure PIN storage
- `path_provider`: File system access
- `share_plus`: File sharing capabilities
- `file_picker`: Backup file selection

## 🚀 Getting Started

### Prerequisites

- **Flutter SDK**: 3.24.3 or higher
- **Dart SDK**: 3.5.3 or higher
- **Development Environment**: Android Studio or VS Code with Flutter extension
- **Target Platform**: Android device or emulator (API level 21+)
- **Device Features**: Camera and storage permissions for document management

### Installation & Setup

1. **Clone the repository:**

   ```bash
   git clone https://github.com/ananyaakamat/my-records-flutter-app.git
   cd my_records
   ```

2. **Install dependencies:**

   ```bash
   flutter pub get
   ```

3. **Configure Android permissions** (automatically handled in AndroidManifest.xml):

   - Storage access for backup files
   - Camera access for document scanning
   - Biometric authentication permissions

4. **Run the application:**

   ```bash
   flutter run
   ```

5. **First Launch Setup:**
   - Set up your 6-digit security PIN
   - Enable biometric authentication (optional)
   - Configure automatic backup preferences
   - Create your first folder to start organizing records

### 🔧 Development Setup

For development and debugging:

```bash
# Run in debug mode
flutter run --debug

# Run with hot reload
flutter run --hot

# Build release APK
flutter build apk --release

# Run tests
flutter test

# Code analysis
flutter analyze
```

## 📁 Project Structure

```
lib/
├── core/                          # Core functionality
│   ├── database/                  # SQLite database configuration
│   │   └── database_helper.dart   # Database operations and migrations
│   ├── services/                  # Core services
│   │   ├── backup_service.dart    # Automated backup system with WorkManager
│   │   └── security_service.dart  # Authentication and security handling
│   ├── constants/                 # App-wide constants
│   └── utils/                     # Utility functions and helpers
├── features/                      # Feature-based architecture
│   ├── home/                      # Main application screens
│   │   └── presentation/
│   │       ├── home_screen.dart         # Main folder list with search
│   │       └── backup_restore_screen.dart # Backup management interface
│   ├── folders/                   # Folder management
│   │   ├── domain/               # Folder models and business logic
│   │   ├── providers/            # Riverpod state management
│   │   └── presentation/         # Folder UI components
│   ├── records/                   # Record management within folders
│   │   ├── domain/               # Record models
│   │   └── presentation/         # Record UI screens
│   ├── security/                  # Authentication system
│   │   └── presentation/
│   │       ├── security_wrapper_screen.dart # Authentication flow wrapper
│   │       ├── auth_screen.dart          # PIN/Biometric authentication
│   │       ├── security_setup_screen.dart # Initial PIN setup
│   │       └── change_pin_dialog.dart    # PIN change functionality
│   └── [other features]/         # Additional feature modules
└── main.dart                      # App entry point with theme configuration
```

## 🔧 Recent Updates

### 🆕 Latest Enhancements (October 30, 2025)

#### ✨ Dynamic Date Interpretation System

**New Feature**: Advanced date recognition and intelligent interpretation for record field values.

**Key Capabilities**:
- **Comprehensive Date Parsing**: Supports 6 different regex patterns for maximum compatibility
- **Smart Age Calculation**: Automatically calculates age for birth dates (e.g., "25 years, 3 months old")
- **Expiry Status Tracking**: Shows time remaining until expiry for future dates (e.g., "Expires in 2 years, 1 month")
- **Current Date Detection**: Displays "Expired" in red for dates matching today's date
- **Multi-Format Support**: Recognizes dates in various international formats

#### 📅 Supported Date Formats

The app now intelligently recognizes dates in these formats within Field Values:

- **Numeric**: `25/07/2025`, `4/3/24`, `15-12-2023`
- **With Month Names**: `4 Mar 2025`, `03 April 24`
- **US Format**: `March 4, 2025`, `Apr 03, 24`
- **Hyphenated**: `4-Mar-2025`, `15-Dec-23`
- **Concatenated**: `4March23`, `15mar2025`, `4Mar2023`
- **With Day Names**: `Mon 4 Mar 2025`, `Sat 03 April 24`

#### 🎯 Enhanced User Experience

- **Interactive Record Details**: Tap any record to view comprehensive details with automatic date interpretation
- **Smart Year Handling**: 2-digit years are intelligently converted (< 50 = 2000s, >= 50 = 1900s)
- **Case-Insensitive**: Works with any combination of uppercase/lowercase month names
- **Contextual Information**: Automatic age/expiry calculations provide meaningful context
- **Visual Indicators**: Red text for expired items, clear formatting for all date interpretations

#### 📖 Comprehensive Help System

- **Updated Help Screens**: Complete guidance on record interaction and date format support
- **Clear Examples**: Detailed examples for all supported date formats
- **User-Friendly Instructions**: Step-by-step guidance for optimal app usage

### ✅ Previous Updates (October 29, 2025)

#### Major Fix: Backup Record Count Accuracy

**Problem Resolved**: Fixed critical issue where backup success dialog displayed incorrect record count (showing 11 records when only 9 valid records existed).

**Root Cause**: Orphaned records from deleted folders were being included in backup statistics, causing count discrepancies.

### 🛠️ Technical Improvements Implemented

1. **Orphaned Record Detection & Cleanup**:

   - Automatically identifies records belonging to deleted folders during backup creation
   - Performs real-time database cleanup to remove orphaned records
   - Ensures data integrity by preventing stale record accumulation

2. **Enhanced Backup Statistics**:

   - Backup counts now reflect actual valid records only
   - Filters out orphaned records before calculating statistics
   - Provides accurate folder and record counts in success dialogs

3. **Comprehensive Debug Logging**:

   - Added detailed logging for backup record filtering process
   - Tracks total records vs. valid records during backup creation
   - Logs orphaned record cleanup operations for transparency

4. **Database Integrity Maintenance**:
   - Automatic cleanup prevents database bloat from orphaned records
   - Improves app performance by removing unnecessary data
   - Maintains referential integrity between folders and records

### 🎯 Impact & Benefits

- **✅ Accurate Statistics**: Backup dialogs now show precise record counts matching user data
- **✅ Improved Performance**: Cleaner database with no orphaned records
- **✅ Enhanced Reliability**: Automatic data integrity maintenance during backups
- **✅ Better User Experience**: Eliminates confusion from incorrect record counts
- **✅ Proactive Maintenance**: Prevents long-term database issues

### 🔍 Technical Details

**Before Fix**: `DEBUG: Found 13 total records, 11 valid records for 9 folders`
**After Fix**: `DEBUG: Found 13 total records, 8 valid records for 7 folders`

- Automatically cleaned up 5 orphaned records from deleted folders
- Backup statistics now accurately reflect only valid, accessible records

## 📱 Usage Guide

### Basic Operations

1. **Creating Folders**: Tap the + button to create custom folders with colors and icons
2. **Managing Records**: Tap any folder to add, edit, or delete records within it
3. **Search Functionality**: Use the search bar to find specific records across all folders
4. **Organizing**: Drag and drop folders to reorder them according to your preference

### Security Features

- **Initial Setup**: Create a 6-digit PIN on first launch
- **Biometric Access**: Enable fingerprint authentication for quick access
- **PIN Management**: Change your PIN anytime through Settings

### Backup & Restore

- **Automatic Backups**: Enable daily or weekly automated backups
- **Manual Backup**: Create instant backups before major changes
- **Restore Data**: Select any previous backup file to restore your data
- **File Location**: Backups are saved in your Downloads folder as JSON files

### Advanced Features

- **Bulk Operations**: Use "Delete All" to remove all folders with safety confirmation
- **Theme Toggle**: Switch between dark and light modes
- **Help System**: Access contextual help for any feature

## 🔧 Development & Contribution

### Development Workflow

```bash
# Development commands
flutter run --debug          # Run with debugging
flutter hot-reload          # Apply code changes instantly
flutter test               # Run unit tests
flutter analyze           # Static code analysis
flutter build apk --debug # Build debug APK
flutter build apk --release # Build production APK
```

### Code Quality Standards

- Follow Flutter/Dart style guidelines
- Use Riverpod for state management
- Implement proper error handling
- Add appropriate comments for complex logic
- Ensure responsive design for different screen sizes

### Contributing Guidelines

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Commit** your changes (`git commit -m 'Add amazing feature'`)
4. **Push** to the branch (`git push origin feature/amazing-feature`)
5. **Open** a Pull Request with detailed description

### Issue Reporting

- Use GitHub Issues for bug reports and feature requests
- Provide detailed reproduction steps for bugs
- Include device information and app version
- Attach screenshots or logs when relevant

## 📄 License & Acknowledgments

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

### Key Technologies & Packages

- **Flutter Team** for the amazing framework
- **Riverpod** for elegant state management
- **SQLite** for reliable local storage
- **WorkManager** for background task processing
- **Material Design** for consistent UI/UX

---

## 📊 Project Status

- **Current Version**: 1.0.0
- **Last Updated**: October 30, 2025
- **Active Development**: ✅ Ongoing
- **Production Ready**: ✅ Yes
- **Platform Support**: 📱 Android (iOS support planned)

## 🔮 Upcoming Features

- **Cloud Sync**: Automatic cloud backup integration
- **Document Scanning**: Built-in camera-based document scanning
- **Export Options**: PDF and Excel export capabilities
- **Sharing**: Direct sharing of individual records or folders
- **iOS Version**: Native iOS application

---

**Built with ❤️ using Flutter**
