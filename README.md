# My Records - Personal Records Management App

A comprehensive Flutter application for organizing and managing personal documents, certificates, educational records, and other important information in a secure, folder-based system with automated backup capabilities.

## 🌟 Key Features

### 📂 Core Organization

- **Folder-Based Organization**: Create custom folders to categorize your records
- **� Customizable Folders**: Choose from multiple colors and icons for folder personalization
- **📊 Record Count Tracking**: Visual indicators showing number of records in each folder
- **🔄 Drag & Drop Reordering**: Organize folders by dragging them to preferred positions
- **📋 Bulk Operations**: Delete all folders and records with comprehensive safety warnings

### 🔍 Advanced Search & Navigation

- **Global Search**: Search across all folders and records with real-time results
- **Smart Filtering**: Filter search results by specific folders
- **Debounced Search**: Optimized search with 500ms delay for better performance
- **Search Result Context**: Shows which folder contains each found record

### 🔐 Security & Authentication

- **PIN Protection**: 6-digit PIN for secure access to all data
- **Biometric Authentication**: Fingerprint support for quick access
- **Security Wrapper**: Seamless authentication flow with splash screen
- **Optimized Loading**: Eliminates blank screens during authentication and data loading

### 💾 Backup & Restore System

- **Automated Backups**: Daily or weekly automatic backups using WorkManager
- **Background Processing**: Backups run automatically when device is charging and idle
- **Manual Backup**: Create instant backups on demand
- **Smart File Management**: Automatically maintains 5 most recent backups
- **Cloud Compatibility**: JSON format backups saved to Downloads folder
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

## 🔧 Recent Updates (Last 48 Hours)

### ✨ New Features Added

1. **Complete Backup System**: Automated daily/weekly backups with WorkManager
2. **Delete All Functionality**: Bulk deletion with comprehensive safety warnings
3. **Enhanced Security Flow**: Improved authentication with splash screen optimization
4. **Search & Filter System**: Global search with folder-specific filtering
5. **UI Polish**: Fixed dialog overflows, improved responsive design

### 🛠️ Technical Improvements

- **Background Task Processing**: WorkManager integration for automated backups
- **State Management Enhancement**: Improved Riverpod provider architecture
- **Database Optimization**: Foreign key constraints and cascade deletion support
- **Authentication Flow**: Eliminated blank screens during app initialization
- **File Management**: JSON backup format with automatic cleanup

### 🎨 UX Enhancements

- **Responsive Loading**: Proper loading states throughout the app
- **Dialog Improvements**: Fixed text overflow issues with Expanded widgets
- **Help System**: Updated help screens for all new functionalities
- **Visual Feedback**: Progress indicators and contextual messages

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
- **Last Updated**: October 2025
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
