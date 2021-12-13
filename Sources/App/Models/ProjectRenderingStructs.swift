//
//  ProjectRenderingStructs.swift
//  App
//
//  Created by Ben Schultz on 3/3/20.
//


#warning( "bms - Add coding keys so that properties can start with lowercase letters.")
import Foundation

struct TotalTime: Codable {
    var TotalTime: Double?
    var CompletionByTime: Double?
    var CompletionByDate: Double?   // not an error on the type.  This is the measure used for the progress circle
    
    
}


struct ProjectAddEdit: Codable {
    var lookup: LookupContext
    var project: Project
    var totalTime: TotalTime
    var buglink: String?
    var journals: [Journal]?
    var rateLists: [RateList]?
}

struct Journal: Codable {
    var ReportDate: Date
    var Notes: String?
    var EventDescription: String?
    var EventWhoGenerates: String?
    var Name: String?
    var id: Int
    
    func formatForDisplay() -> Journal {
        var tmpJournal = self
        tmpJournal.ReportDate = tmpJournal.ReportDate.asLocal
        tmpJournal.Notes = tmpJournal.Notes?.replaceLineBreaksHtml()
        return tmpJournal
    }
}

struct RateList: Codable {
    var Name: String
    var RateDescription: String
    var StartDate: Date?
    var EndDate: Date?
    
    func toLocalDates() -> RateList {
        var temp = self
        temp.StartDate = temp.StartDate?.asLocal
        temp.EndDate = temp.EndDate?.asLocal
        return temp
    }
}
