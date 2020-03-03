//
//  Project.swift
//  App
//
//  Created by Ben Schultz on 2/14/20.
//

import Foundation
import FluentMySQL
import Vapor

struct Project: Content, MySQLModel, Codable {
    var id: Int?
    var contractId: Int
    var companyId: Int
    var description: String
    var statusId: Int?
    var projectNumber: String?
    var statusNotes: String?
    var mantisProjectId: Int?
    var isActive: Bool
    var projectedTime: Double?
    var projectedDateComplete: Date?
    var pmProjectId: Int?
    var hideTimeReporting: Bool?
    var startDate: Date?


    typealias Database = MySQLDatabase
    typealias ID = Int
    static let idKey: IDKey = \.id
    static let entity = "fProjects"

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
}
