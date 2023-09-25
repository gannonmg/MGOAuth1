//
//  OAuth.swift
//  MGOAuth
//
//  Created by Matt Gannon on 7/20/22.
//
//  https://medium.com/codex/how-to-implement-twitter-api-v1-authentication-in-swiftui-2dc4e93f7a82
//

import Foundation
import MGKeychain

public final class OAuthManager: OAuthAuthorizer {
    
    public var config: OAuthConfiguration
    public var temporaryCredentials: TemporaryCredentials?
    public var tokenCredentials: TokenCredentials? {
        do {
            let token: String = try KeychainManager.shared.get(for: tokenLocation)
            let secret: String = try KeychainManager.shared.get(for: secretLocation)
            return TokenCredentials(accessToken: token, accessTokenSecret: secret)
        } catch {
            print("OAuth: Failed to get token. \(error)")
            return nil
        }
    }
    
    public var isAuthenticated: Bool {
        return tokenCredentials != nil
    }

    public init(config: OAuthConfiguration) {
        self.config = config
    }
    
    public func clearCredentials() throws {
        try KeychainManager.shared.remove(key: tokenLocation)
        try KeychainManager.shared.remove(key: secretLocation)
    }
}

