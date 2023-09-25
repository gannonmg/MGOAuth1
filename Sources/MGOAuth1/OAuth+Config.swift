//
//  OAuthConfig.swift
//  MGOAuth
//
//  Created by Matt Gannon on 8/12/22.
//

import Foundation

public struct OAuthConfiguration {
    let client: String
    let consumerKey: String
    let consumerSecret: String
    let callback: String
    let callbackScheme: String
    let requestTokenUrl: String
    let authorizeUrl: String
    let accessTokenUrl: String
    
    public init(
        client: String,
        consumerKey: String,
        consumerSecret: String,
        callback: String,
        callbackScheme: String,
        requestTokenUrl: String,
        authorizeUrl: String,
        accessTokenUrl: String
    ) {
        self.client = client
        self.consumerKey = consumerKey
        self.consumerSecret = consumerSecret
        self.callback = callback
        self.callbackScheme = callbackScheme
        self.requestTokenUrl = requestTokenUrl
        self.authorizeUrl = authorizeUrl
        self.accessTokenUrl = accessTokenUrl
    }
}
