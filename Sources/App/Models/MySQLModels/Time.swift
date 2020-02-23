//
//  Time.swift
//  App
//
//  Created by Ben Schultz on 2/5/20.
//

import Foundation
import FluentMySQL
import Vapor

struct Time: Content, MySQLModel, Codable {
    
    var id: Int?
    var personId: Int
    var projectId: Int
    var workDate: Date
    var duration: Double
    var useOTRate: Bool
    var notes: String
    var exportStatus: Int
    var preDeliveryFlag: Bool
    var doNotBillFlag: Bool
    
    // MARK: Map to MySQL database and columns
    
    typealias Database = MySQLDatabase
    typealias ID = Int
    static let idKey: IDKey = \.id
    static let entity = "fTime"
    
    private enum CodingKeys: String, CodingKey {
        case id = "TimeID",
             personId = "PersonID",
             projectId = "ProjectID",
             workDate = "WorkDate",
             duration = "Duration",
             useOTRate = "UseOTRate",
             notes = "Notes",
             exportStatus = "ExportStatus",
             preDeliveryFlag = "PreDeliveryFlag",
             doNotBillFlag = "DoNotBillFlag"
    }
}
