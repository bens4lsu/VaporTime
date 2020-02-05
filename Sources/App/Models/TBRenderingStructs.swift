//
//  TBTableColumns.swift
//  App
//
//  Created by Ben Schultz on 2/3/20.
//

import Foundation

// MARK: TBTable
struct TBTableColumns: Codable {
    var timeId: Int
    var description: String
    var projectNumber: String?
    var projectDescription: String
    var workDate: Date
    var duration: Double
    var useOTRate: Bool
    var notes: String
    var preDeliveryFlag: Bool
    var exportStatus: Int
    
    // MARK: Map to MySQL database and columns
    
    private enum CodingKeys: String, CodingKey {
        case timeId = "TimeID",
        description = "Description",
        projectNumber = "ProjectNumber",
        projectDescription = "ProjectDescription",
        workDate = "WorkDate",
        duration = "Duration",
        useOTRate = "useOTRate",
        notes = "Notes",
        preDeliveryFlag = "PreDeliveryFlag",
        exportStatus = "ExportStatus"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.timeId = try container.decodeIfPresent(Int.self, forKey: .timeId)!
        self.description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        self.projectNumber = try container.decodeIfPresent(String.self, forKey: .projectNumber)
        self.projectDescription = try container.decodeIfPresent(String.self, forKey: .projectDescription) ?? ""
        self.workDate = try container.decodeIfPresent(Date.self, forKey: .workDate)!
        self.duration = try container.decodeIfPresent(Double.self, forKey: .duration) ?? 0.0
        self.useOTRate = (try? container.decodeIfPresent(String.self, forKey: .useOTRate)) == "1" ? true : false
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        self.preDeliveryFlag = (try? container.decodeIfPresent(String.self, forKey: .useOTRate)) == "1" ? true : false
        self.exportStatus = try container.decodeIfPresent(Int.self, forKey: .exportStatus) ?? 0
    }
}

struct TBTableContext: Encodable {
    var entries: [TBTableColumns]
    var filter: TimeBillingSessionFilter
    var highlightRow = 3631
    var cOpts: String?
    var pOpts: String?
}

struct TimeBillingSessionFilter: Codable {
    var contract: String?
    var project: String?
    var dateFrom: Date?
    var dateTo: Date?
    var durationFrom: Double?
    var durationTo: Double?
    var noteFilter: String?
    var sortColumn: Int = 3
    var sortDirection: String = "desc"
}

// MARK: Used for the filtering drop downs at the bottom of the TB Table

struct TBTableSelectOpts: Codable {
    var description: String
}

extension Array where Element == TBTableSelectOpts {
    func toJSON() -> String? {
        let encoder = JSONEncoder()
        let flattened = self.map({$0.description})
        guard let flatJson = try? encoder.encode(flattened) else { return nil }
        return String(data: flatJson, encoding: .utf8)
    }
}

// MARK: TBTree
struct TBTreeItem: Codable {
    var levels: Int
    var level1: TBTreeItemBranch
    var contractId: Int
}

struct TBTreeItemBranch: Codable, Comparable {
    var label: String
    var projectId: Int?
    var children: [TBTreeItemBranch]?
    
    static func < (lhs: TBTreeItemBranch, rhs: TBTreeItemBranch) -> Bool {
        lhs.label < rhs.label
    }
}

struct TBTreeContext: Codable {
    var items: [TBTreeItem]
}

struct TBTreeColumn: Codable {
    var contractId: Int
    var projectId: Int
    var contractDescription: String
    var billToCompany: String
    var projectNumber: String?
    var projectDescription: String
    var servicesForCompany: String
    
    private enum CodingKeys: String, CodingKey {
        case contractId = "ContractID",
        projectId = "ProjectID",
        contractDescription = "ContractDescription",
        billToCompany = "BillToCompany",
        projectNumber = "ProjectNumber",
        projectDescription = "ProjectDescription",
        servicesForCompany = "ServicesForCompany"
    }
}


// MARK:  TB Add/Edit
struct TBEditProjectLabel: Codable {
    var description: String
    var companyName: String
    var projectDescription: String
    var projectNumber: String?
    var projectId: Int
    
    private enum CodingKeys: String, CodingKey {
        case description = "Description"
        case companyName = "CompanyName"
        case projectDescription = "ProjectDescription"
        case projectNumber = "ProjectNumber"
        case projectId = "ProjectID"
    }
}
