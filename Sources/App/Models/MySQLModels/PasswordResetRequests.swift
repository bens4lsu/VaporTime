//
//  PasswordResetRequests.swift
//  App
//
//  Created by Ben Schultz on 3/12/20.
//

import Foundation
import Fluent
import Vapor

final class PasswordResetRequest: Content, Model, Codable {
    @ID(custom: "ResetRequestKey")
    var id: UUID?
    
    @Field(key: "Expiration")
    var exp: Date
    
    @Field(key: "PersonID")
    var person: Int

//    typealias Database = MySQLDatabase
//    typealias ID = UUID
//    static let idKey: IDKey = \.id
    static let schema = "fPasswordResetRequests"

    private enum CodingKeys: String, CodingKey {
        case id = "ResetRequestKey",
             exp = "Expiration",
             person = "PersonID"
    }
    
    required init() { }
    
    init (id: UUID?, exp: Date, person: Int) {
        self.id = id
        self.exp = exp
        self.person = person
    }
}
