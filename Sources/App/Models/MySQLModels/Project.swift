//
//  Project.swift
//  App
//
//  Created by Ben Schultz on 2/14/20.
//

import Foundation
import Fluent
import Vapor

final class Project: Content, Model, Codable {
    
    @ID(custom: "ProjectID")
    var id: Int?
    
    @Field(key: "ContractID")
    var contractId: Int
    
    @Field(key: "ServicesForCompany")
    var companyId: Int
    
    @Field(key: "ProjectDescription")
    var description: String
    
    @OptionalField(key: "StatusID")
    var statusId: Int?
    
    @OptionalField(key: "ProjectNumber")
    var projectNumber: String?
    
    @OptionalField(key: "StatusNotes")
    var statusNotes: String?
    
    @OptionalField(key: "MantisProjectID")
    var mantisProjectId: Int?
    
    @Field(key: "IsActive")
    var isActive: Bool
    
    @OptionalField(key: "ProjectedTime")
    var projectedTime: Double?
    
    @OptionalField(key: "ProjectedDateComplete")
    var projectedDateComplete: Date?
    
    @OptionalField(key: "PMProjectID")
    var pmProjectId: Int?
    
    @OptionalField(key: "HideTimeReporting")
    var hideTimeReporting: Bool?
    
    @OptionalField(key: "StartDate")
    var startDate: Date?


//    typealias Database = MySQLDatabase
//    typealias ID = Int
//    static let idKey: IDKey = \.id
    static let schema = "fProjects"

    private enum CodingKeys: String, CodingKey {
        case id = "ProjectID",
        contractId = "ContractID",
        companyId = "ServicesForCompany",
        description = "ProjectDescription",
        statusId = "StatusID",
        projectNumber = "ProjectNumber",
        statusNotes = "StatusNotes",
        mantisProjectId = "MantisProjectID",
        isActive = "IsActive",
        projectedTime = "ProjectedTime",
        projectedDateComplete = "ProjectedDateComplete",
        pmProjectId = "PMProjectID",
        hideTimeReporting = "HideTimeReporting",
        startDate = "StartDate"
    }
    
    required init() { }
    
    init(id: Int?, contractId: Int, companyId: Int, description: String, statusId: Int?, projectNumber: String?, statusNotes: String?, mantisProjectId: Int?, isActive: Bool, projectedTime: Double?, projectedDateComplete: Date?, pmProjectId: Int?, hideTimeReporting: Bool?, startDate: Date?) {
        self.id = id
        self.contractId = contractId
        self.companyId = companyId
        self.description = description
        self.statusId = statusId
        self.projectNumber = projectNumber
        self.statusNotes = statusNotes
        self.mantisProjectId = mantisProjectId
        self.isActive = isActive
        self.projectedTime = projectedTime
        self.projectedDateComplete = projectedDateComplete
        self.pmProjectId = pmProjectId
        self.hideTimeReporting = hideTimeReporting
        self.startDate = startDate
    }
}
