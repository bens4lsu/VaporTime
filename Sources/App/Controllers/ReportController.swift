//
//  ReportController.swift
//  App
//
//  Created by Ben Schultz on 2/7/20.
//

import Foundation
import Vapor
import FluentMySQL
import Leaf

class ReportController: RouteCollection {

    let userAndTokenController: UserAndTokenController
    let db = MySQLDirect()
        
    // MARK: Startup
    init(_ userAndTokenController: UserAndTokenController) {
        self.userAndTokenController = userAndTokenController
    }

    func boot(router: Router) throws {
        router.get("Report", use: renderReportSelector)
        router.post("Report", use: renderReport)
    }
    
    private func renderReportSelector(_ req: Request) throws -> Future<Response> {
        return try UserAndTokenController.verifyAccess(req, accessLevel: .report) { _ in
            
            return try db.getLookupTrinity(req).flatMap(to: Response.self) { lookupTrinity in
                return try self.db.getLookupPerson(req).flatMap(to: Response.self) { lookupPerson in
                    
                    let context = LookupContext(contracts: lookupTrinity.contracts,
                                                companies: lookupTrinity.companies,
                                                projects: lookupTrinity.projects,
                                                timeBillers: lookupPerson,
                                                groupBy: ReportGroupBy.list() )
                    return try req.view().render("report-selector", context).encode(for: req)
                }
            }
        }
    }
        
        
    private func renderReport(_ req: Request) throws -> Future<Response> {
        return try UserAndTokenController.verifyAccess(req, accessLevel: .report) { _ in
            let startDateReq = try? req.query.get(Date.self, at: "startDate")
            let endDateReq = try? req.query.get(Date.self, at: "endDate")
            let billedById = try? req.query.get(Int.self, at: "billedById")
            let contractId = try? req.query.get(Int.self, at: "contractId")
            let servicesForCompanyId = try? req.query.get(Int.self, at: "servicesForCompanyId")
            let projectId = try? req.query.get(Int.self, at: "projectId")
            let groupBy1 = try? req.query.get(Int.self, at: "groupBy1")
            let groupBy2 = try? req.query.get(Int.self, at: "groupBy2")
            
            guard let startDate = startDateReq, let endDate = endDateReq else {
                throw Abort(.badRequest, reason: "Start Date and End Date are required for reporting.")
            }
            
            let filters = ReportFilters(startDate: startDate, endDate: endDate, billedById: billedById, contractId: contractId, servicesForCompanyId: servicesForCompanyId, projectId: projectId)
            
            return try db.getReportData(req, filters: filters).flatMap(to: Response.self) { reportData in
                
                var records = [ReportRendererGroup]()
                for row in reportData {
                    records.add(row, group1: ReportGroupBy.fromRaw(groupBy1) ?? nil,
                                group2: ReportGroupBy.fromRaw(groupBy2) ?? nil)
                }
                records.sort()
                
                let context = ReportContext(top: records, levels: records.levels, startDate: startDate, endDate: endDate)
                return try req.view().render("report", context).encode(for: req)
            }
        }
    }
}

extension Array where Element == ReportRendererGroup {
    
    var levels: Int {
        if self.count == 1 {
            return 1
        }
        else if self[0].childGroups == nil {
            return 2
        }
        else {
            return 3
        }
    }
    
    mutating func add(_ row: ReportData, group1: ReportGroupBy?, group2: ReportGroupBy?) {
        
        if (group1 == nil && group2 == nil && self.isEmpty) {
            self.append(ReportRendererGroup(title: "Time Billing", sortValue: ""))
        }
        else if (group1 == nil && group2 == nil) {
            self[0].childRecords!.append(row)
        }
        
        if group1 != nil && group2 == nil {
            let title = group1!.title(from: row)
            
            if let index = indexOfElementWith(title, in: self) {
                self[index].childRecords!.append(row)
            } else {
                let sortValue = group1!.sortValue(from: row)
                self.append(ReportRendererGroup(title: title, childGroups: nil, childRecords: [row], sortValue: sortValue))
            }
        }
        
        if group1 != nil && group2 != nil {
            let title1 = group1!.title(from: row)
            let title2 = group2!.title(from: row)
            let sortValue1 = group1!.sortValue(from: row)
            let sortValue2 = group2!.sortValue(from: row)
            let group2 = ReportRendererGroup(title: title2, childGroups: nil, childRecords: [row], sortValue: sortValue2)
            let (index1, index2) = indexOfChildElementWith(title1: title1, title2: title2)
            if index1 == nil {
                let group1 = ReportRendererGroup(title: title1, childGroups: [group2], childRecords: nil, sortValue: sortValue1)
                self.append(group1)
            }
            else if index1 != nil && index2 == nil {
                self[index1!].childGroups!.append(group2)
            }
            else if index1 != nil && index2 != nil {
                self[index1!].childGroups![index2!].childRecords!.append(row)
            }
        }
    }
    
    func indexOfElementWith(_ title: String, in array: [ReportRendererGroup]) -> Int? {
        let arrayOfIndexes = array.enumerated().filter({
            let (_, reportRenderingGroup) = $0
            return title == reportRenderingGroup.title
        }).map({ $0.offset })   // should be either empty, or have one element with the index
        return arrayOfIndexes.isEmpty ? nil : arrayOfIndexes[0]
    }
    
    func indexOfChildElementWith(title1: String, title2: String) -> (Int?, Int?) {
        let index1 = indexOfElementWith(title1, in:self)
        var index2: Int? = nil
        if index1 != nil {
            if let childGroups = self[index1!].childGroups {
                index2 = indexOfElementWith(title2, in: childGroups)
            }
        }
        return (index1, index2)
    }
    
    mutating func sort() {
        for elem in self {
            if var childGroups = elem.childGroups {
                childGroups.sort()
            }
            if var childRecords = elem.childRecords {
                childRecords.sort()
            }
        }
    }
}

extension Array where Element == LookupTrinity {
    var contracts: Set<LookupContextPair>{
        var set = Set<LookupContextPair>()
        for elem in self {
            set.insert(LookupContextPair(name: elem.contractDescription, id: elem.contractId))
        }
    return set
    }
    
    var companies: Set<LookupContextPair>{
        var set = Set<LookupContextPair>()
        for elem in self {
            set.insert(LookupContextPair(name: elem.servicesForCompany, id: elem.companyId))
        }
        return set
    }
    
    var projects: Set<LookupContextPair>{
        var set = Set<LookupContextPair>()
        for elem in self {
            set.insert(LookupContextPair(name: elem.projectDescription, id: elem.projectId))
        }
        return set
    }
}
