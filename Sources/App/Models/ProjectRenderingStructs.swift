//
//  ProjectRenderingStructs.swift
//  App
//
//  Created by Ben Schultz on 3/3/20.
//

import Foundation

struct TotalTime: Codable {
    var TotalTime: Double
}


struct ProjectAddEdit: Codable {
    var lookup: LookupContext
    var project: Project
    var totalTime: Double
    var buglink: String
    var journals: [Journal]?
}

struct Journal: Codable {
    var ReportDate: Date
    var Notes: String?
    var EventDescription: String?
    var EventWhoGenerates: String?
    var Name: String?
}
