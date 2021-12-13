//
//  ReportController.swift
//  App
//
//  Created by Ben Schultz on 2/7/20.
//

import Foundation
import Vapor
import FluentMySQLDriver
import Leaf

class ReportController: RouteCollection {

    private let db = MySQLDirect()
    private let cache: DataCache
    
    let df: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "MM/dd/yy"
        return df
    }()
            
    // MARK: Startup
    init(_ cache: DataCache) {
        self.cache = cache
    }

    func boot(routes: RoutesBuilder) throws {
        routes.get("Report", use: renderReportSelector)
        routes.post("Report", use: renderReport)
    }
    
    
    private func renderReportSelector(_ req: Request) async throws -> Response {
        return try await UserAndTokenController.ifVerifiedDo(req, accessLevel: .report) { _ in
            let context = try await cache.getLookupContext(req)
            return try await req.view.render("report-selector", context).encodeResponse(for: req)
        }
    }
    
    
    private func renderReport(_ req: Request) async throws -> Response {
        struct PostVars: Content{
            var dateFrom: String?
            var dateTo: String?
            var billedById: String?
            var contractId: String?
            var companyId: String?
            var projectId: String?
            var group1: String?
            var group2: String?
            var display: String?
        }
        
        let pv = try req.content.decode(PostVars.self)
        let startDateReqOpt: Date? = pv.dateFrom.toDate()
        let endDateReqOpt: Date? = pv.dateTo.toDate()
        let billedById: Int? = Int(pv.billedById ?? "")
        let contractId: Int? = Int(pv.contractId ?? "")
        let servicesForCompanyId: Int? = Int(pv.companyId ?? "")
        let projectId: Int? = Int(pv.projectId ?? "")
        let groupBy1: Int? = Int(pv.group1 ?? "")
        let groupBy2: Int? = Int(pv.group2 ?? "")
        let display: String? = pv.display
        
        guard let startDate = startDateReqOpt,
            let endDate = endDateReqOpt else
        {
            throw Abort(.badRequest, reason: "Start Date and End Date are required for reporting.")
        }
        
        return try await UserAndTokenController.ifVerifiedDo(req, accessLevel: .report) { user in
            let filters = ReportFilters(startDate: startDate, endDate: endDate, billedById: billedById, contractId: contractId, servicesForCompanyId: servicesForCompanyId, projectId: projectId)
                        
            async let reportData = db.getReportData(req, filters: filters, userId: user.id)
            async let lookupData = cache.getLookupContext(req)
            let footnote = self.getFootnote(from: filters, and: try await lookupData).replaceLineBreaksHtml()
            var records = [ReportRendererGroup]()
            for row in try await reportData {
                records.add(row, group1: ReportGroupBy.fromRaw(groupBy1) ?? nil,
                            group2: ReportGroupBy.fromRaw(groupBy2) ?? nil)
            }
            records.sort()
            var context = ReportContext(top: records, levels: records.levels, startDate: startDate, endDate: endDate, footnote: footnote)
            context.updateTotals()
            let report = display == "s" ? "report-summary" : "report"
            return try await req.view.render(report, context).encodeResponse(for: req)
        }
    }
    
    private func getFootnote(from filters: ReportFilters, and lookupData: LookupContext) -> String {
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
        for index in 0..<self.count {
            if self[index].childGroups != nil {
                self[index].childGroups!.sort()
            }
            else if self[index].childRecords != nil {
                self[index].childRecords!.sort()
            }
        }
    }
}

