//
//  OAuthObservable.swift
//  MGOAuth
//
//  Created by Matt Gannon on 7/20/22.
//

import SwiftUI

public final class OAuthObservable: ObservableObject {
    
    @Published public var authorizationSheetIsPresented = false
    @Published public var authorizationURL: URL?
    public var isLoggedIn: Bool { manager.isAuthenticated }

    public let manager: OAuthManager
    
    public init(config: OAuthConfiguration) {
        self.manager = .init(config: config)
    }
    
    @MainActor
    public func authorize() {
        guard !self.authorizationSheetIsPresented else { return }
        self.authorizationSheetIsPresented = true
        Task {
            do {
                self.authorizationURL = try await manager.getAuthorizeUrl()
            } catch {
                print("Failed authorization: \(error)")
                self.authorizationSheetIsPresented = false
            }
        }
    }
    
    func onOAuthRedirect(_ url: URL) throws {
        self.authorizationSheetIsPresented = false
        self.authorizationURL = nil
        
        Task {
            do {
                try await manager.handleOAuthRedirect(from: url)
            } catch {
                print("Failed to get credentials from redirect. Error: \(error)")
            }
        }
    }
}
