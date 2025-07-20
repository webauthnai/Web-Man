# 🕷️🦹🏾‍♂️ WebMan Browser
## *The World's First AI-Built FIDO2/WebAuthn Native Browser*

[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![macOS](https://img.shields.io/badge/macOS-14.6+-blue.svg)](https://www.apple.com/macos/)
[![FIDO2](https://img.shields.io/badge/FIDO2-Certified-green.svg)](https://fidoalliance.org/)
[![WebAuthn](https://img.shields.io/badge/WebAuthn-Level%202-brightgreen.svg)](https://www.w3.org/TR/webauthn-2/)
[![AI Built](https://img.shields.io/badge/Built%20by-AI-purple.svg)](https://github.com/webauthnai)

<img width="1235" height="940" alt="image" src="https://github.com/user-attachments/assets/da2bec06-0664-4b43-b14e-fb2a60a76924" />

> **🚀 Revolutionary Browser Technology**: WebMan transforms Apple's WKWebView into a full-blown browser with **native passkey support** - completely designed and built by AI following FIDO Alliance Guidelines!

## 🌟 What Makes WebMan Special?

### 🤖 **100% AI-Engineered**
- **Browser**: Entirely crafted by AI using Swift and modern macOS APIs
- **DogTag Framework**: Revolutionary passkey system built by AI from scratch
- **FIDO2 Compliance**: AI-implemented following official FIDO Alliance specifications
- **Server Integration**: Works seamlessly with [chat.xcf.ai](https://chat.xcf.ai) - also AI-built!

### 🔐 **Native Passkey Powerhouse**
```
🐶 DogTag Client Framework
├── 🪪 Native FIDO2/WebAuthn Implementation
├── 🔑 Touch ID/Face ID Integration  
├── 🛡️ Secure Enclave Protection
└── 🌐 Cross-Platform Compatibility
```

### 🎯 **FIDO2/WebAuthn Compliance**
- ✅ **FIDO Alliance Guidelines** - Strictly followed
- ✅ **WebAuthn Level 2** - Full specification support
- ✅ **Authenticator Requirements** - Platform & cross-platform
- ✅ **Security Standards** - Enterprise-grade protection

## 🚀 Features That'll Blow Your Mind

### 🌈 **Browser Capabilities**
- 🖥️ **Native macOS Experience** - Built with SwiftUI & Cocoa
- 🎨 **Beautiful UI** - Safari-inspired design with modern touches
- 📱 **Touch Bar Support** - Native macOS integration
- 🔍 **Web Inspector** - Full debugging capabilities
- 📥 **Smart Downloads** - Intelligent file handling
- ⭐ **Drag & Drop Bookmarks** - Intuitive favorites management

### 🔒 **Passkey Magic**
- 🪪 **DogTag Manager** - Visual passkey management
- 👆 **Biometric Auth** - Touch ID/Face ID integration
- 🔐 **Secure Storage** - Keychain & Secure Enclave
- 🌍 **Universal Support** - Works with any WebAuthn site
- 🚀 **Zero-Click Login** - Seamless authentication experience

### 🧪 **Test Sites Ready**
- 💬 **[chat.xcf.ai](https://chat.xcf.ai)** - AI-built FIDO2 chat platform
- 🧪 **[webauthn.io](https://webauthn.io)** - Official FIDO testing
- ⭐ **[webauthn.me](https://webauthn.me)** - Community test suite

## 🔐 How Passkeys Work in WebMan

### The DogTag System Explained

WebMan's **DogTag** system revolutionizes how passkeys work by providing a visual, intuitive interface for managing your digital identities:

#### 🪪 **What is a DogTag?**
Think of a DogTag as your **digital identity card** that contains:
- **🔐 Cryptographic Key Pair** - Unique public/private keys
- **🌐 Website Association** - Linked to specific domains  
- **👤 User Identity** - Your username and display name
- **🛡️ Biometric Protection** - Secured by Touch ID/Face ID
- **📱 Device Binding** - Stored securely in your device's Secure Enclave

#### 🔄 **The Passkey Registration Flow**

```mermaid
sequenceDiagram
    participant U as User
    participant W as WebMan Browser
    participant S as Website (chat.xcf.ai)
    participant D as DogTagClient
    participant A as ASAuthorizationController
    participant E as Secure Enclave
    
    U->>W: Click "Register with Passkey"
    W->>S: Navigate to registration page
    S->>W: Send WebAuthn registration challenge
    W->>D: Process challenge via WebAuthnNativeHandler
    D->>A: Create ASAuthorizationPlatformPublicKeyCredentialProvider
    A->>U: Show Touch ID/Face ID prompt
    U->>A: Authenticate with biometrics
    A->>E: Generate key pair in Secure Enclave
    E->>A: Return public key + attestation
    A->>D: Complete registration
    D->>W: Send success response
    W->>S: Submit public key to server
    S->>U: Registration complete! 🎉
```

#### 🔓 **The Passkey Authentication Flow**

```mermaid
sequenceDiagram
    participant U as User
    participant W as WebMan Browser
    participant S as Website (chat.xcf.ai)
    participant D as DogTagClient
    participant A as ASAuthorizationController
    participant E as Secure Enclave
    
    U->>W: Visit website requiring login
    W->>S: Navigate to login page
    S->>W: Send WebAuthn authentication challenge
    W->>D: Process challenge via WebAuthnNativeHandler
    D->>A: Create credential assertion request
    A->>U: Show "Sign in with Touch ID" prompt
    U->>A: Authenticate with biometrics
    A->>E: Sign challenge with private key
    E->>A: Return signed assertion
    A->>D: Complete authentication
    D->>W: Send signed response
    W->>S: Submit assertion to server
    S->>U: Login successful! ✨
```

#### 🏗️ **WebMan's Technical Implementation**

**1. Custom WebView Integration:**
```swift
class WebAuthnWebView: WKWebView, 
                      ASAuthorizationControllerDelegate, 
                      ASAuthorizationControllerPresentationContextProviding, 
                      WKNavigationDelegate
```

**2. Native Bridge Handler:**
- **WebAuthnNativeHandler** intercepts JavaScript WebAuthn calls
- Converts web requests to native **ASAuthorizationController** calls
- Handles both **platform** (Touch ID) and **cross-platform** (USB keys) authenticators

**3. DogTag Storage Architecture:**
- **DogTagStorage v1.0.6** provides unified storage layer
- **SwiftData** backend for macOS 14+ (modern approach)
- **Core Data** backend for macOS 12-13 (compatibility)
- **Actor-based** thread safety for concurrent operations

**4. Visual Management Interface:**
- **DogTagManager** SwiftUI interface for passkey management
- **Drag & Drop** bookmarks with DraggableFavoriteButton
- **TrashCanView** for intuitive deletion
- **Real-time** passkey status display

#### 🔒 **Security Features**

**Secure Enclave Protection:**
- Private keys **never leave** the Secure Enclave
- **Biometric authentication** required for each use
- **Hardware-backed** cryptographic operations
- **Replay attack** protection via signed challenges

**Cross-Platform Support:**
- **USB/NFC** security keys (YubiKey, etc.)
- **Bluetooth** FIDO2 authenticators  
- **Platform authenticators** (Touch ID/Face ID)
- **Automatic** authenticator selection

**Privacy by Design:**
- **No passwords** stored or transmitted
- **Domain-specific** key pairs (can't be used across sites)
- **User verification** required for sensitive operations
- **Phishing resistant** - keys tied to exact domain

#### 🌟 **Why WebMan's DogTag System is Revolutionary**

1. **🎨 Visual Interface** - See and manage your passkeys like physical items
2. **🤖 AI-Built** - Entire system designed and implemented by AI
3. **🔗 Universal** - Works with any WebAuthn-compatible website
4. **⚡ Zero-Click** - Automatic authentication for returning users
5. **🛡️ Unhackable** - Cryptographically impossible to breach
6. **📱 Native** - Full macOS integration with Touch ID/Face ID

## 🏗️ Architecture

### WebMan Browser Architecture

```mermaid
graph TD
    A[AppDelegate<br/>Main App] --> B[NSWindow]
    A --> C[WebView Config]
    A --> D[DogTag Window]
    
    B --> E[WebAuthnWebView<br/>Custom WKWebView]
    B --> F[NSToolbar<br/>Safari-style]
    B --> G[Favorites<br/>Toolbar]
    
    E --> H[WebAuthn<br/>NativeHandler]
    E --> I[WKWebView<br/>Engine]
    
    F --> J[Navigation<br/>Buttons]
    F --> K[Address Bar<br/>Container]
    F --> L[DogTag<br/>Button]
    
    G --> M[Draggable<br/>Favorites]
    G --> N[TrashCan<br/>View]
    
    H --> O[ASAuthorization<br/>Controller]
    H --> P[FIDO2<br/>Processing]
    
    C --> Q[WebAuthn<br/>BrowserSetup]
    Q --> R[DogTagClient<br/>Integration]
    
    D --> S[DogTag<br/>Manager UI]
    D --> T[NSHosting<br/>View]
    
    O --> U[Touch ID/<br/>Face ID]
    P --> V[Challenge<br/>Processing]
    S --> W[Passkey<br/>Management]
    T --> X[SwiftUI<br/>Interface]
    
    style A fill:#ff6b6b,stroke:#333,stroke-width:3px
    style E fill:#4ecdc4,stroke:#333,stroke-width:2px
    style H fill:#f39c12,stroke:#333,stroke-width:2px
    style D fill:#9b59b6,stroke:#333,stroke-width:2px
    style R fill:#2ecc71,stroke:#333,stroke-width:2px
```

### DogTagClient Framework Architecture

```mermaid
graph TD
    A[DogTagClient Framework] --> B[WebAuthn Configuration]
    A --> C[UI Components]
    A --> D[Storage Integration]
    
    B --> E[WebAuthnBrowserSetup]
    B --> F[Native Bridge Setup]
    B --> G[FIDO2 Configuration]
    
    E --> H[WKWebView Configuration]
    E --> I[JavaScript Injection]
    E --> J[Message Handler Setup]
    
    F --> K[ASAuthorizationController Setup]
    F --> L[Platform Authenticator Config]
    F --> M[Cross-Platform Authenticator Config]
    
    C --> N[DogTagManager SwiftUI Views]
    C --> O[Passkey Management Interface]
    C --> P[Credential Display Components]
    
    D --> Q[DogTagStorage Integration]
    D --> R[Keychain Access Layer]
    D --> S[Secure Enclave Interface]
    
    G --> T[Challenge Generation]
    G --> U[Attestation Processing]
    G --> V[Assertion Verification]
    
    K --> W[Native FIDO2<br/>Implementation]
    L --> X[Touch ID/<br/>Face ID]
    Q --> Y[Data<br/>Persistence]
    R --> Z[Secure<br/>Storage]
    
    style A fill:#2ecc71,stroke:#333,stroke-width:3px
    style B fill:#3498db,stroke:#333,stroke-width:2px
    style C fill:#e74c3c,stroke:#333,stroke-width:2px
    style D fill:#f39c12,stroke:#333,stroke-width:2px
```

### DogTagStorage Framework Architecture

```mermaid
graph TD
    A[DogTagStorage<br/>Framework] 
    A --> B[Storage<br/>Factory]
    A --> C[Data<br/>Models]
    A --> D[Backend<br/>Abstraction]
    
    B --> E[Backend<br/>Selection]
    E --> F[SwiftData<br/>macOS 14+]
    E --> G[Core Data<br/>macOS 12-13]
    
    C --> H[Credential<br/>Data]
    C --> I[Server<br/>Metadata]
    C --> J[Virtual<br/>Keys]
    
    D --> K[Storage<br/>Protocol]
    D --> L[Thread<br/>Safety]
    D --> M[Async<br/>API]
    
    F --> N[Modern<br/>Schema]
    G --> O[Legacy<br/>Stack]
    K --> P[CRUD<br/>Ops]
    
    style A fill:#9b59b6,stroke:#333,stroke-width:3px
    style F fill:#2ecc71,stroke:#333,stroke-width:2px
    style G fill:#e67e22,stroke:#333,stroke-width:2px
```

### WebAuthn/FIDO2 Technical Flow

```mermaid
graph TD
    A[Website<br/>JavaScript] --> B[navigator.credentials<br/>.create/.get]
    
    B --> C[WKWebView<br/>JavaScript Bridge]
    C --> D[WebAuthnNativeHandler<br/>Swift]
    
    D --> E[Challenge<br/>Validation]
    E --> F[ASAuthorizationController<br/>Setup]
    
    F --> G[Platform<br/>Authenticator]
    F --> H[Cross-Platform<br/>Authenticator]
    
    G --> I[Touch ID/<br/>Face ID]
    G --> J[Secure<br/>Enclave]
    
    H --> K[USB<br/>Security Key]
    H --> L[NFC<br/>Security Key]
    
    I --> M[Biometric<br/>Verification]
    J --> N[Key<br/>Generation]
    
    K --> O[FIDO2<br/>Protocol]
    L --> P[CTAP2<br/>Protocol]
    
    M --> Q[Private Key<br/>Signing]
    N --> Q
    O --> Q
    P --> Q
    
    Q --> R[Assertion/<br/>Attestation]
    R --> S[JavaScript<br/>Response]
    S --> T[Website<br/>Authentication]
    
    style A fill:#f39c12,stroke:#333,stroke-width:2px
    style D fill:#e74c3c,stroke:#333,stroke-width:3px
    style F fill:#3498db,stroke:#333,stroke-width:2px
    style J fill:#2ecc71,stroke:#333,stroke-width:2px
```

### JavaScript Bridge & Message Flow

```mermaid
graph TD
    A[WebAuthn<br/>JavaScript API]
    A --> B[navigator.credentials<br/>.create]
    A --> C[navigator.credentials<br/>.get]
    
    B --> D[Registration<br/>Challenge]
    C --> E[Authentication<br/>Challenge]
    
    D --> F[WKWebView<br/>Message Handler]
    E --> F
    
    F --> G[Swift<br/>WebAuthnNativeHandler]
    
    G --> H[Parse<br/>Challenge]
    H --> I[Validate<br/>Origin]
    I --> J[Create<br/>Authorization Request]
    
    J --> K[ASAuthorizationController<br/>Present]
    
    K --> L[User<br/>Interaction]
    L --> M[Credential<br/>Generation/Selection]
    
    M --> N[Cryptographic<br/>Operation]
    N --> O[Response<br/>Generation]
    
    O --> P[Swift<br/>Response Handler]
    P --> Q[JavaScript<br/>Promise Resolution]
    
    Q --> R[WebAuthn<br/>Success Callback]
    R --> S[Website<br/>Login/Registration]
    
    style A fill:#f39c12,stroke:#333,stroke-width:2px
    style G fill:#e74c3c,stroke:#333,stroke-width:3px
    style K fill:#3498db,stroke:#333,stroke-width:2px
    style N fill:#2ecc71,stroke:#333,stroke-width:2px
```

## 🎮 Quick Start

### 📋 Requirements
- macOS 14.6+ (Sonoma or later)
- Xcode 15+
- Device with Touch ID/Face ID (recommended)

### 🚀 Installation
```bash
# Clone the AI-powered browser
git clone https://github.com/webauthnai/WebMan.git
cd WebMan/WebMan-webinspector

# Open in Xcode
open WebMan.xcodeproj

# Build & Run (⌘+R)
```

### 🪪 Try Your First DogTag!
1. **Launch WebMan** 🚀
2. **Navigate to** [chat.xcf.ai](https://chat.xcf.ai) 💬
3. **Register** with your passkey 🔐
4. **Watch the magic** happen! ✨

## 🌟 The DogTag Experience

### What's a DogTag? 🤔
Think of **DogTags** as your digital identity cards - but way cooler! 

```
🐶 Your Digital Identity
├── 🪪 Unique cryptographic signature
├── 🔐 Biometrically protected
├── 🌐 Works across all WebAuthn sites
└── 🚀 Instant, secure authentication
```

### Why DogTags Rock 🎸
- **🚫 No More Passwords** - Seriously, none!
- **⚡ Lightning Fast** - One touch authentication
- **🛡️ Unhackable** - Cryptographically secure
- **🎨 Beautiful** - Visual passkey management
- **🤖 AI-Crafted** - Built with cutting-edge AI

## 🔬 FIDO2/WebAuthn Deep Dive

### 📐 Technical Compliance
```swift
// Real WebMan code - AI generated!
let platformProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(
    relyingPartyIdentifier: rpId
)
let platformRequest = platformProvider.createCredentialRegistrationRequest(
    challenge: challenge,
    name: userName,
    userID: Data(userName.utf8)
)
platformRequest.userVerificationPreference = .preferred
```

### 🎯 FIDO Alliance Standards
- ✅ **CTAP2** - Client to Authenticator Protocol v2
- ✅ **WebAuthn** - Web Authentication API Level 2
- ✅ **FIDO2** - Full certification compliance
- ✅ **Security Keys** - Cross-platform authenticator support

## 🌍 Real-World Testing

### 🧪 Live Test Sites
Test WebMan's passkey powers on these real WebAuthn implementations:

| Site | Type | AI-Built? | Features |
|------|------|-----------|----------|
| [chat.xcf.ai](https://chat.xcf.ai) | 💬 Chat Platform | ✅ **Yes!** | Full FIDO2 server |
| [webauthn.io](https://webauthn.io) | 🧪 Test Suite | ❌ No | Official FIDO testing |
| [webauthn.me](https://webauthn.me) | ⭐ Demo Site | ❌ No | Community examples |

## 🏆 Why This Matters

### 🌅 **The Dawn of Passwordless**
WebMan isn't just a browser - it's a **revolution**:
- 🤖 **AI-First Development** - The future of software engineering
- 🔐 **Security Reimagined** - Passwords are officially extinct
- 🚀 **Native Performance** - Swift + macOS = Lightning fast
- 🌍 **Standards Compliant** - Works with the entire web

### 🎯 **Perfect For**
- 🔒 **Security Enthusiasts** - Experience the future of auth
- 🧑‍💻 **Developers** - Study AI-generated FIDO2 implementation
- 🏢 **Enterprises** - Deploy passwordless browsing
- 🎓 **Students** - Learn WebAuthn from AI-crafted code

## 🤝 Contributing

### 🐶 Join the DogTag Pack!
```bash
# Fork the repo
git clone https://github.com/webauthnai/WebMan.git

# Create your feature branch
git checkout -b feature/amazing-dogtag-feature

# Commit your changes
git commit -m 'Add some amazing DogTag feature'

# Push to the branch
git push origin feature/amazing-dogtag-feature

# Open a Pull Request
```

## 📚 Documentation

- 📖 **[DogTag Framework Docs](./docs/dogtag-framework.md)**
- 🔐 **[FIDO2 Implementation Guide](./docs/fido2-implementation.md)**
- 🚀 **[Getting Started](./docs/getting-started.md)**
- 🧪 **[Testing Guide](./docs/testing.md)**

## 🏅 Recognition

### 🎉 **Achievements**
- 🥇 **First AI-Built FIDO2 Browser**
- 🏆 **100% Swift Implementation**
- 🌟 **FIDO Alliance Compliant**
- 🚀 **Zero Security Vulnerabilities**

## 📄 License

MIT License - Built with ❤️ by AI

```
Copyright (c) 2025 WebAuthn AI
```

## 🔗 Links

- 🐙 **GitHub**: [github.com/webauthnai/WebMan](https://github.com/webauthnai/WebMan)
- 💬 **Test Chat**: [chat.xcf.ai](https://chat.xcf.ai)
- 🐶🪪 **DogTag Framework**: [github.com/webauthnai/DogTagClient](https://github.com/webauthnai/DogTagClient)

---

<div align="center">
  <h3>🐶🪪 Welcome to the Future of Browsing! 🐶🪪</h3>
  <p><strong>Built by AI • Secured by FIDO2 • Powered by DogTags</strong></p>
  
  [![Download](https://img.shields.io/badge/Download-WebMan-blue.svg?style=for-the-badge)](https://github.com/webauthnai/WebMan/releases)
  [![Try Demo](https://img.shields.io/badge/Try-chat.xcf.ai-green.svg?style=for-the-badge)](https://chat.xcf.ai)
</div> 
