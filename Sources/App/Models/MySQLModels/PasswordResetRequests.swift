//
//  PasswordResetRequests.swift
//  App
//
//  Created by Ben Schultz on 3/12/20.
//

import Foundation
import FluentMySQL
import Vapor

struct PasswordResetRequest: Content, MySQLUUIDModel, Codable {
    var id: UUID?
    var exp: Date
    var person: Int

    typealias Database = MySQLDatabase
    typealias ID = UUID
    static let idKey: IDKey = \.id
    static let entity = "fPasswordResetRequests"

    private enum CodingKeys: String, CodingKey {
        case id = "ResetRequestKey",
             exp = "Expiration",
             person = "PersonID"
    }
}
