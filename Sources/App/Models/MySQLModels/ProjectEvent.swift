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
    
    init (projectId: Int, id: Int?, eventId: Int?, reportDate: Date, notes: String?, personId: Int, recordedDateTime: Date) {
        self.projectId = projectId
        self.id = id
        self.reportDate = reportDate
        self.notes = notes
        self.personId = personId
        self.recordedDateTime = recordedDateTime
        self.eventId = eventId
    }
    
    init (projectId: Int, eventId: Int, personId: Int) {
        self.init(projectId: projectId, id: nil, eventId: eventId, reportDate: Date(), notes: nil, personId: personId, recordedDateTime: Date())
    }
    
    init (projectId: Int, eventId: Int, personId: Int, notes: String) {
        self.init(projectId: projectId, id: nil, eventId: eventId, reportDate: Date(), notes: notes, personId: personId, recordedDateTime: Date())

    }
    
    init (projectId: Int, eventId: Int?, eventDate: Date, personId: Int, notes: String?) {
        self.init(projectId: projectId, id: nil, eventId: eventId, reportDate: eventDate, notes: notes, personId: personId, recordedDateTime: Date())

    }
}
