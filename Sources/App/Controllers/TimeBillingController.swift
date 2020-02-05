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
        return try UserAndTokenController.verifyAccess(req, accessLevel: .timeBilling) { user in
            return try db.getTBTableCOpts(req).flatMap(to: Response.self) { cOpts in
                return try self.db.getTBTablePOpts(req).flatMap(to: Response.self) {pOpts in
                    return try self.db.getTBTable(req, userId: user.id).flatMap(to: Response.self) { entries in
                        let context = TBTableContext(entries: entries, filter: self.sessionSortOptions(req), cOpts: cOpts.toJSON(), pOpts: pOpts.toJSON())
                        return try req.view().render("time-table", context).encode(for: req)
                    }
                }
            }
        }
    }
    
    private func renderTimeTree(_ req: Request) throws -> Future<Response> {
        return try UserAndTokenController.verifyAccess(req, accessLevel: .timeBilling) { user in
            return try db.getTBTree(req, userId: user.id).flatMap(to:Response.self) { items in
                let treeItems = self.dbItems2TreeItems(items: items)
                let context = TBTreeContext(items: treeItems)
                return try req.view().render("time-tree", context).encode(for: req)
            }
        }
    }
    
    
    // MARK:  Methods connected to routes that return data
    
    private func updateSessionFilters(_ req: Request) throws -> Future<Response> {
        return try UserAndTokenController.verifyAccess(req, accessLevel: .timeBilling) { user in
            // TODO:  save selected info change in the session
            return try "ok".encode(for: req)
        }
    }
    
    // MARK:  Helpers
    
    private func dbItems2TreeItems(items: [TBTreeColumn]) -> [TBTreeItem] {
    /*
        Build the tree.  We want to meet these requirements...
        
        A) If we have one contract, one services for company, and one project, just have one line in the tree.
        B) If we have 1 services for and many projects, put contract and sf on one line, and projects below.
        C) If we have >1 services for and 1 project, put SF & P together under the contract level.
        D) If we have >1 services for and >1 project, need three levels.

    */
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
        
        var treeItems = [TBTreeItem]()
        for contract in contracts {
            let projCount = contractProjectDictionary[contract]!.count
            let sfCount = contractCompanyDictionary[contract]!.count
            
            if projCount == 1 && sfCount == 1 {
                // A
                let row = items.filter { $0.projectId == contractProjectDictionary[contract]!.first }.first!
                let level1 = "\(row.contractDescription) - \(row.projectDescription)"
                let item = TBTreeItem(levels: 1, level1: level1, level2: nil, level3:nil, projectId: row.projectId, contractId: row.contractId)
                treeItems.append(item)
            }
                
            else if projCount > 1 && sfCount == 1 {
                // B
                let rows = items.filter { contractProjectDictionary[contract]!.contains($0.projectId) }
                let level1 = "\(rows.first!.contractDescription) - \(rows.first!.servicesForCompany)"
                for row in rows {
                    var level2: String
                    if let projectNumber = row.projectNumber {
                        level2 = projectNumber.trimmingCharacters(in: .whitespacesAndNewlines)
                        level2 = level2.count > 0 ? "\(level2) - \(row.projectDescription)" : row.projectDescription
                    } else {
                        level2 = row.projectDescription
                    }
                    let item = TBTreeItem(levels: 2, level1: level1, level2: level2, level3: nil, projectId: row.projectId, contractId: row.contractId)
                    treeItems.append(item)
                }
            }
            else if projCount == 1 && sfCount > 1 {
                // C
                let rows = items.filter { contractCompanyDictionary[contract]!.contains($0.servicesForCompany) }
                let level1 = "\(rows.first!.contractDescription)"
                for row in rows {
                    let level2 = "\(row.servicesForCompany) - \(row.projectDescription)"
                    let item = TBTreeItem(levels: 2, level1: level1, level2: level2, level3: nil, projectId: row.projectId, contractId: row.contractId)
                    treeItems.append(item)
                }
            }
            else {
                // D
                let companies = contractCompanyDictionary[contract]!
                for company in companies {
                    let rows = items.filter { $0.servicesForCompany == company && $0.contractId == contract}
                    for row in rows {
                        let item = TBTreeItem(levels: 3, level1: row.contractDescription, level2: company, level3: row.projectDescription, projectId: row.projectId, contractId: row.contractId)
                        treeItems.append(item)
                    }
                    
                }
            }
        }
        return treeItems
    }
}


