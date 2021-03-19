//
//  UserAndTokenController.swift
//  App
//
//  Created by Ben Schultz on 1/30/20.
//

import Foundation
import Vapor
import Fluent
import SwiftSMTP

enum UserAccessLevel: String, Codable {
    case timeBilling = "T"
    case admin = "A"
    case report = "R"
    case doc = "D"
    case crm = "C"
    case activeOnly = "X"
}

class UserAndTokenController: RouteCollection {
    
    static var tokenExpDuration: Double = 3600
    
    var cache: DataCache
    
    let db = MySQLDirect()
    let concordMail: ConcordMail
    
    init(_ cache: DataCache) {
        self.cache = cache
        UserAndTokenController.tokenExpDuration = self.cache.configKeys.tokenExpDuration
        
        concordMail = ConcordMail(configKeys: cache.configKeys)
    }
    
    
    func boot(routes: RoutesBuilder) throws {
        let security = routes.grouped("security")
        

        security.get("login", use: renderLogin)
        //group.get("create", use: renderUserCreate)
        security.get("change-password", use: renderUserCreate)
        security.get("request-password-reset", use: renderPasswordResetForm)
        security.get("check-email", use: renderCheckEmail)
        security.get("password-reset-process", ":parameter", use: verifyPasswordResetRequest)
            
        security.post("login", use: login)
        security.post("create", use: createUser)
        //security.post("change-password", use: changePassword)
        security.post("request-password-reset", use: sendPWResetEmail)
        security.post("password-reset-process", use: verifyAndChangePassword)
    }
    
    
    // MARK:  Methods connected to routes that return Views
    private func renderLogin(_ req: Request) throws -> EventLoopFuture<View> {
        return req.view.render("users-login")
    }
    
    private func renderUserCreate(_ req: Request) throws -> EventLoopFuture<View> {
        return req.view.render("users-create")
    }
    
    private func renderCheckEmail(_ req: Request) throws -> EventLoopFuture<View> {
        return req.view.render("users-password-check-email")
    }
    
    
    // MARK:  Methods connected to routes that return data
    
    private func login(_ req: Request) throws -> EventLoopFuture<Response> {
        struct PostVars: Content {
            var email: String
            var passowrd: String
        }
        let postVars = try req.content.decode(PostVars.self)
        let email = postVars.email
        let password = postVars.passowrd
        guard email.count > 0, password.count > 0 else {
            throw Abort(.badRequest)
        }
        
        return User.query(on: req.db).filter(\.$emailAddress == email).all().flatMap { userMatches in
            
            do {
                let user: User =  try {
                    guard userMatches.count < 2 else {
                        throw Abort(.unauthorized, reason: "More than one user exists with that email address.")
                    }
                    
                    guard userMatches.count == 1 else {
                        throw Abort(.unauthorized, reason: "No user exists for that email address.")
                    }
                    
                    let user = userMatches[0]
                    // verify that password submitted matches
                    guard try Bcrypt.verify(password, created: user.passwordHash) else {
                        throw Abort(.unauthorized, reason: "Could not verify password.")
                    }
                    
                    // login success
                    guard user.isActive else {
                        throw Abort(.unauthorized, reason: "User's system access has been revoked.")
                    }
                    
                    return user
                }()
                
                // create access log entry
                let accessLog = AccessLog(personId: user.id!)
                
                return accessLog.save(on: req.db).flatMapThrowing {
                    let userPersistInfo = user.persistInfo()!
                    let ip = req.remoteAddress?.ipAddress
                    if let accessId = accessLog.id {
                        let token = Token(user: userPersistInfo,
                                          exp: Date().addingTimeInterval(self.cache.configKeys.tokenExpDuration),
                                          ip: ip,
                                          accessLogId: accessId,
                                          loginTime: accessLog.accessTime)
                        try UserAndTokenController.saveSessionInfo(req: req, info: token, sessionKey: "token")
                    }
                    return req.redirect(to: "/")
                }
            }
            catch {
                return req.eventLoop.makeFailedFuture(error)
            }
        }
    }

    
    private func createUser(_ req: Request) throws -> EventLoopFuture<HTTPResponseStatus> {
        struct FormData: Decodable {
            var emailAddress: String?
            var password: String?
            var name: String?
        }
        let form = try req.query.decode(FormData.self)
        guard let emailAddress = form.emailAddress,
            let password = form.password,
            let name = form.name,
            let passwordHash = try? Bcrypt.hash(password)
            else {
                throw Abort(.partialContent, reason: "All fields on create user form are requird")
        }
        let newUser = User(id: nil, name: name, emailAddress: emailAddress, passwordHash: passwordHash)
        return newUser.create(on: req.db).transform(to: HTTPStatus.ok)
    }
    
    
    
    // MARK: Static methods - used for verification in other controllers
    
    static func redirectToLogin(_ req: Request) -> EventLoopFuture<Response> {
        var session = req.session.data
        session["token"] = nil
        session["filter"] = nil
        return req.eventLoop.makeSucceededFuture(req.redirect(to: "./security/login"))
    }
    
    
    static func verifyAccess(_ req: Request, accessLevel: UserAccessLevel, onSuccess: @escaping (_: UserPersistInfo) throws -> EventLoopFuture<Response>) throws -> EventLoopFuture<Response> {
        guard let temp: Token? =  try? getSessionInfo(req: req, sessionKey: "token"),
            var token = temp else {
                return UserAndTokenController.redirectToLogin(req)
        }
        
        guard token.exp >= Date() || token.ip == req.remoteAddress?.ipAddress else {
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
        return accessLog.save(on: req.db).flatMap {
            do {
                return try onSuccess(token.user)
            }
            catch {
                return req.eventLoop.makeFailedFuture(error)
            }
        }
    }
    
    
    static func getSessionInfo<T: Decodable>(req: Request, sessionKey: String) throws -> T?  {
        let session = req.session.data
        guard let stringifiedData = session[sessionKey],
              let datafiedString = stringifiedData.data(using: .utf8) else {
            return nil
        }
        let decoder = JSONDecoder()
        guard let data: T = try? decoder.decode(T.self, from: datafiedString) else {
            return nil
        }
        return data
    }
    
    static func saveSessionInfo<T: Codable>(req: Request, info: T, sessionKey: String) throws {
        var session = req.session.data
        let encoder = JSONEncoder()
        let data = try encoder.encode(info)
        session[sessionKey] = String(data: data, encoding: .utf8)
    }
}


// MARK:  Password reset methods

extension UserAndTokenController {
    
    private func renderPasswordResetForm(_ req: Request) throws -> EventLoopFuture<View> {
        return req.view.render("users-password-reset")
    }
    
    
    private func sendPWResetEmail(_ req: Request) throws -> EventLoopFuture<Response> {
        struct PostVar: Content {
            var emailAddress: String
        }
        let email = try req.query.decode(PostVar.self).emailAddress
        
        guard email.count > 0 else {
            throw Abort(.badRequest, reason:  "No email address received for password reset.")
        }
        
        return User.query(on: req.db).filter(\.$emailAddress == email).all().flatMap { userMatches in
            
            do {
                let user: User = try {
                    guard userMatches.count < 2 else {
                        throw Abort(.unauthorized, reason: "More than one user exists with that email address.")
                    }
                    
                    guard userMatches.count == 1 else {
                        throw Abort(.unauthorized, reason: "No user exists for that email address.")
                    }
                    
                    let user = userMatches[0]
                    return user
                }()
                
                let userId = user.id!
                
                let resetRequest = PasswordResetRequest(id: nil, exp: Date().addingTimeInterval(self.cache.configKeys.resetKeyExpDuration), person: userId)
                return resetRequest.save(on: req.db).flatMap {
                    do {
                        let mailSender = self.cache.configKeys.smtp.username
                        
                        let resetKey: String = try {
                            guard let resetKey = resetRequest.id?.uuidString else {
                                throw Abort(.internalServerError, reason: "Error getting unique key for tracking password reset request.")
                            }
                            return resetKey
                        }()
                        
                        // TODO:  Delete expired keys
                        // TODO:  Delete any older (even unexpired) keys for this user.
                        
                        let (_, text) = self.getResetEmailBody(key: resetKey)
                        
                        //print ("Sending email to \(user.emailAddress)")
                        //let mail = Mailer.Message(from: mailSender, to: user.emailAddress, subject: "Project/Time Reset request", text: text, html: html)
                        
                        let mailFrom = Mail.User(name: nil, email: mailSender)
                        let mailTo = Mail.User(name: nil, email: user.emailAddress)

                        let mail = Mail(
                            from: mailFrom,
                            to: [mailTo],
                            subject: "Project/Time Reset request",
                            text: text
                        )
                        
                        return self.concordMail.send(req, mail).flatMapThrowing { mailResult in
                            
                            switch mailResult {
                            case .success:
                                // redirect to page that tells them to check their email...
                                return req.redirect(to: "/security/check-email")
                            case .failure(let error):
                                throw Abort (.internalServerError, reason: "Mail error:  \(error)")
                            }
                        }
                    }
                    catch {
                        return req.eventLoop.makeFailedFuture(error)
                    }
                }
            }
            catch {
                return req.eventLoop.makeFailedFuture(error)
            }
        }
    }
    
    private func verifyKey(_ req: Request, resetKey: String) throws -> EventLoopFuture<PasswordResetRequest> {
        
        guard let uuid = UUID(resetKey) else {
            throw Abort(.badRequest, reason: "No reset token read in request for password reset.")
        }
        
        return PasswordResetRequest.query(on: req.db).filter(\.$id == uuid).filter(\.$exp >= Date()).first().flatMapThrowing { resetRequestW in
            guard let resetRequest = resetRequestW else {
                throw Abort(.badRequest, reason: "Reset link was invalid or expired.")
            }
            return resetRequest
        }
    }
    
    private func verifyPasswordResetRequest(req: Request) throws -> EventLoopFuture<View> {
        guard let parameter = req.parameters.get("parameter") else {
            throw Abort(.badRequest, reason: "Invalid password reset parameter received.")
        }
        
        return try verifyKey(req, resetKey: parameter).flatMap { _ in
            let context = ["resetKey" : parameter]
            return req.view.render("users-password-change-form", context)
        }
    }
    
    private func verifyAndChangePassword(req: Request) throws -> EventLoopFuture<View> {
        struct PostVars: Content {
            let pw1: String
            let pw2: String
            let resetKey: String
        }
        
        let vars = try req.content.decode(PostVars.self)
        let pw1 = vars.pw1
        let pw2 = vars.pw2
        let resetKey = vars.resetKey
        
        return try verifyKey(req, resetKey: resetKey).flatMap { resetRequest in
            
            do {
                let _ = try {
                    guard pw1 == pw2 else {
                        throw Abort(.badRequest, reason: "Form submitted two passwords that don't match.")
                    }
                }()
            
                // TODO:  enforce minimum password requirement (configuration?)
                // TODO:  verify no white space.  any other invalid characrters?
                
                return try self.changePassword(req, userId: resetRequest.person, newPassword: pw1).flatMap {_ in
                    do {
                        return try self.db.deleteExpiredAndCompleted(req, resetKey: resetKey).flatMap { _ in
                            return req.view.render("users-password-change-success")
                        }
                    }
                    catch {
                        return req.eventLoop.makeFailedFuture(error)
                    }
                }
            }
            catch {
                return req.eventLoop.makeFailedFuture(error)
            }
        }
    }
    
    private func changePassword(_ req: Request, userId: Int, newPassword: String) throws -> EventLoopFuture<HTTPResponseStatus> {
        return User.query(on:req.db).filter(\.$id == userId).all().flatMap { userMatch in
            do {
                let user = userMatch[0]
                let passwordHash = try Bcrypt.hash(newPassword)
                user.passwordHash = passwordHash
                return user.save(on: req.db).transform(to: HTTPResponseStatus.ok)
            }
            catch {
                return req.eventLoop.makeFailedFuture(error)
            }
        }
    }
    
    
    private func changePassword(_ req: Request) throws -> EventLoopFuture<HTTPResponseStatus> {
        struct PostVars: Content {
            var emailAddress: String
            var password: String
        }
        let vars = try req.query.decode(PostVars.self)
        let email = vars.emailAddress
        let password = vars.password
        
        guard email.count > 0, password.count > 0 else {
            throw Abort(.badRequest)
        }
        
        return User.query(on: req.db).filter(\User.$emailAddress == email).all().flatMap { userMatches in
            
            do {
                let user: User = try {
                    guard userMatches.count < 2 else {
                        throw Abort(.unauthorized, reason: "More than one user exists with that email address.")
                    }
                    
                    guard userMatches.count == 1 else {
                        throw Abort(.unauthorized, reason: "No user exists for that email address.")
                    }
                    
                    return userMatches[0]
                }()
                
                let passwordHash = (try? Bcrypt.hash(password)) ?? ""
                user.passwordHash = passwordHash
                return user.save(on: req.db).transform(to: HTTPResponseStatus.ok)
            }
            catch {
                return req.eventLoop.makeFailedFuture(error)
            }
        }
    }
    
    
    
    // MARK: Private helper methods
    
    private func getResetEmailBody(key: String) -> (String, String) {
        let resetLink = "\(self.cache.configKeys.systemRootPublicURL)/security/password-reset-process/\(key)"
        
        let html = """
        <p>We have received a password reset request for your account.  If you did not make this request, you can delete this email, and your password will remain unchanged.</p>
        <p>If you do want to change your password, follow <a href="\(resetLink)">this link</a>.</p>
        """
        
        let txt = "We have received a password reset request for your account.  If you did not make this request, you can delete this email, and your password will remain unchanged.\n\nIf you do want to change your password, visit \(resetLink) in your browser."
        
        return (html, txt)
    }
    
}


