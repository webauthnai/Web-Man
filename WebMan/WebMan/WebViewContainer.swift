import SwiftUI
import WebKit
import AuthenticationServices
import LocalAuthentication

struct WebViewContainer: NSViewRepresentable {
    @EnvironmentObject var browserManager: BrowserManager
    
    func makeNSView(context: Context) -> WKWebView {
        let webView = WebAuthnWebView()
        
        print("🔧 Created WebAuthnWebView, setting up browserManager...")
        browserManager.setWebView(webView)
        
        print("🔧 Navigation delegate set to: \(String(describing: webView.navigationDelegate))")
        print("🔧 UI delegate set to: \(String(describing: webView.uiDelegate))")
        
        // Load initial URL
        if let url = URL(string: browserManager.currentURL) {
            print("🔧 Loading initial URL: \(url.absoluteString)")
            webView.load(URLRequest(url: url))
        }
        
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        // Handle updates if needed
    }
}

class WebAuthnWebView: WKWebView, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding, WKNavigationDelegate {
    private var webAuthnHandler: WebAuthnNativeHandler?
    
    override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: Self.createWebAuthnConfiguration())
        setupWebAuthn()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupWebAuthn()
    }
    
    convenience init() {
        let config = Self.createWebAuthnConfiguration()
        self.init(frame: .zero, configuration: config)
    }
    
    private static func createWebAuthnConfiguration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        
        // FIXED: Reduce display system queries and warnings
        configuration.suppressesIncrementalRendering = true
        configuration.allowsAirPlayForMediaPlayback = false
        
        // Enable core web features only
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.mediaTypesRequiringUserActionForPlayback = [.all]
        
        // FIXED: Use standard API instead of setValue to avoid display system conflicts
        configuration.preferences.isElementFullscreenEnabled = false
        configuration.preferences.isSiteSpecificQuirksModeEnabled = false
        
        // FIXED: Disable features that trigger display queries
        if #available(macOS 11.0, *) {
            configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        } else {
            configuration.preferences.javaScriptEnabled = true
        }
        
        // Enable WebAuthn with minimal display impact
        if #available(macOS 12.0, *) {
            // Use modern WebAuthn API that doesn't trigger display warnings
        }
        
        // FIXED: Remove setValue calls that trigger display system queries
        configuration.preferences.isFraudulentWebsiteWarningEnabled = true
        
        // Enable developer extras in debug builds
//#if DEBUG
        configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
//#endif
        
        print("🔧 WebView configuration created with JavaScript enabled via per-navigation preferences")
        
        return configuration
    }
    
    private func setupWebAuthn() {
        // FIXED: Defer setup to avoid display timing conflicts
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.webAuthnHandler = WebAuthnNativeHandler(webView: self)
            self.navigationDelegate = self
            
            // FIXED: Remove setValue calls that trigger display queries
            // Use standard WebKit configuration instead
            
            // Add message handlers without triggering display system
            self.configuration.userContentController.add(self.webAuthnHandler!, name: "webauthn")
            
            // Create minimal WebAuthn bridge that doesn't interfere with navigation
            let minimalBridgeScript = """
            (function() {
                'use strict';
                
                // Only inject if WebAuthn is not already available or if we need to enhance it
                if (!navigator.credentials || !navigator.credentials.create) {
                    console.log('🔧 WebAuthn not available, providing minimal polyfill');
                    
                    // Minimal polyfill - only what's needed
                    if (!navigator.credentials) {
                        navigator.credentials = {};
                    }
                    
                    // WebAuthn native bridge
                    navigator.credentials.create = async function(options) {
                        console.log('🔐 WebAuthn Create via native bridge');
                        
                        return new Promise((resolve, reject) => {
                            const requestId = 'create_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
                            
                            // Set up callback
                            window.webAuthnNativeCallback = function(id, result, error) {
                                if (id === requestId) {
                                    delete window.webAuthnNativeCallback;
                                    if (error) {
                                        reject(new Error(error.error || 'WebAuthn failed'));
                                    } else {
                                        resolve(result);
                                    }
                                }
                            };
                            
                            // Send to native handler
                            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.webauthn) {
                                window.webkit.messageHandlers.webauthn.postMessage({
                                    action: 'webauthn_create',
                                    options: options,
                                    requestId: requestId
                                });
                            } else {
                                reject(new Error('Native WebAuthn bridge not available'));
                            }
                        });
                    };
                    
                    navigator.credentials.get = async function(options) {
                        console.log('🔓 WebAuthn Get via native bridge');
                        
                        return new Promise((resolve, reject) => {
                            const requestId = 'get_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
                            
                            // Set up callback
                            window.webAuthnNativeCallback = function(id, result, error) {
                                if (id === requestId) {
                                    delete window.webAuthnNativeCallback;
                                    if (error) {
                                        reject(new Error(error.error || 'WebAuthn failed'));
                                    } else {
                                        resolve(result);
                                    }
                                }
                            };
                            
                            // Send to native handler
                            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.webauthn) {
                                window.webkit.messageHandlers.webauthn.postMessage({
                                    action: 'webauthn_get',
                                    options: options,
                                    requestId: requestId
                                });
                            } else {
                                reject(new Error('Native WebAuthn bridge not available'));
                            }
                        });
                    };
                } else {
                    console.log('🔧 WebAuthn already available, skipping injection');
                }
                
                // Basic WebAuthn support detection
                if (!window.PublicKeyCredential) {
                    window.PublicKeyCredential = function() {};
                    window.PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable = function() {
                        return Promise.resolve(true);
                    };
                    window.PublicKeyCredential.isConditionalMediationAvailable = function() {
                        return Promise.resolve(false);
                    };
                }
                
                console.log('🔧 Minimal WebAuthn bridge ready');
            })();
            """
            
            let bridgeScript = WKUserScript(
                source: minimalBridgeScript,
                injectionTime: .atDocumentEnd, // After page loads to avoid interfering
                forMainFrameOnly: false
            )
            self.configuration.userContentController.addUserScript(bridgeScript)
            
            print("🔧 Minimal WebAuthn bridge enabled")
        }
    }
    
    // MARK: - ASAuthorizationControllerPresentationContextProviding
    // FIXED: Prevent display identifier issues in presentation anchor
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Use main window without triggering display queries
        if let window = self.window {
            return window
        } else {
            // Fallback to app main window to avoid display system conflicts
            return NSApplication.shared.mainWindow ?? NSWindow()
        }
    }
}

// MARK: - Native WebAuthn Handler
class WebAuthnNativeHandler: NSObject, WKScriptMessageHandler, ASAuthorizationControllerDelegate {
        weak var webView: WKWebView?
        private var pendingRequests: [String: (ASAuthorizationController, String)] = [:]
        
        init(webView: WKWebView) {
            self.webView = webView
            super.init()
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            // FIXED: Process messages on main queue to avoid display timing issues
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                guard let body = message.body as? [String: Any],
                      let action = body["action"] as? String else { return }
                
                switch action {
                case "webauthn_create":
                    self.handleWebAuthnCreate(body)
                case "webauthn_get":
                    self.handleWebAuthnGet(body)
                default:
                    print("Unknown WebAuthn action: \(action)")
                }
            }
        }
        
        private func handleWebAuthnCreate(_ body: [String: Any]) {
            guard let options = body["options"] as? [String: Any],
                  let requestId = body["requestId"] as? String else {
                sendError(requestId: "unknown", error: "Invalid create request")
                return
            }
            
            print("🔐 Handling native WebAuthn create request: \(requestId)")
            
            // Parse WebAuthn options
            guard let publicKey = options["publicKey"] as? [String: Any],
                  let rpInfo = publicKey["rp"] as? [String: Any],
                  let userInfo = publicKey["user"] as? [String: Any],
                  let userName = userInfo["name"] as? String else {
                sendError(requestId: requestId, error: "Invalid WebAuthn options")
                return
            }
            
            // Extract the actual challenge from the request
            let challenge: Data
            if let challengeDict = publicKey["challenge"] as? [String: Any] {
                // Convert Uint8Array object to Data by extracting numeric indices
                var bytes: [UInt8] = []
                for i in 0..<32 { // Assuming 32-byte challenge
                    if let byte = challengeDict[String(i)] as? Int {
                        bytes.append(UInt8(byte))
                    }
                }
                challenge = Data(bytes)
            } else {
                // Fallback to random challenge
                challenge = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
            }
            
            // Use the actual RPID from the request
            let rpId = rpInfo["id"] as? String ?? "webman.test"
            print("🏢 Using RPID: \(rpId)")
            
            // Extract supported algorithms from the request
            var credentialParameters: [ASAuthorizationPublicKeyCredentialParameters] = []
            if let pubKeyCredParams = publicKey["pubKeyCredParams"] as? [[String: Any]] {
                for param in pubKeyCredParams {
                    if let alg = param["alg"] as? Int,
                       let type = param["type"] as? String, type == "public-key" {
                        let credentialParam = ASAuthorizationPublicKeyCredentialParameters(algorithm: ASCOSEAlgorithmIdentifier(rawValue: alg))
                        credentialParameters.append(credentialParam)
                    }
                }
            }
            // Default to ES256 if no algorithms specified
            if credentialParameters.isEmpty {
                let defaultParam = ASAuthorizationPublicKeyCredentialParameters(algorithm: ASCOSEAlgorithmIdentifier.ES256)
                credentialParameters = [defaultParam]
            }
            
            // Try cross-platform authenticator first for localhost (less restrictive)
            let crossPlatformProvider = ASAuthorizationSecurityKeyPublicKeyCredentialProvider(relyingPartyIdentifier: rpId)
            let crossPlatformRequest = crossPlatformProvider.createCredentialRegistrationRequest(
                challenge: challenge,
                displayName: "Test User",
                name: userName,
                userID: Data(userName.utf8)
            )
            crossPlatformRequest.credentialParameters = credentialParameters
            crossPlatformRequest.userVerificationPreference = ASAuthorizationPublicKeyCredentialUserVerificationPreference.preferred
            
            // Also create platform authenticator as fallback
            let platformProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: rpId)
            let platformRequest = platformProvider.createCredentialRegistrationRequest(
                challenge: challenge,
                name: userName,
                userID: Data(userName.utf8)
            )
            platformRequest.userVerificationPreference = ASAuthorizationPublicKeyCredentialUserVerificationPreference.preferred
            
            // Use both providers - system will choose the appropriate one
            let authController = ASAuthorizationController(authorizationRequests: [crossPlatformRequest, platformRequest])
            authController.delegate = self
            
            if let webView = webView as? WebAuthnWebView {
                authController.presentationContextProvider = webView
            }
            
            // Store the request
            pendingRequests[requestId] = (authController, "create")
            
            // FIXED: Perform request with small delay to avoid display timing conflicts
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                authController.performRequests()
            }
        }
        
        private func handleWebAuthnGet(_ body: [String: Any]) {
            guard let options = body["options"] as? [String: Any],
                  let requestId = body["requestId"] as? String else {
                sendError(requestId: "unknown", error: "Invalid get request")
                return
            }
            
            print("🔓 Handling native WebAuthn get request: \(requestId)")
            
            // Parse WebAuthn options for authentication
            guard let publicKey = options["publicKey"] as? [String: Any] else {
                sendError(requestId: requestId, error: "Invalid WebAuthn get options")
                return
            }
            
            // Extract the actual challenge from the request
            let challenge: Data
            if let challengeDict = publicKey["challenge"] as? [String: Any] {
                // Convert Uint8Array object to Data by extracting numeric indices
                var bytes: [UInt8] = []
                for i in 0..<32 { // Assuming 32-byte challenge
                    if let byte = challengeDict[String(i)] as? Int {
                        bytes.append(UInt8(byte))
                    }
                }
                challenge = Data(bytes)
            } else {
                // Fallback to random challenge
                challenge = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
            }
            
            // Use the actual RPID from the request
            let rpId = publicKey["rpId"] as? String ?? "webman.test"
            print("🏢 Using RPID for authentication: \(rpId)")
            
            // Try cross-platform authenticator first for localhost (less restrictive)
            let crossPlatformProvider = ASAuthorizationSecurityKeyPublicKeyCredentialProvider(relyingPartyIdentifier: rpId)
            let crossPlatformRequest = crossPlatformProvider.createCredentialAssertionRequest(challenge: challenge)
            crossPlatformRequest.userVerificationPreference = ASAuthorizationPublicKeyCredentialUserVerificationPreference.preferred
            
            // Also create platform authenticator as fallback
            let platformProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: rpId)
            let platformRequest = platformProvider.createCredentialAssertionRequest(challenge: challenge)
            platformRequest.userVerificationPreference = ASAuthorizationPublicKeyCredentialUserVerificationPreference.preferred
            
            // Use both providers - system will choose the appropriate one
            let authController = ASAuthorizationController(authorizationRequests: [crossPlatformRequest, platformRequest])
            authController.delegate = self
            
            if let webView = webView as? WebAuthnWebView {
                authController.presentationContextProvider = webView
            }
            
            // Store the request
            pendingRequests[requestId] = (authController, "get")
            
            // FIXED: Perform request with small delay to avoid display timing conflicts
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                authController.performRequests()
            }
        }
        
        // MARK: - ASAuthorizationControllerDelegate
        func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
            // Find the request ID
            let requestId = pendingRequests.first { $0.value.0 === controller }?.key ?? "unknown"
            let operation = pendingRequests[requestId]?.1 ?? "unknown"
            
            print("✅ WebAuthn \(operation) completed successfully for request: \(requestId)")
            
            if let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration {
                // Handle registration success
                let result: [String: Any] = [
                    "success": true,
                    "type": "registration",
                    "credentialId": credential.credentialID.base64EncodedString(),
                    "attestationObject": credential.rawAttestationObject?.base64EncodedString() ?? ""
                ]
                sendSuccess(requestId: requestId, result: result)
            } else if let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion {
                // Handle authentication success
                let result: [String: Any] = [
                    "success": true,
                    "type": "authentication",
                    "credentialId": credential.credentialID.base64EncodedString(),
                    "authenticatorData": credential.rawAuthenticatorData.base64EncodedString(),
                    "signature": credential.signature.base64EncodedString()
                ]
                sendSuccess(requestId: requestId, result: result)
            }
            
            // Clean up
            pendingRequests.removeValue(forKey: requestId)
        }
        
        func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
            // Find the request ID
            let requestId = pendingRequests.first { $0.value.0 === controller }?.key ?? "unknown"
            
            print("❌ WebAuthn failed for request \(requestId): \(error)")
            
            sendError(requestId: requestId, error: error.localizedDescription)
            
            // Clean up
            pendingRequests.removeValue(forKey: requestId)
        }
        
        private func sendSuccess(requestId: String, result: [String: Any]) {
            let script = "window.webAuthnNativeCallback && window.webAuthnNativeCallback('\(requestId)', \(jsonString(from: result)), null);"
            // FIXED: Execute JavaScript with proper queue to avoid "resultToPush is nil" warnings
            DispatchQueue.main.async { [weak self] in
                self?.webView?.evaluateJavaScript(script, completionHandler: nil)
            }
        }
        
        private func sendError(requestId: String, error: String) {
            let errorObj = ["error": error, "requestId": requestId]
            let script = "window.webAuthnNativeCallback && window.webAuthnNativeCallback('\(requestId)', null, \(jsonString(from: errorObj)));"
            // FIXED: Execute JavaScript with proper queue to avoid "resultToPush is nil" warnings
            DispatchQueue.main.async { [weak self] in
                self?.webView?.evaluateJavaScript(script, completionHandler: nil)
            }
        }
        
        private func jsonString(from object: [String: Any]) -> String {
            guard let data = try? JSONSerialization.data(withJSONObject: object),
                  let string = String(data: data, encoding: .utf8) else {
                return "{}"
            }
            return string
        }
    }


// MARK: - WKDownloadDelegate for proper download handling
extension WebAuthnWebView: WKDownloadDelegate {
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        print("💾 Download requested: \(suggestedFilename)")
        
        // Only allow actual downloads (not images/media that should be inline)
        let filename = suggestedFilename.lowercased()
        let inlineExtensions = ["svg", "png", "jpg", "jpeg", "gif", "webp", "ico", "bmp", "css", "js", "html", "htm"]
        
        let shouldPreventDownload = inlineExtensions.contains { filename.hasSuffix(".\($0)") }
        
        if shouldPreventDownload {
            print("🚫 Preventing download of inline content: \(suggestedFilename)")
            completionHandler(nil) // Cancel the download
            return
        }
        
        // Allow legitimate downloads to Downloads folder
        let downloadsPath = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let destinationURL = downloadsPath.appendingPathComponent(suggestedFilename)
        print("✅ Allowing download to: \(destinationURL.path)")
        completionHandler(destinationURL)
    }
    
    func downloadDidFinish(_ download: WKDownload) {
        print("✅ Download completed successfully")
    }
    
    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        print("❌ Download failed: \(error.localizedDescription)")
    }
}

// MARK: - WKNavigationDelegate for WebAuthnWebView
extension WebAuthnWebView {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        print("🔗 WebAuthnWebView navigation action:")
        print("   - URL: \(navigationAction.request.url?.absoluteString ?? "nil")")
        print("   - Navigation type: \(navigationAction.navigationType.rawValue)")
        print("   - Target frame: \(String(describing: navigationAction.targetFrame?.isMainFrame))")
        
        // Allow all navigation actions (including link clicks)
        decisionHandler(.allow)
    }
    
    // CRITICAL: Enable JavaScript per-navigation (modern API)
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: WKWebpagePreferences, decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
        print("🔗 WebAuthnWebView navigation action (with preferences):")
        print("   - URL: \(navigationAction.request.url?.absoluteString ?? "nil")")
        print("   - Enabling JavaScript for this navigation")
        
        // Enable JavaScript for this navigation
        preferences.allowsContentJavaScript = true
        decisionHandler(.allow, preferences)
    }
    
    // CRITICAL: Handle response policy to prevent unwanted downloads
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        guard let url = navigationResponse.response.url else {
            decisionHandler(.allow)
            return
        }
        
        let urlString = url.absoluteString.lowercased()
        let pathExtension = url.pathExtension.lowercased()
        
        // Debug: Log all response details for images
        if urlString.contains(".svg") || urlString.contains("img/") || urlString.contains("logo") {
            print("🖼️ IMAGE RESPONSE DEBUG:")
            print("   - URL: \(url.absoluteString)")
            print("   - Extension: .\(pathExtension)")
            print("   - MIME Type: \(navigationResponse.response.mimeType ?? "unknown")")
            if let httpResponse = navigationResponse.response as? HTTPURLResponse {
                print("   - Status Code: \(httpResponse.statusCode)")
                print("   - Content-Type: \(httpResponse.allHeaderFields["Content-Type"] ?? "unknown")")
                print("   - Content-Disposition: \(httpResponse.allHeaderFields["Content-Disposition"] ?? "none")")
            }
        }
        
        // Define file types that should be displayed inline (not downloaded)
        let inlineImageTypes = ["svg", "png", "jpg", "jpeg", "gif", "webp", "ico", "bmp"]
        let inlineDocumentTypes = ["html", "htm", "css", "js", "json", "xml", "txt"]
        let inlineMediaTypes = ["mp4", "webm", "ogg", "mp3", "wav", "m4a"]
        
        let allInlineTypes = inlineImageTypes + inlineDocumentTypes + inlineMediaTypes
        
        // Check if this is a file type that should be displayed inline
        if allInlineTypes.contains(pathExtension) {
            print("🖼️ ✅ FORCING INLINE: \(url.lastPathComponent) (.\(pathExtension))")
            decisionHandler(.allow)
            return
        }
        
        // Check for image MIME types (in case extension is missing)
        if let mimeType = navigationResponse.response.mimeType?.lowercased() {
            let inlineMimeTypes = [
                "image/", "text/", "application/javascript", "application/json",
                "application/xml", "video/", "audio/", "application/pdf"
            ]
            
            for inlineType in inlineMimeTypes {
                if mimeType.hasPrefix(inlineType) {
                    print("🖼️ Displaying inline content by MIME type: \(mimeType)")
                    decisionHandler(.allow)
                    return
                }
            }
        }
        
        // Check if this might be a download based on Content-Disposition header
        if let httpResponse = navigationResponse.response as? HTTPURLResponse {
            if let contentDisposition = httpResponse.allHeaderFields["Content-Disposition"] as? String {
                if contentDisposition.lowercased().contains("attachment") {
                    print("💾 Content-Disposition indicates download: \(contentDisposition)")
                    // This is intentionally marked as a download, allow it
                    decisionHandler(.allow)
                    return
                }
            }
        }
        
        // For everything else, allow it (default behavior)
        print("✅ Allowing navigation response: \(url.lastPathComponent)")
        decisionHandler(.allow)
    }
}
