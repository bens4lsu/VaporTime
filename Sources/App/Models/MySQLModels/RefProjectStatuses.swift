//
//  ProjectEvents.swift
//  App
//
//  Created by Ben Schultz on 3/3/20.
//

import Foundation
import FluentMySQL
import Vapor

struct RefProjectStatuses: Content, MySQLModel, Codable, Comparable {
    var id: Int?
    var description: String
    var displayOrder: Int
    var canCompleteProject: Bool

    typealias Database = MySQLDatabase
    typealias ID = Int
    static let idKey: IDKey = \.id
    static let entity = "RefProjectStatuses"

    private enum CodingKeys: String, CodingKey {
        case id = "StatusID",
        description = "StatusDescription",
        displayOrder = "DisplayOrder",
        canCompleteProject = "CanCompleteProject"
    }
    
    static func < (lhs: RefProjectStatuses, rhs: RefProjectStatuses) -> Bool{
        return lhs.displayOrder < rhs.displayOrder
    }
    
    static func == (lhs: RefProjectStatuses, rhs: RefProjectStatuses) -> Bool {
        return lhs.displayOrder == rhs.displayOrder
    }
}
