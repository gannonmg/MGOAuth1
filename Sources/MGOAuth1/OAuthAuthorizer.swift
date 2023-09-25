//
//  OAuthAuthorizer.swift
//  MGOAuth
//
//  Created by Matt Gannon on 8/12/22.
//

import Foundation
import MGKeychain

public protocol OAuthAuthorizer: AnyObject {
    var isAuthenticated: Bool { get }
    var config: OAuthConfiguration { get }
    var temporaryCredentials: TemporaryCredentials? { get set }
    var tokenCredentials: TokenCredentials? { get }
    var tokenLocation: String { get }
    var secretLocation: String { get }
    func getAuthorizeUrl() async throws -> URL
    func handleOAuthRedirect(from url: URL) async throws
}

extension OAuthAuthorizer {
    
    // MARK: Temporary Credentials
    public func getAuthorizeUrl() async throws -> URL {
        let temporaryCredentials: TemporaryCredentials = try await getTemporaryCredentials()
        self.temporaryCredentials = temporaryCredentials
        
        let authUrlString: String = "\(config.authorizeUrl)?oauth_token=\(temporaryCredentials.requestToken)"
        return try URL(string: authUrlString)
    }

    private func getTemporaryCredentials() async throws -> TemporaryCredentials {
        let authorizationType: AuthorizedRequestType = .temporary(urlString: config.requestTokenUrl)
        let urlRequest: URLRequest = try buildOAuthRequest(for: authorizationType)
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        let parameters: [URLQueryItem] = try getResponseParameters(for: response, data: data)
        let temporaryCredentials: TemporaryCredentials = try parseTemporaryCredentials(from: parameters)
        return temporaryCredentials
    }
    
    // MARK: Access Token Credentials
    public func handleOAuthRedirect(from url: URL) async throws {
        let token: TokenCredentials = try await getCredentialsFromRedirect(url)
        try KeychainManager.shared.save(key: tokenLocation, value: token.accessToken)
        try KeychainManager.shared.save(key: secretLocation, value: token.accessTokenSecret)
    }
    
    private func getCredentialsFromRedirect(_ url: URL) async throws -> TokenCredentials {
        guard let tempCredentials = temporaryCredentials else {
            throw OAuthError.noCredentialsOnRedirect
        }
        
        guard let parameters = url.query?.urlQueryItems else {
            throw OAuthError.cannotParseResponse
        }
        
        guard let oAuthToken = parameters["oauth_token"],
              let oAuthVerifier = parameters["oauth_verifier"] else {
            throw OAuthError.noVerifiedTokens
        }
        
        if oAuthToken != tempCredentials.requestToken {
            throw OAuthError.credentialsDidNotMatch
        }

        let tokenCredentials: TokenCredentials = try await getTokenCredentials(
            temporaryCredentials: tempCredentials,
            verifier: oAuthVerifier
        )
        
        return tokenCredentials
    }
    
    private func getTokenCredentials(temporaryCredentials: TemporaryCredentials, verifier: String) async throws -> TokenCredentials {
        let authorizationType: AuthorizedRequestType = .access(
            urlString: config.accessTokenUrl,
            temporaryCredentials: temporaryCredentials,
            verifier: verifier
        )
        
        let urlRequest: URLRequest = try buildOAuthRequest(for: authorizationType)
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        let parameters: [URLQueryItem] = try getResponseParameters(for: response, data: data)
        let tokenCredentials: TokenCredentials = try parseTokenCredentials(from: parameters)
        return tokenCredentials
    }
    
    // MARK: Response Parser
    private func getResponseParameters(for response: URLResponse, data: Data) throws -> [URLQueryItem] {
        guard let response = response as? HTTPURLResponse else {
            throw OAuthError.unknown
        }
        
        guard response.statusCode == 200 else {
            throw OAuthError.httpURLResponse(response.statusCode)
        }
        
        guard let parameterString = String(data: data, encoding: .utf8) else {
            throw OAuthError.cannotDecodeRawData
        }
        
        guard let parameters = parameterString.urlQueryItems else {
            throw OAuthError.unexpectedResponse
        }
        
        guard !parameters.isEmpty else {
            throw OAuthError.responseParametersEmpty
        }
        
        return parameters
    }
    
    private func parseTemporaryCredentials(from parameters: [URLQueryItem]) throws -> TemporaryCredentials {
        guard let oAuthToken = parameters["oauth_token"],
              let oAuthTokenSecret = parameters["oauth_token_secret"],
              let oAuthCallbackConfirmed = parameters["oauth_callback_confirmed"]
        else { throw OAuthError.unexpectedResponse }
        
        guard oAuthCallbackConfirmed == "true" else {
            throw OAuthError.failedToConfirmCallback
        }

        return TemporaryCredentials(requestToken: oAuthToken, requestTokenSecret: oAuthTokenSecret)
    }
    
    private func parseTokenCredentials(from parameters: [URLQueryItem]) throws -> TokenCredentials {
        guard let oAuthToken = parameters["oauth_token"],
              let oAuthTokenSecret = parameters["oauth_token_secret"]
        else { throw OAuthError.cannotParseResponse }
        
        return TokenCredentials(accessToken: oAuthToken, accessTokenSecret: oAuthTokenSecret)
    }
    
    // MARK: Request Builder
    private func buildOAuthRequest(for authType: AuthorizedRequestType) throws -> URLRequest {
        let baseURL: URL = try authType.url
        let baseURLStringMinusQueries: String = try baseURL.absoluteStringByTrimmingQuery()
        
        var parameters: [URLQueryItem] = [
            .init(name: "oauth_consumer_key", value: config.consumerKey),
            .init(name: "oauth_nonce", value: .generateNonce()),
            .init(name: "oauth_signature_method", value: "HMAC-SHA1"),
            .init(name: "oauth_timestamp", value: .currentTimestamp),
            .init(name: "oauth_version", value: "1.0")
        ]
        
        switch authType {
        case .temporary:
            let callbackItem: URLQueryItem = .init(name: "oauth_callback", value: config.callback)
            parameters.append(callbackItem)
        case .access(_, let temporaryCredentials, let verifier):
            let tokenItem: URLQueryItem = .init(name: "oauth_token", value: temporaryCredentials.requestToken)
            let verifierItem: URLQueryItem = .init(name: "oauth_verifier", value: verifier)
            parameters.append(contentsOf: [tokenItem, verifierItem])
        case .get(_, let token):
            let tokenItem: URLQueryItem = .init(name: "oauth_token", value: token.accessToken)
            parameters.append(tokenItem)
        }
        
        // Append non-oauth parameters
        parameters.append(contentsOf: baseURL.query?.urlQueryItems ?? [])
        
        let signature: String = oAuthSignature(
            httpMethod: authType.httpMethod.method,
            baseURLString: baseURLStringMinusQueries,
            parameters: parameters,
            consumerSecret: config.consumerSecret,
            oAuthTokenSecret: authType.secret
        )
        
        let signatureItem: URLQueryItem = .init(name: "oauth_signature", value: signature)
        parameters.append(signatureItem)
        
        var urlRequest: URLRequest = .init(url: baseURL)
        urlRequest.httpMethod = authType.httpMethod.method
        let authorizationHeader: String = oAuthAuthorizationHeader(parameters: parameters)
        urlRequest.setValue(authorizationHeader, forHTTPHeaderField: "Authorization")
        return urlRequest
    }
    
    // MARK: Request Building Helpers
    /// Builds the hashed signature to be sent with the `"oauth\_signature"` parameter in the request header
    private func oAuthSignature(httpMethod: String, baseURLString: String, parameters: [URLQueryItem], consumerSecret: String, oAuthTokenSecret: String? = nil) -> String {
        let signatureBaseString: String = oAuthSignatureBaseString(
            httpMethod: httpMethod,
            baseURLString: baseURLString,
            parameters: parameters
        )
        
        let signingKey: String = oAuthSigningKey(
            consumerSecret: consumerSecret,
            oAuthTokenSecret: oAuthTokenSecret
        )
        
        return signatureBaseString.hmacSHA1Hash(key: signingKey)
    }
    
    /// Creates the OAuth signature's base string, to be hashed with the signing key.
    private func oAuthSignatureBaseString(httpMethod: String, baseURLString: String, parameters: [URLQueryItem]) -> String {
        var parameterComponents: [String] = []
        for parameter in parameters {
            let name = parameter.name.oAuthURLEncodedString
            let value = parameter.value?.oAuthURLEncodedString ?? ""
            parameterComponents.append("\(name)=\(value)")
        }
        
        let parameterString = parameterComponents.sorted().joined(separator: "&")
        let signatureBaseString = [
            httpMethod,
            baseURLString.oAuthURLEncodedString,
            parameterString.oAuthURLEncodedString
        ].joined(separator: "&")
        
        return signatureBaseString
    }
    
    /// Creates a URL encoded signing key from the provided consumer secret and optional token secret.
    private func oAuthSigningKey(consumerSecret: String, oAuthTokenSecret: String?) -> String {
        if let oAuthTokenSecret = oAuthTokenSecret {
            return consumerSecret.oAuthURLEncodedString + "&" + oAuthTokenSecret.oAuthURLEncodedString
        } else {
            return consumerSecret.oAuthURLEncodedString + "&"
        }
    }
    
    /// Creates a URL encoded Authorization header from the oauth query items
    private func oAuthAuthorizationHeader(parameters: [URLQueryItem]) -> String {
        var parameterComponents: [String] = []
        for parameter in parameters {
            let name = parameter.name.oAuthURLEncodedString
            let value = parameter.value?.oAuthURLEncodedString ?? ""
            parameterComponents.append("\(name)=\"\(value)\"")
        }
        
        return "OAuth " + parameterComponents.sorted().joined(separator: ", ")
    }
}

public extension OAuthAuthorizer {
    func get<T: Codable>(from urlString: String) async throws -> T {
        guard let token = tokenCredentials else {
            throw OAuthError.missingAccessToken
        }
        
        let request: AuthorizedRequestType = .get(urlString: urlString, token: token)
        let urlRequest: URLRequest = try buildOAuthRequest(for: request)
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let response = response as? HTTPURLResponse else {
            throw OAuthError.unknown
        }
        
        guard response.statusCode == 200 else {
            throw OAuthError.httpURLResponse(response.statusCode)
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: Keychain Helpers
extension OAuthAuthorizer {
    public var tokenLocation: String { config.callback + "_key" }
    public var secretLocation: String { config.callback + "_secret" }
}
