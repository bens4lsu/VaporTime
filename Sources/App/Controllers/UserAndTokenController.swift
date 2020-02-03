//
//  UserAndTokenController.swift
//  App
//
//  Created by Ben Schultz on 1/30/20.
//

import Foundation
import Vapor
import FluentMySQL
import Crypto

class UserAndTokenController: RouteCollection {
    
    // TODO:  move time interval and secret to configuration
    private let secretKey = "Daisywasasweetsweetdog"
    private let tokenExpDuration: Double = 3600         // seconds
    
    func boot(router: Router) throws {
        router.group("security") { group in
            group.get("login", use: displayLogin)
            group.get("create", use: displayUserCreate)
            
            group.post("login", use: login)
            group.post("create", use: createUser)
        }
    }
    
    // MARK:  Methods connected to routes that return Views
    private func displayLogin(_ req: Request) throws -> Future<View> {
        return try req.view().render("users-login")
    }
    
    private func displayUserCreate(_ req: Request) throws -> Future<View> {
        return try req.view().render("users-create")
    }
    
    
    // MARK:  Methods connected to routes that return data
    
    private func login(_ req: Request) throws -> Future<Response> {
        let email: String = try req.content.syncGet(at: "email")
        let password: String = try req.content.syncGet(at: "password")
        
        guard email.count > 0, password.count > 0 else {
            throw Abort(.badRequest)
        }
        
        return User.query(on: req).filter(\User.emailAddress == email).all().flatMap(to: Response.self) { userMatches in
            
            guard userMatches.count < 2 else {
                throw Abort(.unauthorized, reason: "More than one user exists with that email address.")
            }
            
            guard userMatches.count == 1 else {
                throw Abort(.unauthorized, reason: "No user exists for that email address.")
            }
            
            let user = userMatches[0]
            // verify that password submitted matches
            guard try BCrypt.verify(password, created: user.passwordHash) else {
                throw Abort(.unauthorized, reason: "Could not verify password.")
            }
            // login success
            let session = try req.session()
            let userPersistInfo = user.persistInfo()!
            let ip = req.http.remotePeer.hostname
            let token = try Token(user: userPersistInfo, exp: Date().addingTimeInterval(self.tokenExpDuration), ip: ip).encode()
            print (token)
            session["token"] = token
            return try user.redirectRouteAfterLogin(req)
        }
    }
    
    
    private func createUser(_ req: Request) throws -> Future<User> {
        struct FormData: Decodable {
            var emailAddress: String?
            var password: String?
            var name: String?
        }
        let form = try req.content.syncDecode(FormData.self)
        guard let emailAddress = form.emailAddress,
            let password = form.password,
            let name = form.name,
            let passwordHash = try? BCrypt.hash(password)
        else {
            throw Abort(.partialContent, reason: "All fields on create user form are requird")
        }
        let newUser = User(id: nil, name: name, emailAddress: emailAddress, passwordHash: passwordHash)
        return newUser.create(on: req)
    }


// MARK: Static methods
    
    static func redirectToLogin(_ req: Request) -> Future<Response> {
        return req.future().map() {
            // TODO:  Fix this.  Just putting /security/login -> 404
            return req.redirect(to: "http://localhost:8080/security/login")
        }
    }
    
    static func verifyAccess(_ req: Request, onSuccess: (_: UserPersistInfo) throws -> Future<Response>) throws -> Future<Response> {
        guard let session = try? req.session(),
              let tokenJSON = session["token"] else
        {
            return UserAndTokenController.redirectToLogin(req)
        }
        print (tokenJSON)
        let decoder = JSONDecoder()
        let token = try decoder.decode(Token.self, from: tokenJSON)
        
        guard token.exp >= Date() || token.ip != req.http.remotePeer.hostname else {
            // token is expired, or ip address has changed
            return UserAndTokenController.redirectToLogin(req)
        }
        return try onSuccess(token.user)
    }

}


