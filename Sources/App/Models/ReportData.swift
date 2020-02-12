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
    
    static func list() -> [LookupContextPair] {
        [LookupContextPair(name: "Contract", id: Self.contract.rawValue),
        LookupContextPair(name: "Project", id: Self.project.rawValue),
        LookupContextPair(name: "Services For Company", id: Self.serviceFor.rawValue),
        LookupContextPair(name: "Billed By", id: Self.person.rawValue),
        LookupContextPair(name: "Week", id: Self.week.rawValue),
        LookupContextPair(name: "Month", id: Self.month.rawValue)]
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
    var notes: String
    
    private enum CodingKeys: String, CodingKey {
        case firstDayOfWeekMonday = "FirstDayOfWeekMonday",
        firstOfMonth = "FirstOfMonth",
        duration = "Duration",
        workDate = "WorkDate",
        contractDescription = "ContractDescription",
        projectDescription = "ProjectDescription",
        servicesForCompany = "ServicesForCompany",
        billedByName = "BilledByName",
        notes = "Notes"
    }
    
    static func < (lhs: ReportData, rhs: ReportData) -> Bool {
        lhs.workDate < rhs.workDate
    }
    
    static func == (lhs: ReportData, rhs: ReportData) -> Bool {
        lhs.workDate == rhs.workDate
    }
}

class ReportRendererGroup: Encodable, Comparable {
    var title: String
    var childGroups: [ReportRendererGroup]?
    var childRecords: [ReportData]?
    var sortValue: String
    var total: Double = 0.0  // dumb workaround.  I can't get the caluclated property version of total to encode
                            // for leaf.  The total might encode correctly, but it chokes on the [ReportData]? type.
                            // See also mutating func at the end.
    var count: Int = 0
    
    var totalCalc: (Double, Int) {
        if let groups = childGroups {
            var total = 0.0
            var count = 0
            for group in groups {
                group.updateTotal()
                total += group.total
                count += group.count
            }
            return (total, count)
        }
        else if let records = childRecords {
            return (records.reduce(0, { tot, record in tot + record.duration  }), records.count)
        }
        else {
            return (0.0, 0)
        }
    }
    
    var countCalc: Int {
        if let groups = childGroups {
            return groups.reduce(0, { tot, group in group.countCalc })
        }
        else if let records = childRecords {
            return records.count
        }
        else {
            return 0
        }
    }
    
    init(title: String, childGroups: [ReportRendererGroup]?, childRecords: [ReportData]?, sortValue: String) {
        self.title = title
        self.childGroups = childGroups
        self.childRecords = childRecords
        self.sortValue = sortValue
    }
    
    static func < (lhs: ReportRendererGroup, rhs: ReportRendererGroup) -> Bool {
        lhs.sortValue < rhs.sortValue
    }
    
    static func == (lhs: ReportRendererGroup, rhs: ReportRendererGroup) -> Bool {
        lhs.sortValue == rhs.sortValue
    }
    
    func updateTotal() {
        let (total, count) = self.totalCalc
        self.total = total
        self.count = count
    }
}

struct ReportContext: Encodable {
    var top: [ReportRendererGroup]
    var levels: Int
    var startDate: Date
    var endDate: Date
    var grandTotal: Double = 0.0
    var count: Int = 0
    
    mutating func updateTotals() {
        grandTotal = 0.0
        count = 0
        for renderer in top {
            renderer.updateTotal()
            grandTotal += renderer.total
            count += renderer.count
        }
    }
}



