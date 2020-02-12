//
//  User.swift
//  App
//
//  Created by Ben Schultz on 1/30/20.
//

import Foundation
import FluentMySQL
import Vapor

struct User: Content, MySQLModel, Migration, Codable {
    var id: Int?
    var name: String
    var emailAddress: String
    var isActive: Bool
    var isTimeBiller: Bool
    var isAdmin: Bool
    var isReportViewer: Bool
    var isCRMUser: Bool
    var isDocUser: Bool
    var workPhone: String?
    var mobilePhone: String?
    var personalNote: String?
    var passwordHash: String
    
    
    // MARK: Map to MySQL database and columns
    
    typealias Database = MySQLDatabase
    typealias ID = Int
    static let idKey: IDKey = \.id
    static let entity = "LuPeople"
    
    private enum CodingKeys: String, CodingKey {
        case id = "PersonID",
             name = "Name",
             emailAddress = "Email",
             isActive = "ActiveUser",
             isTimeBiller = "BillsTime",
             isAdmin = "SysAdmin",
             isReportViewer = "ReportViewer",
             isCRMUser = "CRMUser",
             isDocUser = "DocUser",
             workPhone = "WorkPhone",
             mobilePhone = "MobilePhone",
             personalNote = "PersonalNote",
             passwordHash = "PasswordHash"
    }
    
    
    // MARK: Public methods
    
    
    init(id: Int?, name: String, emailAddress: String, passwordHash: String) {
        self.id = id
        self.name = name
        self.emailAddress = emailAddress
        self.isActive = true
        self.isTimeBiller = true
        self.isAdmin = false
        self.isReportViewer = false
        self.isCRMUser = false
        self.isDocUser = false
        self.workPhone = ""
        self.mobilePhone = ""
        self.personalNote = ""
        self.passwordHash = passwordHash
    }
    
    
    func persistInfo() -> UserPersistInfo? {
        guard let id = self.id else { return nil }
        var access = Set<UserAccessLevel>()
        access.insert(.activeOnly)
        if self.isAdmin { access.insert(.admin) }
        if self.isTimeBiller { access.insert(.timeBilling) }
        if self.isReportViewer { access.insert(.report) }
        if self.isCRMUser { access.insert(.crm) }
        if self.isDocUser { access.insert(.doc) }
        return UserPersistInfo (id: id, name: self.name, emailAddress: self.emailAddress, access: access)
    }
        
    static func prepare(on: MySQLConnection) {
        
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
    var access: Set<UserAccessLevel>
    
    func accessDictionary() -> [String: Bool] {
        var dict = [String: Bool]()
        dict["timeBilling"] = access.contains(.timeBilling)
        dict["admin"] = access.contains(.admin)
        dict["report"] = access.contains(.report)
        dict["doc"] = access.contains(.doc)
        dict["crm"] = access.contains(.crm)
        return dict
    }
}
