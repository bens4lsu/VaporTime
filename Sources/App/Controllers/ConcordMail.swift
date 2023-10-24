//
//  Mailer.swift
//  App
//
//  Created by Ben Schultz on 4/22/20.
//

import Foundation
import Vapor
import SMTPKitten

class ConcordMail {
    
    struct InternalMail {
        
        struct User {
            var name: String?
            var email: String
            
            var smtpKittenUser: SMTPKitten.MailUser {
                SMTPKitten.MailUser(name: self.name, email: self.email)
            }
        }
        
        enum ContentType {
            case plain
            case html
            
            var smtpKittenContentType: (String) -> SMTPKitten.Mail.Content {
                switch self {
                case .plain:
                    return Mail.Content.plain
                case .html:
                    return Mail.Content.html
                }
            }
        }
        
        var from: InternalMail.User
        var to: InternalMail.User
        var subject: String
        var contentType: InternalMail.ContentType
        var text: String
        
        var smtpKittenMail: SMTPKitten.Mail {
            SMTPKitten.Mail(from: from.smtpKittenUser,
                            to: [to.smtpKittenUser],
                            cc: Set<SMTPKitten.MailUser>(),
                            subject: subject,
                            content: contentType.smtpKittenContentType(text)
            )
        }
    }
    
    var smtp: ConfigKeys.Smtp
    
    init(configKeys: ConfigKeys) {
        self.smtp = configKeys.smtp
    }
    
    public enum Result {
        case success
        case failure(error: Error)
    }
    
    func send(mail: InternalMail) async throws -> ConcordMail.Result  {
        let client = try await SMTPClient.connect(hostname: smtp.hostname, ssl: .startTLS(configuration: .default))
        try await client.login(user: smtp.username,password: smtp.password)
        try await client.sendMail(mail.smtpKittenMail)
        return .success
    }
    
    #if DEBUG
    func testMail() async throws -> ConcordMail.Result {
        let name = smtp.friendlyName ?? smtp.username
        let email = smtp.fromEmail ?? smtp.username
        let mail = InternalMail(
            from: InternalMail.User(name: name, email: email),
            to: InternalMail.User(name: "ben schultz", email: "bens4lsu@gmail.com"),
            subject: "Welcome to our app!",
            contentType: .plain,
            text: "Welcome to our app, you're all set up & stuff."
        )
        return try await send(mail: mail)
        
    }
    #endif
}
