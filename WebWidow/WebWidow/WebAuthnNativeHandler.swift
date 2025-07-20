import Foundation
import WebKit
import AuthenticationServices

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
            let rpId = rpInfo["id"] as? String ?? "WebWidow.test"
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
            let rpId = publicKey["rpId"] as? String ?? "WebWidow.test"
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
