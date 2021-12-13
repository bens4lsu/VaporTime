//
//  ProjectEvents.swift
//  App
//
//  Created by Ben Schultz on 3/3/20.
//

import Foundation
import Fluent
import Vapor

final class RefProjectStatuses: Model, Codable {
    
    @ID(custom: "StatusID")
    var id: Int?
    
    @Field(key: "StatusDescription")
    var statusDescription: String
    
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
        statusDescription = "StatusDescription",
        displayOrder = "DisplayOrder",
        canCompleteProject = "CanCompleteProject"
    }
    
    required init() { }
    
    var dto: RefProjectStatusesDTO? {
        guard let id = self.id else {
            return nil
        }
        return RefProjectStatusesDTO(id: id, statusDescription: self.statusDescription, displayOrder: self.displayOrder, canCompleteProject: self.canCompleteProject)
    }
}

struct RefProjectStatusesDTO: Codable, Content, Comparable {
    var id: Int
    var statusDescription: String
    var displayOrder: Int
    var canCompleteProject: Bool
    
    static func < (lhs: RefProjectStatusesDTO, rhs: RefProjectStatusesDTO) -> Bool{
        return lhs.displayOrder < rhs.displayOrder
    }
    
    static func == (lhs: RefProjectStatusesDTO, rhs: RefProjectStatusesDTO) -> Bool {
        return lhs.displayOrder == rhs.displayOrder
    }
}

extension Array where Element == RefProjectStatuses {
    var dto: [RefProjectStatusesDTO] {
        self.map { $0.dto }.compactMap{ $0 }.sorted()
    }
}
