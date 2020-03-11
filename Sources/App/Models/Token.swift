//
//  Toke n.swift
//  App
//
//  Created by Ben Schultz on 1/30/20.
//

import Foundation
import FluentMySQL
import Vapor

struct Token: Codable {
    var user: UserPersistInfo
    var exp: Date
    var ip: String?
    var accessLogId: Int
    var loginTime: Date
    
    func encode() throws -> String {
        let jsonData = try JSONEncoder().encode(self)
        return String(data: jsonData, encoding: .utf8)!
    }
}
