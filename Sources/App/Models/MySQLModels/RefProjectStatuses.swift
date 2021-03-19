//
//  ProjectEvents.swift
//  App
//
//  Created by Ben Schultz on 3/3/20.
//

import Foundation
import Fluent
import Vapor

final class RefProjectStatuses: Content, Model, Codable, Comparable {
    
    @ID(custom: "StatusID")
    var id: Int?
    
    @Field(key: "StatusDescription")
    var description: String
    
    @Field(key: "DisplayOrder")
    var displayOrder: Int
    
    @Field(key: "CanCompleteProject")
    var canCompleteProject: Bool

//    typealias Database = MySQLDatabase
//    typealias ID = Int
//    static let idKey: IDKey = \.id
    static let schema = "RefProjectStatuses"

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
    
    required init() { }
}
