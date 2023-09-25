//
//  AuthorizationType.swift
//  MGOAuth
//
//  Created by Matt Gannon on 8/12/22.
//

import Foundation

public enum HTTPMethod {
    case get, post, put, patch, delete
    
    var method: String {
        switch self {
        case .get: return "GET"
        case .post: return "POST"
        case .put: return "PUT"
        case .patch: return "PATCH"
        case .delete: return "DELETE"
        }
    }
}

enum AuthorizedRequestType {
    case temporary(urlString: String)
    case access(urlString: String, temporaryCredentials: TemporaryCredentials, verifier: String)
    case get(urlString: String, token: TokenCredentials)
    
    var url: URL {
        get throws {
            return try URL(string: baseUrlString)
        }
    }

    var baseUrlString: String {
        switch self {
        case .temporary(let urlString), .access(let urlString, _, _), .get(let urlString, _):
            return urlString
        }
    }
    
    var secret: String? {
        switch self {
        case .access(_, let temporaryCredentials, _):
            return temporaryCredentials.requestTokenSecret
        case .get(_, let token):
            return token.accessTokenSecret
        default:
            return nil
        }
    }
    
    var httpMethod: HTTPMethod {
        switch self {
        case .temporary, .access:
            return .post
        case .get:
            return .get
        }
    }
}
