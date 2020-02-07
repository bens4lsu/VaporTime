//
//  ReportData.swift
//  App
//
//  Created by Ben Schultz on 2/7/20.
//

import Foundation

struct ReportFilters {
    var startDate: Date
    var endDate: Date
    var billedById: Int?
    var contractId: Int?
    var servicesForCompanyId: Int?
    var projectId: Int?
}

enum ReportGroupBy: Int {
    case contract = 1
    case project
    case serviceFor
    case person
    case week
    case month
    
    static func fromRaw(_ val: Int?) -> Self? {
        guard let value = val else {
            return nil
        }
        return Self(rawValue: value)
    }
    
    func title(from row: ReportData) -> String {
        
        let dateFormatterMMyy: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM/yy"
            return formatter
        }()
        
        var title = ""
        switch self {
        case .contract:
            title = "Contract: \(row.contractDescription)"
        case .project:
            title = "Project: \(row.projectDescription)"
        case .serviceFor:
            title = "Work for Company: \(row.servicesForCompany)"
        case .person:
            title = "Billed by: \(row.billedByName)"
        case .week:
            title = "Week starting: \(row.firstDayOfWeekMonday)"
        case .month:
            title = "Month of: \(dateFormatterMMyy.string(from: row.firstOfMonth))"
        }
        return title
    }
    
    func sortValue(from row: ReportData) -> String {
        
        var sortValue = ""
        switch self {
        case .contract:
            sortValue = row.contractDescription
        case .project:
            sortValue = row.projectDescription
        case .serviceFor:
            sortValue = row.servicesForCompany
        case .person:
            sortValue = row.billedByName
        case .week:
            sortValue = String(row.firstDayOfWeekMonday.timeIntervalSinceReferenceDate)
        case .month:
            sortValue = String(row.firstOfMonth.timeIntervalSinceReferenceDate)
        }
        return sortValue
    }
}

enum ReportView {
    case detailView
    case summaryView
}

struct ReportData: Codable, Comparable {
    var firstDayOfWeekMonday: Date
    var firstOfMonth: Date
    var duration: Double
    var workDate: Date
    var contractDescription: String
    var projectDescription: String
    var servicesForCompany: String
    var billedByName: String
    
    static func < (lhs: ReportData, rhs: ReportData) -> Bool {
        lhs.workDate < rhs.workDate
    }
    
    static func == (lhs: ReportData, rhs: ReportData) -> Bool {
        lhs.workDate == rhs.workDate
    }
}

struct ReportRendererGroup: Codable, Comparable {
    var title: String
    var childGroups: [ReportRendererGroup]?
    var childRecords: [ReportData]?
    var sortValue: String
    
    var total: Double {
        if let groups = childGroups {
            return groups.reduce(0, { tot, group in tot + group.total  })
        }
        else if let records = childRecords {
            return records.reduce(0, { tot, record in tot + record.duration  })
        }
        else {
            return 0
        }
    }
    
    static func < (lhs: ReportRendererGroup, rhs: ReportRendererGroup) -> Bool {
        lhs.sortValue < rhs.sortValue
    }
    
    static func == (lhs: ReportRendererGroup, rhs: ReportRendererGroup) -> Bool {
        lhs.sortValue == rhs.sortValue
    }
}

struct ReportContext {
    var top: [ReportRendererGroup]
    var levels: Int
    var startDate: Date
    var endDate: Date
}



