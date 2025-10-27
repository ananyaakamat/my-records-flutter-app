# My Records - Personal Records Management App

A Flutter application for organizing and managing personal documents, certificates, educational records, and other important information in a folder-based system.

## 🌟 Features

- **📂 Folder-Based Organization**: Create custom folders to categorize your records
- **🌙 Dark/Light Theme**: Default dark mode with toggle support for user preference
- **🎨 Customizable Folders**: Choose from multiple colors and icons for folder personalization
- **📱 Mobile-First Design**: Optimized for mobile devices with responsive UI
- **🔍 Record Management**: Add, edit, duplicate, and delete folders with ease
- **💾 Local Storage**: SQLite database for secure local data storage
- **📊 Record Count Tracking**: Visual indicators showing number of records in each folder

## Tech Stack

- **Framework**: Flutter 3.24.3
- **Language**: Dart 3.5.3
- **Database**: SQLite with sqflite package
- **State Management**: Riverpod
- **Architecture**: Clean Architecture (Domain, Data, Presentation layers)

## Getting Started

### Prerequisites

- Flutter SDK 3.24.3 or higher
- Dart SDK 3.5.3 or higher
- Android Studio or VS Code with Flutter extension
- Android emulator or physical device

### Installation

1. Clone the repository:

   ```bash
   git clone <repository-url>
   cd my_records
   ```

2. Install dependencies:

   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   flutter run
   ```

## Project Structure

```
lib/
├── core/                 # Core functionality
│   ├── database/        # Database helpers and configurations
│   ├── constants/       # App constants
│   └── utils/          # Utility functions
├── features/            # Feature modules
│   ├── home/           # Home screen
│   ├── certificates/   # Certificate management
│   ├── documents/      # Document management
│   ├── education/      # Educational records
│   └── personal_info/  # Personal information
└── main.dart           # App entry point
```

## Development

### Running Tests

```bash
flutter test
```

### Code Analysis

```bash
flutter analyze
```

### Building for Android

```bash
flutter build apk
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests and analysis
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
