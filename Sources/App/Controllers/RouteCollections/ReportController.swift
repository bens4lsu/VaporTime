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

    private let db = MySQLDirect()
    private let cache: DataCache
    
    let df: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "MM/dd/yy"
        return df
    }()
    
    private var cachedLookupContext: LookupContext?
        
    // MARK: Startup
    init(_ cache: DataCache) {
        self.cache = cache
    }

    func boot(router: Router) throws {
        router.get("Report", use: renderReportSelector)
        router.post("Report", use: renderReport)
    }
    
    private func renderReportSelector(_ req: Request) throws -> Future<Response> {
        return try UserAndTokenController.verifyAccess(req, accessLevel: .report) { _ in
            return try self.cache.getLookupContext(req).flatMap(to: Response.self) { context in
                return try req.view().render("report-selector", context).encode(for: req)
            }
        }
    }
        
        
    private func renderReport(_ req: Request) throws -> Future<Response> {
        return try UserAndTokenController.verifyAccess(req, accessLevel: .report) { user in
            
            
            let startDateReqStr: String? = try? req.content.syncGet(at: "dateFrom")
            let endDateReqStr: String? = try? req.content.syncGet(at: "dateTo")
            let billedById: Int? = try? req.content.syncGet(at: "billedById")
            let contractId: Int? = try? req.content.syncGet(at: "contractId")
            let servicesForCompanyId: Int? = try? req.content.syncGet(at: "companyId")
            let projectId: Int? = try? req.content.syncGet(at: "projectId")
            let groupBy1: Int? = try? req.content.syncGet(at: "group1")
            let groupBy2: Int? = try? req.content.syncGet(at: "group2")
            let display: String? = try? req.content.syncGet(at: "display")
            
            guard let startDateReq = startDateReqStr,
                let endDateReq = endDateReqStr,
                let startDate = self.df.date(from: startDateReq),
                let endDate = self.df.date(from: endDateReq) else
            {
                throw Abort(.badRequest, reason: "Start Date and End Date are required for reporting.")
            }
            
            let filters = ReportFilters(startDate: startDate, endDate: endDate, billedById: billedById, contractId: contractId, servicesForCompanyId: servicesForCompanyId, projectId: projectId)
                        
            return try self.db.getReportData(req, filters: filters, userId: user.id).flatMap(to: Response.self) { reportData in
                return try self.cache.getLookupContext(req).flatMap(to: Response.self) { lookupData in
                    let footnote = self.getFootnote(from: filters, and: lookupData)
                    var records = [ReportRendererGroup]()
                    for row in reportData {
                        records.add(row, group1: ReportGroupBy.fromRaw(groupBy1) ?? nil,
                                    group2: ReportGroupBy.fromRaw(groupBy2) ?? nil)
                    }
                    records.sort()
                    var context = ReportContext(top: records, levels: records.levels, startDate: startDate, endDate: endDate, footnote: footnote)
                    context.updateTotals()
                    let report = display == "s" ? "report-summary" : "report"
                    return try req.view().render(report, context).encode(for: req)
                }
            }
        }
    }
    
    func getFootnote(from filters: ReportFilters, and lookupData: LookupContext) -> String {
        var footnote = "Data for dates from \(self.df.string(from: filters.startDate)) to \(self.df.string(from: filters.endDate)).\n"
       
        if let billedById = filters.billedById {
            let biller = lookupData.timeBillers.filter({$0.id == billedById})[0].name
            footnote += "Only showing rows billed by \(biller)\n"
        }
        
        if let contractId = filters.contractId,
            let contract = lookupData.contracts.filter({$0.id == contractId}).first
        {
            let name = contract.name
            footnote += "Only showing rows for the contract named \"\(name)\""
        }
        
        if let servicesForId = filters.servicesForCompanyId,
            let servicesFor = lookupData.companies.filter({$0.id == servicesForId}).first
        {
            let name = servicesFor.name
            footnote += "Only showing rows where services are for the company named \"\(name)\""
        }
        
        if let projectId = filters.projectId,
            let project = lookupData.projects.filter({$0.id == projectId}).first
        {
            let name = project.name
            footnote += "Only showing rows for the project named \"\(name)\""
        }
        
        return footnote
    }
}



// MARK:  Extensions to the data structures used to template the data in the reports

extension Array where Element == ReportRendererGroup {
    
    var levels: Int  {
        if self.count == 0 {          // no data returned that met report parameters
            return 0
        }
        else if self[0].childGroups == nil {    // one group
            return 1
        }
        else {
            return 2
        }
    }
    
    mutating func add(_ row: ReportData, group1: ReportGroupBy?, group2: ReportGroupBy?) {
        
        if (group1 == nil && group2 == nil && self.isEmpty) {
            self.append(ReportRendererGroup(title: "Time Billing", childGroups: nil, childRecords: [row], sortValue: ""))
        }
        else if (group1 == nil && group2 == nil) {
            self[0].childRecords!.append(row)
        }
        
        else if group1 != nil && group2 == nil {
            let title = group1!.title(from: row)
            
            if let index = indexOfElementWith(title, in: self) {
                self[index].childRecords!.append(row)
            } else {
                let sortValue = group1!.sortValue(from: row)
                self.append(ReportRendererGroup(title: title, childGroups: nil, childRecords: [row], sortValue: sortValue))
            }
        }
        
        else if group1 != nil && group2 != nil {
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
