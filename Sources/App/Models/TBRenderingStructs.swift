//
//  TBTableColumns.swift
//  App
//
//  Created by Ben Schultz on 2/3/20.
//
//  I like to write my database queries with select statements that join columns from other
//  tables, and who leave columns out of tables.  These models map to select statement results
//  from the direct database queries in MySQLDirect.swift

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
    var projectId: Int
    
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
        exportStatus = "ExportStatus",
        projectId = "ProjectID"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.timeId = try container.decodeIfPresent(Int.self, forKey: .timeId)!
        self.description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        self.projectNumber = try container.decodeIfPresent(String.self, forKey: .projectNumber)
        self.projectDescription = try container.decodeIfPresent(String.self, forKey: .projectDescription) ?? ""
        self.workDate = try container.decodeIfPresent(Date.self, forKey: .workDate)!.addingTimeInterval(12*3600)
        self.duration = try container.decodeIfPresent(Double.self, forKey: .duration) ?? 0.0
        self.useOTRate = (try? container.decodeIfPresent(String.self, forKey: .useOTRate)) == "1" ? true : false
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        self.preDeliveryFlag = (try? container.decodeIfPresent(String.self, forKey: .useOTRate)) == "1" ? true : false
        self.exportStatus = try container.decodeIfPresent(Int.self, forKey: .exportStatus) ?? 0
        self.projectId = try container.decodeIfPresent(Int.self, forKey: .projectId)!
    }
}

struct TBTableContext: Encodable {
    var entries: [TBTableColumns]
    var filter: TimeBillingSessionFilter
    var highlightRow: Int?
    var cOpts: String?
    var pOpts: String?
}

struct TimeBillingSessionFilter: Codable {
    // These can all stay as String? type.
    // There's no processing, and no storage, except in the session.
    // It's just test to write back to the screen when the screen reloads.
    var contract: String?
    var project: String?
    var dateFrom: String?
    var dateTo: String?
    var durationFrom: String?
    var durationTo: String?
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
    
    //  need these initializors to build on swift 5.14 on ubuntu
    init(label: String, projectId: Int?) {
        self.label = label
        self.projectId = projectId
    }

    init(label: String) {
        self.label = label
    }
    
    init(label: String, projectId: Int?, children: [TBTreeItemBranch]) {
        self.label = label
        self.projectId = projectId
        self.children = children
    }
}

struct TBTreeContext: Codable {
    var items: [TBTreeItem]
    var editPage = "TBAddEdit"
    var heading = "Add New Time Entry"
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

struct TBAddEditContext: Codable {
    var project: TBEditProjectLabel
    var time: Time?
}
