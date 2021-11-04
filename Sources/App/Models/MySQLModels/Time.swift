//
//  Time.swift
//  App
//
//  Created by Ben Schultz on 2/5/20.
//

import Foundation
import Fluent
import Vapor

final class Time: Content, Model, Codable {
    
    @ID(custom: "TimeID")
    var id: Int?
    
    @Field(key: "PersonID")
    var personId: Int
    
    @Field(key: "ProjectID")
    var projectId: Int
    
    @Field(key: "WorkDate")
    var workDate: Date
    
    @Field(key: "Duration")
    var duration: Double
    
    @Field(key: "UseOTRate")
    var useOTRate: Bool
    
    @Field(key: "Notes")
    var notes: String
    
    @Field(key: "ExportStatus")
    var exportStatus: Int
    
    @Field(key: "PreDeliveryFlag")
    var preDeliveryFlag: Bool
    
    @Field(key: "DoNotBillFlag")
    var doNotBillFlag: Bool
    
    // MARK: Map to MySQL database and columns
    
//    typealias Database = MySQLDatabase
//    typealias ID = Int
//    static let idKey: IDKey = \.id
    static let schema = "fTime"
    
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
    
    required init() { }
    
    init(id: Int?, personId: Int, projectId: Int, workDate: Date, duration: Double, useOTRate: Bool, notes: String, exportStatus: Int, preDeliveryFlag: Bool, doNotBillFlag: Bool) {
        self.id = id
        self.personId = personId
        self.projectId = projectId
        self.workDate = workDate
        self.duration = duration
        self.useOTRate = useOTRate
        self.notes = notes
        self.exportStatus = exportStatus
        self.preDeliveryFlag = preDeliveryFlag
        self.doNotBillFlag = doNotBillFlag
    }
}
