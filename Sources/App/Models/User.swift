//
//  User.swift
//  App
//
//  Created by Ben Schultz on 1/30/20.
//

import Foundation
import FluentMySQL
import Vapor
import JWT

struct User: Content, MySQLModel, Migration {
    var id: Int?
    var name: String
    var emailAddress: String
    var passwordHash: String
    
    func jwtInfo() -> UserJWTInfo? {
        guard let id = self.id else { return nil }
        return UserJWTInfo (id: id, name: self.name, emailAddress: self.emailAddress)
    }
}

// MARK: Validatable Protocol Conformation
extension User: Validatable {
    static func validations() throws -> Validations<User> {
        var validations = Validations(User.self)
        try validations.add(\.emailAddress, .email)
        return validations
    }
}

struct UserJWTInfo: JWTPayload {
    var id: Int
    var name: String
    var emailAddress: String
    
    func verify(using signer: JWTSigner) throws {
         // nothing to verify
     }
}
