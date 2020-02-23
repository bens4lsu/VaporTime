//
//  ProjectEvents.swift
//  App
//
//  Created by Ben Schultz on 2/14/20.
//

import Foundation
import FluentMySQL
import Vapor

struct ProjectEvent: Content, MySQLModel, Codable {
    var projectId: Int
    var id: Int?
    var eventId: Int?
    var reportDate: Date
    var notes: String?
    var personId: Int
    var recordedDateTime: Date

    typealias Database = MySQLDatabase
    typealias ID = Int
    static let idKey: IDKey = \.id
    static let entity = "fProjectEvents"

    private enum CodingKeys: String, CodingKey {
        case projectId = "ProjectID",
        id = "ProjectEventID",
        eventId = "EventID",
        reportDate = "ReportDate",
        notes = "Notes",
        personId = "PersonID",
        recordedDateTime = "RecordedDateTime"
    }
}
