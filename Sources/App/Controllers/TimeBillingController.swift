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
    let projectTree: ProjectTree
    let db = MySQLDirect()
        
    // MARK: Startup
    init(_ userAndTokenController: UserAndTokenController, _ projectTree: ProjectTree) {
        self.userAndTokenController = userAndTokenController
        self.projectTree = projectTree
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
        guard let temp: TimeBillingSessionFilter? = try? UserAndTokenController.getSessionInfo(req: req, sessionKey: "filter"),
            let data = temp
        else {
            return TimeBillingSessionFilter()
        }
        return data
    }
    
    // MARK:  Methods connected to routes that return Views
    
    
    private func renderTimeTable(_ req: Request) throws -> Future<Response> {
        let highlightRow = try? req.query.get(Int.self, at: "highlightRow")
        
        return try UserAndTokenController.verifyAccess(req, accessLevel: .timeBilling) { user in
            
            return try db.getTBTableCOpts(req).flatMap(to: Response.self) { cOpts in
                
                return try self.db.getTBTablePOpts(req).flatMap(to: Response.self) {pOpts in
                    
                    return try self.db.getTBTable(req, userId: user.id).flatMap(to: Response.self) { entries in
                        
                        let context = TBTableContext(entries: entries,
                                                     filter: self.sessionSortOptions(req),
                                                     highlightRow: highlightRow,
                                                     cOpts: cOpts.toJSON(),
                                                     pOpts: pOpts.toJSON())
                        print(self.sessionSortOptions(req))
                        return try req.view().render("time-table", context).encode(for: req)
                    }
                }
            }
        }
    }
    
    
    private func renderTimeTree(_ req: Request) throws -> Future<Response> {
        return try UserAndTokenController.verifyAccess(req, accessLevel: .timeBilling) { user in
            return try projectTree.getTree(req, userId: user.id).flatMap(to:Response.self) { context in
                return (try req.view().render("time-tree", context).encode(for: req))
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
            let sesContract = try? req.content.syncGet(String.self, at: "sesContract").trimmingCharacters(in: .whitespaces)
            
            let sesProject = try? req.content.syncGet(String.self, at: "sesProject").trimmingCharacters(in: .whitespaces)
            
            let sesDateTo = try? req.content.syncGet(String.self, at: "sesDateTo").trimmingCharacters(in: .whitespaces)
            
            let sesDateFrom = try? req.content.syncGet(String.self, at: "sesDateFrom").trimmingCharacters(in: .whitespaces)
            
            let sesDurTo = try? req.content.syncGet(String.self, at: "sesDurTo").trimmingCharacters(in: .whitespaces)
            
            let sesDurFrom = try? req.content.syncGet(String.self, at: "sesDurFrom").trimmingCharacters(in: .whitespaces)
            
            let sesNote = try? req.content.syncGet(String.self, at: "sesNote").trimmingCharacters(in: .whitespaces)
            
            let sortCol = try? req.content.syncGet(Int.self, at: "sortCol")
            
            let sortDir = try? req.content.syncGet(String.self, at: "sortDir").trimmingCharacters(in: .whitespaces)
            
            let filter = TimeBillingSessionFilter(contract: sesContract, project: sesProject, dateFrom: sesDateFrom, dateTo: sesDateTo, durationFrom: sesDurFrom, durationTo: sesDurTo, noteFilter: sesNote, sortColumn: sortCol ?? 3, sortDirection: sortDir ?? "desc")
            
            try UserAndTokenController.saveSessionInfo(req: req, info: filter, sessionKey: "filter")
            print ("Saved to session: \(filter)")
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
        return try UserAndTokenController.verifyAccess(req, accessLevel: .timeBilling) { user in
            let timeId = try? req.content.syncGet(Int.self, at: "timeId")
            guard let time = timeId else {
                return try ["Error" : "request for delete recieved with no id."].encode(for: req)
            }
            return Time.query(on:req).filter(\.id == time).delete().flatMap(to: Response.self) {
                return try ["OK" : "OK"].encode(for: req)
            }
        }
    }
}


