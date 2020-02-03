//
//  User.swift
//  App
//
//  Created by Ben Schultz on 1/30/20.
//

import Foundation
import FluentMySQL
import Vapor

struct User: Content, MySQLModel, Migration {
    var id: Int?
    var name: String
    var emailAddress: String
    var passwordHash: String
    
    func persistInfo() -> UserPersistInfo? {
        guard let id = self.id else { return nil }
        return UserPersistInfo (id: id, name: self.name, emailAddress: self.emailAddress)
    }
    
    func redirectRouteAfterLogin(_ req: Request) throws -> Future<Response> {
        // TODO:  use the user's permissions and properties to figure out the
        //        best default spot for them to be redirected.
        return req.future().map() {
            // TODO:  Fix this.  Just putting /security/login -> 404
            return req.redirect(to: "http://localhost:8080/TBTable")
        }
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

struct UserPersistInfo: Codable {
    // Non-secret struct represntation of a user that can be saved in the session
    var id: Int
    var name: String
    var emailAddress: String
}
