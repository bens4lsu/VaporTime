//
//  TimeBillingController.swift
//  App
//
//  Created by Ben Schultz on 1/31/20.
//

import Foundation
import Vapor
import FluentMySQL
import Leaf


// TODO:  For rendered views that show up inside a frame, if the session has become invalid, don't redirect to login,
//        because then you have a login screen inside a frame.  Just go to a session-exipred page.
//          Is there a way to redirect the top page of the browser?  maybe I can send a post to a javascript listener
//          on index?
//

class TimeBillingController: RouteCollection {
    
    let userAndTokenController: UserAndTokenController
    let db = MySQLDirect()
        
    // MARK: Startup
    init(_ userAndTokenController: UserAndTokenController) {
        self.userAndTokenController = userAndTokenController
    }
    
    func boot(router: Router) throws {
        router.get("TBTable", use: renderTimeTable)
        router.post("ajax/savesession", use: updateSessionFilters)
        router.get("TBTree", use: renderTimeTree)
        router.get("TBAddEdit", use: renderTimeAddEdit)
        router.post("TBAddEdit", use: addEditTimeEntry)
        router.post("ajax/deleteTimeRecord", use: deleteTimeEntry)
    }
    
    private func sessionSortOptions(_ req: Request) -> TimeBillingSessionFilter {
        guard let session = try? req.session(),
            let tokenJSON = session["sorts"] else {
                return TimeBillingSessionFilter()
        }
        let decoder = JSONDecoder()
        let filter = (try? decoder.decode(TimeBillingSessionFilter.self, from: tokenJSON))  ?? TimeBillingSessionFilter()
        return filter
    }
    
    // MARK:  Methods connected to routes that return Views
    
    private func renderTimeTable(_ req: Request) throws -> Future<Response> {
        let highlightRow = try? req.query.get(Int.self, at: "highlightRow")
        return try UserAndTokenController.verifyAccess(req, accessLevel: .timeBilling) { user in
            return try db.getTBTableCOpts(req).flatMap(to: Response.self) { cOpts in
                return try self.db.getTBTablePOpts(req).flatMap(to: Response.self) {pOpts in
                    return try self.db.getTBTable(req, userId: user.id).flatMap(to: Response.self) { entries in
                        let context = TBTableContext(entries: entries, filter: self.sessionSortOptions(req), highlightRow: highlightRow, cOpts: cOpts.toJSON(), pOpts: pOpts.toJSON())
                        return try req.view().render("time-table", context).encode(for: req)
                    }
                }
            }
        }
    }
    
    private func renderTimeTree(_ req: Request) throws -> Future<Response> {
        return try UserAndTokenController.verifyAccess(req, accessLevel: .timeBilling) { user in
            return try db.getTBTree(req, userId: user.id).flatMap(to:Response.self) { items in
                let treeItems = self.convertDbItemsToTreeItems(items: items)
                let context = TBTreeContext(items: treeItems)
                return try req.view().render("time-tree", context).encode(for: req)
            }
        }
    }
    
    private func renderTimeAddEdit(_ req: Request) throws -> Future<Response> {
        guard let projectId = try? req.query.get(Int.self, at: "projectId") else {
            throw Abort(.badRequest, reason: "Time edit requested with no projectId.")
        }
        let timeId = try? req.query.get(Int.self, at: "timeId")
        return try UserAndTokenController.verifyAccess(req, accessLevel: .timeBilling) { _ in
            return try db.getTBAdd(req, projectId: projectId).flatMap(to: Response.self) { project in
                guard let project = project else {
                    throw Abort(.badRequest, reason: "Database lookup for project returned no records.")
                }
                var context = TBAddEditContext(project: project)
                if let timeId = timeId {
                    return Time.find(timeId, on: req).flatMap(to: Response.self) { time in
                        guard var time = time else {
                            return try req.view().render("time-add-edit", context).encode(for: req)
                        }
                        time.workDate = time.workDate.addingTimeInterval(12*3600)
                        context.time = time
                        return try req.view().render("time-add-edit", context).encode(for: req)
                    }
                } else {
                    return try req.view().render("time-add-edit", context).encode(for: req)
                }
                
            }
        }
    }
    
    
    // MARK:  Methods connected to routes that return data or redirect
    
    private func updateSessionFilters(_ req: Request) throws -> Future<Response> {
        return try UserAndTokenController.verifyAccess(req, accessLevel: .timeBilling) { user in
            // TODO:  save selected info change in the session
            return try "ok".encode(for: req)
        }
    }
    
    private func addEditTimeEntry(_ req: Request) throws -> Future<Response> {
        let timeId = try? req.query.get(Int.self, at: "timeId")
        let projectIdOpt = try? req.query.get(Int.self, at: "projectId")
        let workDateOpt = (try? req.content.syncGet(at: "datepicker")).toDate()
        let durationOpt: Double? = try? req.content.syncGet(at: "duration")
        let useOtRate = (try? req.content.syncGet(at: "ot")).toBool()
        let preDelivery = (try? req.content.syncGet(at: "pre")).toBool()
        let notes: String = (try? req.content.syncGet(at: "notes")) ?? ""
        let doNotBill = (try? req.content.syncGet(at: "nobill")).toBool()
    
        guard let projectId = projectIdOpt, let workDate = workDateOpt, let duration = durationOpt else {
            throw Abort(.badRequest, reason: "Time entry submitted without at least one required value (project, date, duration).")
        }
        return try UserAndTokenController.verifyAccess(req, accessLevel: .timeBilling) { user in
            let time = Time(id: timeId, personId: user.id, projectId: projectId, workDate: workDate, duration: duration, useOTRate: useOtRate, notes: notes, exportStatus: 0, preDeliveryFlag: preDelivery, doNotBillFlag: doNotBill)
            return time.save(on: req).map(to: Response.self) { timeRow in
                var urlAddString = ""
                if timeRow.id != nil {
                    // i can't think of how this comes back nil, but I'll stick this line in an if, just in case...
                    urlAddString = "?highlightRow=\(timeRow.id!)"
                }
                return req.redirect(to: "TBTable\(urlAddString)")
            }
        }
    }
    
    private func deleteTimeEntry(_ req: Request) throws -> Future<Response> {
        //return try UserAndTokenController.verifyAccess(req, accessLevel: .timeBilling) { user in
            let timeId = try? req.content.syncGet(Int.self, at: "timeId")
            guard let time = timeId else {
                return try ["Error" : "request for delete recieved with no id."].encode(for: req)
            }
            return Time.query(on:req).filter(\.id == time).delete().flatMap(to: Response.self) {
                return try ["OK" : "OK"].encode(for: req)
            }
        //}
    }
    
    // MARK:  Helpers
    
    private func convertDbItemsToTreeItems(items: [TBTreeColumn]) -> [TBTreeItem] {
    /*
        Build the tree.  We want to meet these requirements...
        
        A) If we have one contract, one services for company, and one project, just have one line in the tree.
        B) If we have 1 services for and many projects, put contract and sf on one line, and projects below.
        C) If we have >1 services for and 1 project, put SF & P together under the contract level.
        D) If we have >1 services for and >1 project, need three levels.

    */
        
        // Build dictionaries of sets, which keep listings from being
        // duplicated and let us pluck information that we need in the
        // main logic below

        var contractProjectDictionary = [Int: Set<Int>]()
        var contractCompanyDictionary = [Int: Set<String>]()
        var contracts = Set<Int>()
        
        for item in items {
            let contract = item.contractId
            contracts.insert(contract)
            if contractProjectDictionary[contract] == nil {
                contractProjectDictionary[contract] = Set<Int>()
            }
            contractProjectDictionary[contract]!.insert(item.projectId)
            if contractCompanyDictionary[contract] == nil {
                contractCompanyDictionary[contract] = Set<String>()
            }
            contractCompanyDictionary[contract]!.insert(item.servicesForCompany)
        }
        
        
        // Here's the logic -- iterate over each contract (top level)
        var treeItems = [TBTreeItem]()
        for contract in contracts {
            let projCount = contractProjectDictionary[contract]!.count
            let sfCount = contractCompanyDictionary[contract]!.count
            
            if projCount == 1 && sfCount == 1 {
                // A
                let row = items.filter { $0.projectId == contractProjectDictionary[contract]!.first }.first!
                let level1 = "\(row.contractDescription) - \(row.projectDescription)"
                let branch = TBTreeItemBranch(label: level1, projectId: row.projectId)
                let item = TBTreeItem(levels: 1, level1: branch, contractId: row.contractId)
                treeItems.append(item)
            }
                
            else if projCount > 1 && sfCount == 1 {
                // B
                let rows = items.filter { contractProjectDictionary[contract]!.contains($0.projectId) }
                var level1 = TBTreeItemBranch(label: "\(rows.first!.contractDescription) - \(rows.first!.servicesForCompany)")
                var level2 = [TBTreeItemBranch]()
                for row in rows {
                    var label: String
                    if let projectNumber = row.projectNumber {
                        label = projectNumber.trimmingCharacters(in: .whitespacesAndNewlines)
                        label = level2.count > 0 ? "\(level2) - \(row.projectDescription)" : row.projectDescription
                    } else {
                        label = row.projectDescription
                    }
                    level2.append(TBTreeItemBranch(label: label, projectId: row.projectId))
                }
                level1.children = level2.sorted()
                let item = TBTreeItem(levels: 2, level1: level1, contractId: contract)
                treeItems.append(item)
            }
                
            else if projCount == 1 && sfCount > 1 {
                // C
                let rows = items.filter { contractCompanyDictionary[contract]!.contains($0.servicesForCompany) }
                var level1 = TBTreeItemBranch(label: "\(rows.first!.contractDescription)")
                var level2 = [TBTreeItemBranch]()
                for row in rows {
                    level2.append(TBTreeItemBranch(label: "\(row.servicesForCompany) - \(row.projectDescription)", projectId: row.projectId))
                }
                level1.children = level2.sorted()
                let item = TBTreeItem(levels: 2, level1: level1, contractId: contract)
                treeItems.append(item)
            }
                
            else {
                // D
                let companies = contractCompanyDictionary[contract]!
                let contractStruct = items.filter { $0.contractId == contract }.first!
                var level1 = TBTreeItemBranch(label: contractStruct.contractDescription, projectId: nil, children: Array())
                for company in companies {
                    var level2 = TBTreeItemBranch(label: company)
                    var level3 = [TBTreeItemBranch]()
                    let rows = items.filter { $0.servicesForCompany == company && $0.contractId == contract}
                    for row in rows {
                        level3.append(TBTreeItemBranch(label: row.projectDescription, projectId: row.projectId))
                    }
                    level2.children = level3.sorted()
                    // if level2 only has one child, flatten it
                    if level2.children!.count == 1 {
                        let child = level2.children!.first!
                        level2 = TBTreeItemBranch(label: "\(level2.label) - \(child.label)")
                    }
                    level1.children!.append(level2)
                }
                level1.children!.sort()
                let item = TBTreeItem(levels: 3, level1: level1, contractId: contractStruct.contractId)
                treeItems.append(item)
            }
        }
        return treeItems.sorted { $0.level1.label < $1.level1.label }
    }
}


