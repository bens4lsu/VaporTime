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

enum VerifyAccessResponse {
    case success(UserPersistInfo)
    case failure(Response)
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
    private func renderLogin(_ req: Request) async throws -> View {
        return try await req.view.render("users-login")
    }
    
    private func renderUserCreate(_ req: Request) async throws -> View {
        return try await req.view.render("users-create")
    }
    
    private func renderCheckEmail(_ req: Request) async throws -> View {
        return try await req.view.render("users-password-check-email")
    }
    
    
    // MARK:  Methods connected to routes that return data
    
    private func login(_ req: Request) async throws -> Response {
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
        
        let userMatches = try await User.query(on: req.db).filter(\.$emailAddress == email).all()
        
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
            
            //login sucess
            return user
        }()
                
        // create access log entry
        let accessLog = AccessLog(personId: user.id!)
        async let logTask = accessLog.saveAndReturn(on: req.db)     // saveAndReturn() from Extionsions -> Model
                
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
        let _ = try await logTask
        return req.redirect(to: "/")
    }

    
    private func createUser(_ req: Request) async throws -> HTTPResponseStatus {
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
        try await newUser.create(on: req.db)
        return HTTPStatus.ok
    }
    
    
    
    // MARK: Static methods - used for verification in other controllers
    
    static func redirectToLogin(_ req: Request) -> Response {
        var session = req.session.data
        session["token"] = nil
        session["filter"] = nil
        return req.redirect(to: "./security/login")
    }
    
    
    private static func verifyAccess(_ req: Request, accessLevel: UserAccessLevel) async throws -> VerifyAccessResponse {
        guard let temp: Token? =  try? getSessionInfo(req: req, sessionKey: "token"),
            var token = temp else {
                return .failure(UserAndTokenController.redirectToLogin(req))
        }
        
        guard token.exp >= Date() || token.ip == req.remoteAddress?.ipAddress else {
            // token is expired, or ip address has changed
            return .failure(UserAndTokenController.redirectToLogin(req))
        }
        
        if !token.user.access.contains(accessLevel)  {
            // TODO: reroute to a no permission for this resource page
            throw Abort (.unauthorized)
        }
        
        token.exp = (Date().addingTimeInterval(UserAndTokenController.tokenExpDuration))
        try saveSessionInfo(req: req, info: token, sessionKey: "token")
        
        let accessLog = AccessLog(personId: token.user.id, id: token.accessLogId, loginTime: token.loginTime)
        try await accessLog.save(on: req.db)
        return .success(token.user)
    }
    
    static func ifVerifiedDo(_ req: Request, accessLevel: UserAccessLevel, onSuccess: (_ user: UserPersistInfo) async throws -> Response) async throws -> Response {
        let accessResponse = try await Self.verifyAccess(req, accessLevel: accessLevel)
        switch accessResponse {
        case .success(let userPersistInfo):
            return try await onSuccess(userPersistInfo)
        case .failure(let response):
            return response
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
    
    private func renderPasswordResetForm(_ req: Request) async throws -> View {
        return try await req.view.render("users-password-reset")
    }
    
    
    private func sendPWResetEmail(_ req: Request) async throws -> Response {
        struct PostVar: Content {
            var emailAddress: String
        }
        let email = try req.query.decode(PostVar.self).emailAddress
        
        guard email.count > 0 else {
            throw Abort(.badRequest, reason:  "No email address received for password reset.")
        }
        
        let userMatches = try await User.query(on: req.db).filter(\.$emailAddress == email).all()
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
        try await resetRequest.save(on: req.db)  // sets resetRequest.id
        
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
                        
        let mailResult = try await self.concordMail.send(req, mail)
        switch mailResult {
        case .success:
            // redirect to page that tells them to check their email...
            return req.redirect(to: "/security/check-email")
        case .failure(let error):
            throw Abort (.internalServerError, reason: "Mail error:  \(error)")
        }
    }
    
    private func verifyKey(_ req: Request, resetKey: String) async throws -> PasswordResetRequest {
        
        guard let uuid = UUID(resetKey) else {
            throw Abort(.badRequest, reason: "No reset token read in request for password reset.")
        }
        
        let resetRequestW = try await PasswordResetRequest.query(on: req.db).filter(\.$id == uuid).filter(\.$exp >= Date()).first()
        guard let resetRequest = resetRequestW else {
            throw Abort(.badRequest, reason: "Reset link was invalid or expired.")
        }
        return resetRequest
    }
    
    private func verifyPasswordResetRequest(req: Request) async throws -> View {
        guard let parameter = req.parameters.get("parameter") else {
            throw Abort(.badRequest, reason: "Invalid password reset parameter received.")
        }
        
        let _ = try await verifyKey(req, resetKey: parameter)
        let context = ["resetKey" : parameter]
        return try await req.view.render("users-password-change-form", context)
    }
    
    private func verifyAndChangePassword(req: Request) async throws -> View {
        struct PostVars: Content {
            let pw1: String
            let pw2: String
            let resetKey: String
        }
        
        let vars = try req.content.decode(PostVars.self)
        let pw1 = vars.pw1
        let pw2 = vars.pw2
        let resetKey = vars.resetKey
        
        guard pw1 == pw2 else {
            throw Abort(.badRequest, reason: "Form submitted two passwords that don't match.")
        }
        
        let resetRequest: PasswordResetRequest = try await verifyKey(req, resetKey: resetKey)
  
        // TODO:  enforce minimum password requirement (configuration?)
        // TODO:  verify no white space.  any other invalid characrters?
                
        async let changeTask = changePassword(req, userId: resetRequest.person, newPassword: pw1)
        async let deleteTask = self.db.deleteExpiredAndCompleted(req, resetKey: resetKey)
        let (_, _) = (try await changeTask, try await deleteTask)
        return try await req.view.render("users-password-change-success")
    }
    
    private func changePassword(_ req: Request, userId: Int, newPassword: String) async throws -> HTTPResponseStatus {
        let userMatch = try await User.query(on:req.db).filter(\.$id == userId).all()
        let user = userMatch[0]
        let passwordHash = try Bcrypt.hash(newPassword)
        user.passwordHash = passwordHash
        try await user.save(on: req.db)
        return HTTPResponseStatus.ok
    }
    
    
    private func changePassword(_ req: Request) async throws -> HTTPResponseStatus {
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
        
        let userMatches = try await User.query(on: req.db).filter(\User.$emailAddress == email).all()
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
        try await user.save(on: req.db)
        return HTTPResponseStatus.ok
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


