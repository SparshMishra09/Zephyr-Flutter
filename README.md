# Zephyr — AI-Powered On-Device Research Assistant

[![Flutter](https://img.shields.io/badge/Flutter-3.24-blue.svg)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.2-green.svg)](https://dart.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Zephyr is a privacy-first, on-device AI research assistant built with Flutter. It combines **Retrieval-Augmented Generation (RAG)** with Google's Gemini API to let you chat with your documents, ask questions about your screen, and get instant answers — all from a floating ghost bubble available anywhere on your phone.

## ✨ Features

- **🔍 RAG-Powered Chat** — Import PDFs, text files, images, and CSVs. Ask questions and get answers grounded in your documents with source citations.
- **👻 Ghost Bubble** — A floating overlay bubble that lets you ask questions from any app without leaving your current context.
- **📄 Document Management** — Import, organize, and search through your personal document library.
- **🧠 Smart Embeddings** — On-device text embedding with TF Lite (falls back to character n-gram embeddings).
- **⚡ Streaming Responses** — Real-time streaming AI responses with typing indicators.
- **🌙 Dark Theme** — Beautiful dark UI with purple accent gradients and glass-morphism effects.
- **🔒 Privacy-First** — Documents stored locally. Only queries go to the Gemini API.

## 🏗️ Architecture

```
zephyr/
├── lib/
│   ├── core/                    # Core services and utilities
│   │   ├── config/              # App configuration
│   │   ├── database/            # Hive database wrapper
│   │   ├── models/              # Data models (Document, Chunk, Conversation, Message)
│   │   ├── services/            # Gemini API, screen context
│   │   └── utils/               # Extensions, logger, constants
│   ├── features/                # Feature modules (clean architecture)
│   │   ├── home/                # Home screen with quick actions
│   │   ├── chat/                # Chat screen with RAG responses
│   │   ├── documents/           # Document import and management
│   │   ├── settings/            # App settings and configuration
│   │   └── onboarding/          # First-time user onboarding
│   ├── rag/                     # RAG pipeline
│   │   ├── embedding/           # Text embedding (TF Lite + fallback)
│   │   ├── ingestion/           # Document ingestion and chunking
│   │   ├── parsers/             # File parsers (PDF, text, image, CSV)
│   │   ├── retrieval/           # Vector similarity search
│   │   └── pipeline/            # RAG orchestrator
│   ├── overlay/                 # Ghost bubble floating overlay
│   └── theme/                   # Zephyr dark theme
├── test/                        # Comprehensive test suite
├── android/                     # Android platform code
└── assets/                      # Static assets
```

## 🚀 Getting Started

### Prerequisites

- Flutter SDK >= 3.24.0
- Dart SDK >= 3.2.0
- Android Studio / VS Code with Flutter plugins
- An Android device (API 26+) or emulator
- A [Google AI Studio API key](https://aistudio.google.com/apikey)

### Installation

```bash
# Clone the repository
git clone https://github.com/SparshMishra09/Zephyr.git
cd zephyr

# Get dependencies
flutter pub get

# Run on connected device
flutter run

# Build release APK
flutter build apk --release
```

### Setting Up

1. **API Key**: Open the app → Settings → enter your Gemini API key
2. **Ghost Bubble**: Enable in Settings → grant "Display over other apps" permission
3. **Import Documents**: Tap the + button on the Documents tab to import files

## 🧪 Testing

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Run specific test file
flutter test test/rag/text_chunker_test.dart
```

## 📱 Screenshots

| Home | Chat | Documents | Ghost Bubble |
|------|------|-----------|--------------|
| 🏠 | 💬 | 📄 | 👻 |

## 📦 Tech Stack

| Layer | Technology |
|-------|-----------|
| UI Framework | Flutter 3.24 + Material 3 |
| State Management | Provider |
| Local Storage | Hive + SharedPreferences |
| AI/ML | Google Generative AI + TF Lite |
| File Handling | file_picker, pdf, image |
| Overlay | system_alert_window |
| Testing | flutter_test + mockito |

## 📄 License

MIT License — see [LICENSE](LICENSE) for details.

## 🤝 Contributing

Contributions welcome! Please open an issue or PR.

## 👤 Author

Built by Sparsh Mishra — [GitHub](https://github.com/SparshMishra09)