//
//  ProjectRenderingStructs.swift
//  App
//
//  Created by Ben Schultz on 3/3/20.
//

import Foundation

struct TotalTime: Codable {
    var TotalTime: Double?
    var CompletionByTime: Double?
    var CompletionByDate: Double?
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
}

struct RateList: Codable {
    var Name: String
    var RateDescription: String
    var StartDate: Date?
    var EndDate: Date?
}
