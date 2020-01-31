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
import JWT

class UserAndTokenController: RouteCollection {
    
    // TODO:  move time interval and secret to configuration
    private let secretKey = "Daisywasasweetsweetdog"
    private let tokenExpDuration: Double = 3600
    
    enum ValidUser {
        case valid(UserJWTInfo)
        case invalid
        
        func asBool() -> Bool {
            switch self {
            case .valid:
                return true
            default:
                return false
            }
        }
    }
    
    func boot(router: Router) throws {
        router.group("security") { group in
            group.get("login", use: displayLogin)
            group.get("create", use: displayUserCreate)
            
            group.post("login", use: login)
            group.post("create", use: createUser)
            group.post("testJWT", use: testJwt)
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
    
    private func login(_ req: Request) throws -> Future<String> {
        let email: String = try req.content.syncGet(at: "email")
        let password: String = try req.content.syncGet(at: "password")
        
        guard email.count > 0, password.count > 0 else {
            throw Abort(.badRequest)
        }
        
        return User.query(on: req).filter(\User.emailAddress == email).all().flatMap(to: String.self) { userMatches in
            
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
            
            return try self.getJWT(user: user, req: req)
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

    private func testJwt(_ req: Request) throws -> Future<String> {
        guard case .valid(_) = try verifyJWT(req) else {
            return req.future("Error:  JWT signature is invalid, or JWT could not be decoded into <Token>")
        }
        return req.future("OK")

    }
    
    
    // MARK:  Methods used to validate JWT, potentially called by other controllers or routes
   
    func getJWT(user: User, req: Request) throws -> Future<String> {
        // generate a new token and send it back
        let newToken = Token(user: user.jwtInfo()!,
                             exp: Date().addingTimeInterval(self.tokenExpDuration),
                             ip: req.http.remotePeer.hostname)
        
        let jwtToken = try JWT(payload: newToken)
            .sign(using: .hs256(key: self.secretKey))
        
        let jwtString = String(data: jwtToken, encoding: .utf8) ?? ""
        print (jwtString)
        return req.future(jwtString)
    }
    
    func verifyJWT(_ req: Request) throws -> UserAndTokenController.ValidUser {
        // fetches the token from `Authorization: Bearer <token>` header
        guard let bearer = req.http.headers.bearerAuthorization else {
            throw Abort(.unauthorized)
        }
        
        // parse JWT from token string, using HS-256 signer
        if let token = try? JWT<Token>(from: bearer.token, verifiedUsing: .hs256(key: self.secretKey)) {
            return .valid(token.payload.user)
        }
        return .invalid
    }
}
