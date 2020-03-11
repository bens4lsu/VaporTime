//
//  AccessLog.swift
//  App
//
//  Created by Ben Schultz on 3/10/20.
//

import Foundation
import FluentMySQL
import Vapor

struct AccessLog: Content, MySQLModel, Codable {
    var personId: Int
    var id: Int?
    var loginTime: Date
    var accessTime: Date

    typealias Database = MySQLDatabase
    typealias ID = Int
    static let idKey: IDKey = \.id
    static let entity = "fAccessLog"

    private enum CodingKeys: String, CodingKey {
        case personId = "PersonID",
             id = "AccessID",
             loginTime = "LoginTime",
             accessTime = "LastAccessTime"
    }

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
    }
}
