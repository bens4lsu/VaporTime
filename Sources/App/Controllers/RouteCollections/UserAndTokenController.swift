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
import MailCore

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

    init(_ cache: DataCache) {
        self.cache = cache
        UserAndTokenController.tokenExpDuration = self.cache.configKeys.tokenExpDuration
    }
    
    func boot(router: Router) throws {
        router.group("security") { group in
            group.get("login", use: renderLogin)
            //group.get("create", use: renderUserCreate)
            group.get("change-password", use: renderUserCreate)
            group.get("request-password-reset", use: renderPasswordResetForm)
            group.get("check-email", use: renderCheckEmail)
            group.get("password-reset-process", String.parameter, use: verifyPasswordResetRequest)
            
            group.post("login", use: login)
            group.post("create", use: createUser)
            //group.post("change-password", use: changePassword)
            group.post("request-password-reset", use: sendPWResetEmail)
        }
    }
    
    
    // MARK:  Methods connected to routes that return Views
    private func renderLogin(_ req: Request) throws -> Future<View> {
        return try req.view().render("users-login")
    }
    
    private func renderUserCreate(_ req: Request) throws -> Future<View> {
        return try req.view().render("users-create")
    }
    
    private func renderPasswordResetForm(_ req: Request) throws -> Future<View> {
        return try req.view().render("users-password-reset")
    }
    
    private func renderCheckEmail(_ req: Request) throws -> Future<View> {
        return try req.view().render("users-password-check-email")
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
            return accessLog.save(on: req).map(to: Response.self) { access in
                let userPersistInfo = user.persistInfo()!
                let ip = req.http.remotePeer.hostname
                if let accessId = access.id {
                    let token = Token(user: userPersistInfo,
                                      exp: Date().addingTimeInterval(self.cache.configKeys.tokenExpDuration),
                                      ip: ip,
                                      accessLogId: accessId,
                                      loginTime: access.accessTime)
                    try UserAndTokenController.saveSessionInfo(req: req, info: token, sessionKey: "token")
                }
                return req.redirect(to: "/")
            }
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
    
    
    // MARK:  Password reset methods
    private func sendPWResetEmail(_ req: Request) throws -> Future<Response> {
        let email = try req.content.syncGet(String.self, at: "emailAddress")
        
        guard email.count > 0 else {
            throw Abort(.badRequest, reason:  "No email address received for password reset.")
        }
        
        return User.query(on: req).filter(\User.emailAddress == email).all().flatMap(to: Response.self) { userMatches in
            guard userMatches.count < 2 else {
                throw Abort(.unauthorized, reason: "More than one user exists with that email address.")
            }
            
            guard userMatches.count == 1 else {
                throw Abort(.unauthorized, reason: "No user exists for that email address.")
            }
            
            let user = userMatches[0]
            let userId = user.id!
            
            let resetRequest = PasswordResetRequest(id: nil, exp: Date().addingTimeInterval(self.cache.configKeys.resetKeyExpDuration), person: userId)
            return resetRequest.save(on: req).flatMap(to: Response.self) { reset in
                
                let mailSender = self.cache.configKeys.smtp.username
                guard let resetKey = reset.id?.uuidString else {
                    throw Abort(.internalServerError, reason: "Error getting unique key for tracking password reset request.")
                }
                
                let (html, text) = self.getResetEmailBody(key: resetKey)
                
                print ("Sending email to \(user.emailAddress)")
                let mail = Mailer.Message(from: mailSender, to: user.emailAddress, subject: "Project/Time Reset request", text: text, html: html)
                
                return try req.mail.send(mail).map(to: Response.self) { mailResult in
                    
                    switch mailResult {
                    case .serviceNotConfigured:
                        throw Abort(.internalServerError, reason: "SMTP services not configured.")
                    case .success:
                        // redirect to page that tells them to check their email...
                        return req.redirect(to: "/security/check-email")
                    case .failure(let error):
                        throw Abort (.internalServerError, reason: "Mail error:  \(error)")
                    }
                }
            }
        }
    }
    
    private func verifyPasswordResetRequest(req: Request) throws -> Future<View> {
        let parameter = try req.parameters.next(String.self)
        guard let uuid = UUID(parameter) else {
            throw Abort(.badRequest, reason: "No reset token read in request for password reset.")
        }
        
        return PasswordResetRequest.query(on: req).filter(\.id == uuid).filter(\.exp >= Date()).first().flatMap(to: View.self) { resetRequestW in
            guard let _ = resetRequestW else {
                throw Abort(.badRequest, reason: "Reset link was invalid or expired.")
            }
            let context = ["resetKey" : parameter]
            return try req.view().render("users-password-change-form", context)
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


