# Alpha CRM - Multi-Channel Zalo & Omnichannel Marketing CRM System

Alpha CRM is a premium, full-stack customer relationship management and marketing automation system. It is designed to empower operators and business owners to manage customer relations, run bulk marketing campaigns, and automate customer engagement across multiple messaging channels—with a particular focus on the **Zalo platform** (both Personal Zalo accounts and Zalo Official Accounts) as well as **Facebook Messenger** and **TikTok Business Messaging**.

The system is built as a hybrid local-cloud application consisting of:
1. **Frontend**: A high-fidelity, responsive client application built with **Flutter** supporting Windows Desktop, Android, and Web viewports.
2. **Local Backend Bridge**: A **Node.js/TypeScript** background service ([zalo-bot-service](file:///D:/Dev/NodeJS/alpha-studio/tools/alpha-crm/integration/zalo-bot-service/)) that communicates with personal Zalo (via `zca-js`), Facebook Messenger APIs, and TikTok Messaging stubs, acting as the local-first execution engine.

---

## 📸 Screenshots & Design System

The system strictly adheres to the standard **Design System** defined in [DESIGN.md](file:///D:/Dev/NodeJS/alpha-studio/tools/alpha-crm/DESIGN.md) and [PRODUCT.md](file:///D:/Dev/NodeJS/alpha-studio/tools/alpha-crm/PRODUCT.md). It features a highly polished dark/light corporate aesthetic using the `Be Vietnam Pro` (Inter-derived) typography, an 8px spacing grid, and fluid layouts optimized across Desktop, Tablet, and Mobile viewports.

![Alpha CRM Dashboard](img/crm_dashboard.png)

---

## 🏗️ System Architecture

Alpha CRM runs in two primary runtime configurations based on the client platform:

### A. Local-First Desktop Mode (Windows)
When running as a Windows Desktop application, the Flutter UI acts as a supervisor, launching the Node.js backend bridge as a background subprocess.
*   **Subprocess Supervisor**: [ZaloBackendManager](file:///D:/Dev/NodeJS/alpha-studio/tools/alpha-crm/lib/shared/utils/zalo_backend_manager.dart) spawns `dist/server.cjs` and performs a 5-second health check. It features exponential backoff auto-restart and a safety circuit breaker.
*   **OS Process Binding**: Processes are bound to a native Windows Job Object via [windows_job_object.dart](file:///D:/Dev/NodeJS/alpha-studio/tools/alpha-crm/lib/shared/utils/windows_job_object.dart), guaranteeing that the Node background process is killed by the OS immediately if the Flutter client exits or is force-closed.
*   **Startup Overlay**: [BackendSplashOverlay](file:///D:/Dev/NodeJS/alpha-studio/tools/alpha-crm/lib/shared/widgets/backend_splash_overlay.dart) blocks the main UI until the backend is fully healthy and the Zalo integration is initialized. In case of startup failure, it displays a copyable log panel.

```text
[ Flutter Windows Client ] ──(HTTP/SSE Localhost)──> [ Local zalo-bot-service (Node/TS) ] ──> Zalo ZCA API
           │                                                       │
  (Windows Job Object)                                     (Heartbeat & Command Poll)
           │                                                       │
           ▼                                                       ▼
[ Native Process Lifecycle ]                               [ Alpha Studio Cloud ] ──> [ n8n Automation Engine ]
```

### B. Remote Cloud-Remote Mode (Web & Android)
When running on Web or Android (where running a local Node process is impossible), the Flutter client communicates directly with Alpha Studio's cloud relay APIs.
*   **Unified Streaming**: Connects via a pooled [CrmSseClient](file:///D:/Dev/NodeJS/alpha-studio/tools/alpha-crm/lib/shared/api/crm_sse_client.dart) to stream real-time events (`hello`, `message.new`, etc.).
*   **Vocabulary Mapping**: [LiveChatCloudEventMapper](file:///D:/Dev/NodeJS/alpha-studio/tools/alpha-crm/lib/features/messaging/live_chat/data/live_chat_cloud_event_mapper.dart) maps cloud events back to local bridge events, keeping notifier logic identical.
*   **Agent Health Banner**: [AgentStatusProvider](file:///D:/Dev/NodeJS/alpha-studio/tools/alpha-crm/lib/features/messaging/live_chat/providers/agent_status_provider.dart) monitors the remote agent's heartbeat and locks/unlocks the composer based on the agent's connection state.

---

## ✨ Core Features & Integration Modules

### 1. Multi-Channel Live Chat
*   **Channels Supported**: Zalo Personal (ZCA), Zalo Official Account (OA), Facebook Page Messenger, and TikTok Business Messaging (structural placeholder).
*   **Local-First Database**: Message bodies, conversations, and metadata are saved to a local `better-sqlite3` database. Only high-level metadata is synced to the cloud, preserving chat privacy and bypassing cloud payload limitations.
*   **Local Caching**: Flutter uses [LocalDb](file:///D:/Dev/NodeJS/alpha-studio/tools/alpha-crm/lib/shared/local_db/local_db.dart) (`sqflite`) to store offline message snapshots for instant loading and offline recovery.
*   **Quick Replies**: Live Chat features a quick-reply bar supporting both numbered (`/1`, `/2`) and named (`/hello`, `/chao`) shortcuts resolved by [quick_reply_shortcuts.dart](file:///D:/Dev/NodeJS/alpha-studio/tools/alpha-crm/lib/features/messaging/live_chat/utils/quick_reply_shortcuts.dart).

### 2. Group Operations & AI Summarization
*   **Management Actions**: Scan group members, join groups via link/QR, invite friends in bulk, create automated groups, and leave groups in bulk.
*   **Logical Group Merging**: Collapses duplicate group records synced from multiple Zalo accounts into a single row on the UI with an avatar stack.
*   **Transient AI Summaries**: Selects recent messages, unions/dedupes them across accounts, and sends them transiently to the cloud for AI summarization. **Privacy Safe**: Group message content is never stored on the cloud database. Summaries are cached locally at `Documents/AlphaCRM/group_summaries.json`.

### 3. Bulk Messaging & Campaign Scheduling
*   **Client-Side Queue**: Schedules immediate or future campaigns stored in a local SQLite table via [ScheduledCampaignsDao].
*   **Background Timers**: Automatically spins up background timers for active campaigns, and checks for `missed` campaigns (scheduled during app downtime) upon startup to mark them accordingly.
*   **Zalo Compliance Guard**: Features a strict [ZaloComplianceGuard](file:///D:/Dev/NodeJS/alpha-studio/tools/alpha-crm/lib/shared/utils/zalo_compliance_guard.dart) checking account types, limits, and quiet hours. Uses a dedicated [ComplianceWarningsPopup] to warn operators before execution.

### 4. Friend Operations
*   **Add Friends**: Auto-send friend requests from CSV phone lists or scanned Zalo groups.
*   **Auto-Approve with TTL**: Automatically accepts incoming friend requests. Includes a TTL-based approval tracker ([recent-friend-approvals.ts](file:///D:/Dev/NodeJS/alpha-studio/tools/alpha-crm/integration/zalo-bot-service/src/recent-friend-approvals.ts)) that lets the bot suppress duplicate auto-welcomes.

### 5. App Security Lock
*   **Local Cryptographic Lock**: Lock button in the sidebar footer activates a global screen overlay.
*   **SHA-256 Hashing**: Passwords are hashed with a local salt and stored inside the application support directory, guarding access when the operator is away.

### 6. Auto-Update Service
*   **B2 Sync**: Checks semver against Backblaze B2 `version.json` on startup.
*   **In-Place Installation**: Downloads ZIP (Windows) or APK (Android). Applies Windows updates in-place via an external console script updater, writing a `.update_pending` flag and validating success upon the next launch.

---

## 🛠️ Tech Stack & Key Libraries

### Frontend (Flutter Client)
*   **Framework**: Flutter 3 (Dart SDK `^3.10.7`)
*   **State Management**: `flutter_riverpod` (combining `StateNotifierProvider` and `StateProvider`)
*   **Routing**: `go_router` (17 routes declared in [AppRoutes](file:///D:/Dev/NodeJS/alpha-studio/tools/alpha-crm/lib/app/routing/app_routes.dart))
*   **UI Components**: Material 3, `data_table_2` (advanced tables), `fl_chart` (dashboard statistics), `google_fonts` (Inter / Be Vietnam Pro)
*   **Local Storage**: `sqflite` / `sqflite_common_ffi` for local cache entries

### Local Backend (Node.js Service)
*   **Runtime**: Node.js (bundled in production Windows package), TypeScript
*   **Zalo Protocol**: `zca-js@^2.1.2` (Zalo Client API)
*   **Proxy Support**: `proxy-agent@^6.5.0` (socks/http/https proxy rotation per account)
*   **Database**: `better-sqlite3` (fast local message and settings store)
*   **Security**: Windows DPAPI key generation + AES-256-GCM encryption in [secure-store.ts](file:///D:/Dev/NodeJS/alpha-studio/tools/alpha-crm/integration/zalo-bot-service/src/secure-store.ts) for credential files (`credentials_*.json`)

---

## 📁 Directory Structure

```text
alpha-crm/
├── claude.md                       # Developer conventions & guidelines
├── DESIGN.md                       # Design system color and spacing tokens
├── PRODUCT.md                      # Product goals and brand personality
├── pubspec.yaml                    # Flutter dependencies
├── lib/
│   ├── main.dart                   # Flutter application entry point
│   ├── app/
│   │   ├── routing/                # AppRouter & GoRouter declarations
│   │   ├── theme/                  # AppColors, AppSpacing, and AppTextStyles
│   │   └── shell/                  # Sidebar, Topbar, and ResponsiveScaffold
│   ├── features/                   # Feature-first modules
│   │   ├── dashboard/              # Visual statistics & quick actions
│   │   ├── customers/              # Customer list, filtering, offline cache
│   │   ├── messaging/              # Live Chat, Bulk Messaging, Chatbot, History
│   │   ├── friends/                # Add friend by phone/group, auto-approve
│   │   ├── groups/                 # Group management & AI summarization
│   │   ├── security/               # AppLock overlays & password hashing
│   │   └── workflows/              # n8n rule builder & templates
│   ├── shared/                     # Reusable widgets and utilities
│   │   ├── widgets/                # AppDialog, Splash, Status Banners
│   │   └── utils/                  # ZaloBackendManager, ComplianceGuard
│   └── mock/                       # UI mocks for offline demonstration
└── integration/
    └── zalo-bot-service/           # Local Node.js backend bridge
        ├── src/
        │   ├── channels/           # Adapters: PersonalZca, OfficialOa, Facebook, Tiktok
        │   ├── agent/              # Cloud polling command loops & reporters
        │   ├── integrations/       # n8n templates & proxy tests
        │   ├── compliance.ts       # Backend compliance guard
        │   ├── secure-store.ts     # DPAPI encrypted configuration helper
        │   └── server.ts           # Express HTTP/SSE server (locked to 127.0.0.1)
```

---

## 🚀 Getting Started

### 1. Prerequisites
Ensure you have the following installed on your machine:
*   [Flutter SDK](https://docs.flutter.dev/get-started/install) (`^3.10.7` / compatible with Dart `^3.10.7`)
*   [Node.js](https://nodejs.org/) (v18 or newer recommended)
*   **Conda environments** (if running Python scripts: activate `D:\Dev\conda-envs\py310` or `D:\Dev\conda-envs\py312` per rules)

---

### 2. Setting Up the Local Backend Bridge

Navigate to the [zalo-bot-service](file:///D:/Dev/NodeJS/alpha-studio/tools/alpha-crm/integration/zalo-bot-service/) directory:
```bash
cd integration/zalo-bot-service
cp .env.example .env
npm install
npm run build
```

#### Running in Development:
```bash
npm run dev
```

#### Performing Zalo Personal Login:
To authenticate a personal Zalo account and generate the necessary session files:
```bash
npm run zalo:login-personal
```
This command opens a CLI prompt with a Zalo QR code. Scan the QR code using your mobile Zalo app. The session credentials will be saved securely to the `.data/` directory (encrypted at rest on Windows machines).

---

### 3. Setting Up the Flutter Client

Navigate back to the project root directory and retrieve the dependencies:
```bash
flutter pub get
```

#### Running the App:
*   **Windows Desktop**:
    ```bash
    flutter run -d windows
    ```
    *(Note: On Windows, the client will automatically start and manage the backend bridge subprocess via `ZaloBackendManager`)*
*   **Web Client**:
    ```bash
    flutter run -d chrome
    ```
*   **Android Devices**:
    Ensure an emulator or physical device is connected, then run:
    ```bash
    flutter run -d <device-id>
    ```

---

## 🔒 Session Security & Session Persistence

*   **Immutable Session Files**: Zalo session credentials (`credentials_<uId>.json`) are written **exactly once** during the QR login process and remain immutable. The backend never re-serializes the active cookie jar to disk.
*   **Background Re-login Refresh**: To prevent Zalo session cookies (specifically `zpw_sek`) from expiring, the Node.js bridge runs a background refresh task. Every **12 hours**, it silently triggers `zalo.login(saved)`. This updates the cookie jar in RAM while preserving the clean, original credential file on disk.
*   **Proxy Rotation**: Individual Zalo accounts can be assigned a dedicated SOCKS or HTTP proxy under Account Settings. The backend forces connections for that account through a proxy instance configured via `proxy-agent`.

---

## 📦 Automated Release Pipeline

The production CRM release pipeline is orchestrated by the parent repository's script:
`alpha-studio-backend/scripts/release-to-b2.js`

Running this script packages the Flutter binaries (APK and Windows executables) and compiles the backend service into a single minified bundle `integration/zalo-bot-service/dist/server.cjs` (built via `esbuild` to avoid leaking source files and minimize package size), shipping them onto Backblaze B2.
