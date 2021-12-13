//
//  User.swift
//  App
//
//  Created by Ben Schultz on 1/30/20.
//

import Foundation
import Fluent
import Vapor

final class User: Content, Model, Codable {
    @ID(custom: "PersonID")
    var id: Int?
    
    @Field(key: "Name")
    var name: String
    
    @Field(key: "Email")
    var emailAddress: String
    
    @Field(key: "ActiveUser")
    var isActive: Bool
    
    @Field(key: "BillsTime")
    var isTimeBiller: Bool
    
    @Field(key: "SysAdmin")
    var isAdmin: Bool
    
    @Field(key: "ReportViewer")
    var isReportViewer: Bool
    
    @Field(key: "CRMUser")
    var isCRMUser: Bool
    
    @Field(key: "DocUser")
    var isDocUser: Bool
    
    @OptionalField(key: "WorkPhone")
    var workPhone: String?
    
    @OptionalField(key: "MobilePhone")
    var mobilePhone: String?
    
    @OptionalField(key: "PersonalNote")
    var personalNote: String?
    
    @Field(key: "PasswordHash")
    var passwordHash: String
    
    
    // MARK: Map to MySQL database and columns
    
//    typealias Database = MySQLDatabase
//    typealias ID = Int
//    static let idKey: IDKey = \.id
    static let schema = "LuPeople"
    
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
        
        if id != nil {
            self.$id.exists = true  // 2021.11.19 - need this to fool Fluent into understanding
                                    //              that the id property is set.  It was trying
                                    //              to insert where I needed an update.
        }
    }
    
    func persistInfo() -> UserPersistInfo? {
        guard let id = self.id else { return nil }
        var access = Set<UserAccessLevel>()
        access.insert(.activeOnly)
        if self.isAdmin { access.insert(.admin) }
        if self.isTimeBiller { access.insert(.timeBilling) }
        if self.isReportViewer { access.insert(.report) }
        return UserPersistInfo (id: id, name: self.name, emailAddress: self.emailAddress, access: access)
    }
        
    //static func prepare(on: MySQLConnection) {  }
    
    required init() { }
}

// MARK: Validatable Protocol Conformation
extension User: Validatable {
    static func validations(_ validations: inout Validations) {
        var validations = Validations()
        validations.add("emailAddress", as: String.self, is: .email)
    }
}

#warning ("make new permission levels for read project page and add/edit project page")
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
        return dict
    }
}
