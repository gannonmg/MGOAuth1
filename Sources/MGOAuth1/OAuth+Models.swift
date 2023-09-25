//
//  OAuth+Models.swift
//  MGOAuth
//
//  Created by Matt Gannon on 8/11/22.
//

import Foundation

public struct TemporaryCredentials {
    let requestToken: String
    let requestTokenSecret: String
}

public struct TokenCredentials {
    let accessToken: String
    let accessTokenSecret: String
}

enum OAuthError: Error {
    case unknown
    case httpURLResponse(Int)
    case cannotDecodeRawData
    case cannotParseResponse
    case unexpectedResponse
    case responseParametersEmpty
    case failedToConfirmCallback
    case noVerifiedTokens
    case noCredentialsOnRedirect
    case credentialsDidNotMatch
    case missingAccessToken
    case failedUrlStrippingQueries
}
