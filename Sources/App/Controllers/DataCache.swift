//
//  DataCache.swift
//  App
//
//  Created by Ben Schultz on 2/27/20.
//

import Foundation
import Vapor
import Fluent
import FluentMySQLDriver

class DataCache {
    
    private var cachedLookupContext: LookupContext?
    private var savedTrees: [Int : TBTreeContext] = [:]
    private let db = MySQLDirect()
    
    public var configKeys = ConfigKeys()
    
    var smtp: ConfigKeys.Smtp {
        configKeys.smtp
    }
    
    public func clear() {
        cachedLookupContext = nil
        savedTrees = [:]
    }
    
    public func getLookupContext(_ req: Request) async throws -> LookupContext {
        if let context = cachedLookupContext {
            return context
        }
        
        async let lookupTrinitiyTask = try db.getLookupTrinity(req)
        async let lookupPerson = try db.getLookupPerson(req)
        async let projectStatuses = try RefProjectStatuses.query(on: req.db).all()
        async let eventTypes = try db.getEventTypes(req)
        async let rateSchedules = try LuRateSchedules.query(on: req.db).all()
        let statuses = try await projectStatuses.sorted()
        let lookupTrinity = try await lookupTrinitiyTask
        let context = LookupContext(contracts: lookupTrinity.contracts.sorted(),
                                    companies: lookupTrinity.companies.sorted(),
                                    projects:  lookupTrinity.projects.sorted(),
                                    timeBillers: try await lookupPerson.sorted(),
                                    groupBy: ReportGroupBy.list(),
                                    projectStatuses: statuses,
                                    eventTypes: try await eventTypes,
                                    rateSchedules: try await rateSchedules)
        cachedLookupContext = context
        return context
    }
    
    
    public func getProjectTree(_ req: Request, userId: Int) async throws -> TBTreeContext {
        if let tree = self.savedTrees[userId] {
            return tree
        }
        let items = try await db.getTBTree(req, userId: userId)
        let treeItems = convertDbItemsToTreeItems(items: items)
        let tree = TBTreeContext(items: treeItems)
        savedTrees[userId] = tree
        return tree
    }
    
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
                        label = "\(projectNumber.trimmingCharacters(in: .whitespacesAndNewlines)) - \(row.projectDescription)"
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
                        level2 = TBTreeItemBranch(label: "\(level2.label) - \(child.label)", projectId: child.projectId)
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
