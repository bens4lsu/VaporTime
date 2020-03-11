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

enum UserAccessLevel: String, Codable {
    case timeBilling = "T"
    case admin = "A"
    case report = "R"
    case doc = "D"
    case crm = "C"
    case activeOnly = "X"
}

class UserAndTokenController: RouteCollection {
    
    static let tokenExpDuration = ConfigKeys().tokenExpDuration
        
    func boot(router: Router) throws {
        router.group("security") { group in
            group.get("login", use: renderLogin)
            group.get("create", use: renderUserCreate)
            group.get("change-password", use: renderUserCreate)
            
            group.post("login", use: login)
            group.post("create", use: createUser)
            group.post("change-password", use: changePassword)
        }
    }
    
    
    // MARK:  Methods connected to routes that return Views
    private func renderLogin(_ req: Request) throws -> Future<View> {
        return try req.view().render("users-login")
    }
    
    private func renderUserCreate(_ req: Request) throws -> Future<View> {
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
            guard user.isActive else {
                throw Abort(.unauthorized, reason: "User's system access has been revoked.")
            }
            
            // create access log entry
            let accessLog = AccessLog(personId: user.id!)
            return accessLog.save(on: req).flatMap(to: Response.self) { access in
                let userPersistInfo = user.persistInfo()!
                let ip = req.http.remotePeer.hostname
                if let accessId = access.id {
                    let token = Token(user: userPersistInfo,
                                      exp: Date().addingTimeInterval(UserAndTokenController.tokenExpDuration),
                                      ip: ip,
                                      accessLogId: accessId,
                                      loginTime: access.accessTime)
                    try UserAndTokenController.saveSessionInfo(req: req, info: token, sessionKey: "token")
                }
                return req.future().map() {
                    return req.redirect(to: "/")
                }
            }
        }
    }
    
    private func changePassword(_ req: Request) throws -> Future<User> {
        let email: String = try req.content.syncGet(at: "emailAddress")
        let password: String = try req.content.syncGet(at: "password")
        
        guard email.count > 0, password.count > 0 else {
            throw Abort(.badRequest)
        }
        
        return User.query(on: req).filter(\User.emailAddress == email).all().flatMap(to: User.self) { userMatches in
            
            guard userMatches.count < 2 else {
                throw Abort(.unauthorized, reason: "More than one user exists with that email address.")
            }
            
            guard userMatches.count == 1 else {
                throw Abort(.unauthorized, reason: "No user exists for that email address.")
            }
            
            var user = userMatches[0]
            let passwordHash = (try? BCrypt.hash(password)) ?? ""
            user.passwordHash = passwordHash
            return user.save(on: req)
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
    
    

// MARK: Static methods - used for verification in other controllers
    
    static func redirectToLogin(_ req: Request) -> Future<Response> {
        return req.future().map() {
            // TODO:  Fix this.  Just putting /security/login -> 404
            let session = try req.session()
            session["token"] = nil
            session["filter"] = nil
            return req.redirect(to: "./security/login")
        }
    }

    
    static func verifyAccess(_ req: Request, accessLevel: UserAccessLevel, onSuccess: @escaping (_: UserPersistInfo) throws -> Future<Response>) throws -> Future<Response> {
        guard let temp: Token? =  try? getSessionInfo(req: req, sessionKey: "token"),
            var token = temp else {
            return UserAndTokenController.redirectToLogin(req)
        }
                
        guard token.exp >= Date() || token.ip != req.http.remotePeer.hostname else {
            // token is expired, or ip address has changed
            return UserAndTokenController.redirectToLogin(req)
        }
        
        if !token.user.access.contains(accessLevel)  {
            // TODO: reroute to a no permission for this resource page
            throw Abort (.unauthorized)
        }
        
        token.exp = (Date().addingTimeInterval(UserAndTokenController.tokenExpDuration))
        try saveSessionInfo(req: req, info: token, sessionKey: "token")
        
        let accessLog = AccessLog(personId: token.user.id, id: token.accessLogId, loginTime: token.loginTime)
        return accessLog.save(on: req).flatMap(to:Response.self) { _ in
            return try onSuccess(token.user)
        }
    }
    
    
    static func getSessionInfo<T: Codable>(req: Request, sessionKey: String) throws -> T?  {
        let session = try req.session()
        guard let stringifiedData = session[sessionKey] else {
            return nil
        }
        let decoder = JSONDecoder()
        guard let data: T = try? decoder.decode(T.self, from: stringifiedData) else {
            return nil
        }
        return data
    }
    
    static func saveSessionInfo<T: Codable>(req: Request, info: T, sessionKey: String) throws {
        let session = try req.session()
        let encoder = JSONEncoder()
        let data = try encoder.encode(info)
        session[sessionKey] = String(data: data, encoding: .utf8)
    }
}


