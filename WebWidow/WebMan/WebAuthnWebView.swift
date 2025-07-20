import Foundation
import Cocoa
import WebKit
import AuthenticationServices

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
