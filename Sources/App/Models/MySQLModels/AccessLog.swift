//
//  AccessLog.swift
//  App
//
//  Created by Ben Schultz on 3/10/20.
//

import Foundation
import Fluent
import FluentMySQLDriver
import Vapor

final class AccessLog: Content, Model, Codable {

    @Field(key: "PersonID")
    var personId: Int
    
    @ID(custom: "AccessID")
    var id: Int?
    
    @Field(key: "LoginTime")
    var loginTime: Date
    
    @Field(key: "LastAccessTime")
    var accessTime: Date

//    typealias Database = MySQLDatabase
//    typealias ID = Int
//    static let idKey: IDKey = \.id
    static let schema = "fAccessLog"

//    private enum CodingKeys: String, CodingKey {
//        case personId = "PersonID",
//             id = "AccessID",
//             loginTime = "LoginTime",
//             accessTime = "LastAccessTime"
//    }

    init(personId: Int) {
        // used to create a new row in the access log (login)
        self.personId = personId
        self.id = nil
        self.loginTime = Date()
        self.accessTime = Date()
    }
    
    init(personId: Int, id: Int, loginTime: Date) {
        // used to update the accessTime in an existing row
        self.personId = personId
        self.id = id
        self.loginTime = loginTime
        self.accessTime = Date()
        self.$id.exists = true  // 2021.11.19 - need this to fool Fluent into understanding
                                //              that the id property is set.  It was trying
                                //              to insert where I needed an update.
    }
    
    required init() {
        
    }
    
}
