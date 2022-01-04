//
//  ProjectRenderingStructs.swift
//  App
//
//  Created by Ben Schultz on 3/3/20.
//


import Foundation

struct TotalTime: Codable {
    var totalTime: Double?
    var completionByTime: Double?
    var completionByDate: Double?   // not an error on the type.  This is the measure used for the progress circle
    
    private enum CodingKeys: String, CodingKey {
        case totalTime = "TotalTime"
        case completionByTime = "CompletionByTime"
        case completionByDate = "CompletionByDate"
    }
}

struct ProjectAddEdit: Codable {
    var lookup: LookupContext
    var project: Project
    var totalTime: TotalTime
    var buglink: String?
    var journals: [Journal]?
    var rateLists: [RateList]?
    var errorMessage: String?  //not currently used
}

struct Journal: Codable {
    var reportDate: Date
    var notes: String?
    var eventDescription: String?
    var eventWhoGenerates: String?
    var name: String?
    var id: Int
    
    private enum CodingKeys: String, CodingKey {
        case reportDate = "ReportDate"
        case notes = "Notes"
        case eventDescription = "EventDescription"
        case name = "Name"
        case id = "id"
    }
    
    func formatForDisplay() -> Journal {
        var tmpJournal = self
        tmpJournal.reportDate = tmpJournal.reportDate.asLocal
        tmpJournal.notes = tmpJournal.notes?.replaceLineBreaksHtml()
        return tmpJournal
    }
}

struct RateList: Codable {
    var name: String
    var rateDescription: String
    var startDate: Date?
    var endDate: Date?
    
    private enum CodingKeys: String, CodingKey {
        case name = "Name"
        case rateDescription = "RateDescription"
        case startDate = "StartDate"
        case endDate = "EndDate"
    }
    
    func toLocalDates() -> RateList {
        var temp = self
        temp.startDate = temp.startDate?.asLocal
        temp.endDate = temp.endDate?.asLocal
        return temp
    }
}
