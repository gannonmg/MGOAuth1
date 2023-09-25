//
//  OAuth+Help.swift
//  MGOAuth
//
//  Created by Matt Gannon on 7/20/22.
//

import CommonCrypto
import Foundation
import MGKeychain

extension CharacterSet {
    static var urlRFC3986Allowed: CharacterSet {
        CharacterSet(charactersIn: "-_.~").union(.alphanumerics)
    }
}

extension String {
    var oAuthURLEncodedString: String {
        self.addingPercentEncoding(withAllowedCharacters: .urlRFC3986Allowed) ?? self
    }
    
    var urlQueryItems: [URLQueryItem]? {
        URLComponents(string: "://?\(self)")?.queryItems
    }
    
    static func generateNonce() -> String {
        let uuidString: String = UUID().uuidString
        return String(uuidString.prefix(8))
    }
    
    static var currentTimestamp: String {
        return String(Int(Date().timeIntervalSince1970))
    }
    
    func hmacSHA1Hash(key: String) -> String {
        let length: Int = Int(CC_SHA1_DIGEST_LENGTH)
        var digest: [UInt8] = .init(repeating: 0, count: length)
        let algorithm: CCHmacAlgorithm = CCHmacAlgorithm(kCCHmacAlgSHA1)
        CCHmac(algorithm, key, key.count,
               self, self.count, &digest)
        return Data(digest).base64EncodedString()
    }
}

// MARK: - Query array helpers
extension Array where Element == URLQueryItem {
    private func value(for name: String) -> String? {
        return self.filter({$0.name == name}).first?.value
    }
    
    subscript(name: String) -> String? {
        return value(for: name)
    }
}

// MARK: - URL Error
extension URL {
    struct BadURLError: Error {
        let urlString: String
        
        init(_ urlString: String) {
            self.urlString = urlString
        }
        
        var localizedDescription: String {
            return "Bad URL: \(urlString)"
        }
    }

    init(string: String) throws {
        guard let url: URL = .init(string: string) else { throw BadURLError(string) }
        self = url
    }
    
    func absoluteStringByTrimmingQuery() throws -> String {
        guard var urlComponents: URLComponents = .init(url: self, resolvingAgainstBaseURL: false) else {
            throw OAuthError.failedUrlStrippingQueries
        }
        
        urlComponents.query = nil
        
        guard let componentsString: String = urlComponents.string else {
            throw OAuthError.failedUrlStrippingQueries
        }
        
        return componentsString
    }
}
