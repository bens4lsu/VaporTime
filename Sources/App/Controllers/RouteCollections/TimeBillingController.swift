//
//  TimeBillingController.swift
//  App
//
//  Created by Ben Schultz on 1/31/20.
//

import Foundation
import Vapor
import FluentMySQLDriver
import Leaf

class TimeBillingController: RouteCollection {
    
    let cache: DataCache
    let db = MySQLDirect()
        
    // MARK: Startup
    init(_ cache: DataCache) {
        self.cache = cache
    }
    
    func boot(routes: RoutesBuilder) throws {
        routes.get("TBTable", use: renderTimeTable)
        routes.post("ajax/savesession", use: updateSessionFilters)
        routes.get("TBTree", use: renderTimeTree)
        routes.get("TBAddEdit", use: renderTimeAddEdit)
        routes.post("TBAddEdit", use: addEditTimeEntry)
        routes.post("ajax/deleteTimeRecord", use: deleteTimeEntry)
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
    
    
    private func renderTimeTable(_ req: Request) async throws -> Response {
        let highlightRow = try? req.query.get(Int.self, at: "highlightRow")
        
        return try await UserAndTokenController.ifVerifiedDo(req, accessLevel: .timeBilling) { user in
            async let entries = db.getTBTable(req, userId: user.id)
            async let lookup = cache.getLookupContext(req)
            let context = TBTableContext(entries: try await entries,
                                         filter: sessionSortOptions(req),
                                         highlightRow: highlightRow,
                                         lookup: try await lookup)
            return try await req.view.render("time-table", context).encodeResponse(for: req)
        }
    }
    
    
    private func renderTimeTree(_ req: Request) async throws ->  Response {
        return try await UserAndTokenController.ifVerifiedDo(req, accessLevel: .timeBilling) { user in
            let context = try await cache.getProjectTree(req, userId: user.id)
            return try await req.view.render("time-tree", context).encodeResponse(for: req)
        }
    }
    
    private func renderTimeAddEdit(_ req: Request) async throws -> Response {
        guard let projectId = try? req.query.get(Int.self, at: "projectId") else {
            throw Abort(.badRequest, reason: "Time edit requested with no projectId.")
        }
        let timeId = try? req.query.get(Int.self, at: "timeId")
        
        return try await UserAndTokenController.ifVerifiedDo(req, accessLevel: .timeBilling) { _ in
            let project = try await self.db.getTBAdd(req, projectId: projectId)
            guard let project = project else {
                throw Abort(.badRequest, reason: "Database lookup for project returned no records.")
            }
            var context = TBAddEditContext(project: project)
            if let timeId = timeId {
                guard let time = try await Time.find(timeId, on: req.db) else {
                    return try await req.view.render("time-add-edit", context).encodeResponse(for: req)
                }
                time.workDate = time.workDate.addingTimeInterval(12*3600)
                context.time = time
                return try await req.view.render("time-add-edit", context).encodeResponse(for: req)
            } else {
                return try await req.view.render("time-add-edit", context).encodeResponse(for: req)
            }
        }
    }
    
    
    // MARK:  Methods connected to routes that return data or redirect
    
    private func updateSessionFilters(_ req: Request) async throws -> Response {
        return try await UserAndTokenController.ifVerifiedDo(req, accessLevel: .timeBilling) { user in
            let sesContract = try? req.query.get(String.self, at: "sesContract").trimmingCharacters(in: .whitespaces)
            let sesProject = try? req.query.get(String.self, at: "sesProject").trimmingCharacters(in: .whitespaces)
            let sesDateTo = try? req.query.get(String.self, at: "sesDateTo").trimmingCharacters(in: .whitespaces)
            let sesDateFrom = try? req.query.get(String.self, at: "sesDateFrom").trimmingCharacters(in: .whitespaces)
            let sesDurTo = try? req.query.get(String.self, at: "sesDurTo").trimmingCharacters(in: .whitespaces)
            let sesDurFrom = try? req.query.get(String.self, at: "sesDurFrom").trimmingCharacters(in: .whitespaces)
            let sesNote = try? req.query.get(String.self, at: "sesNote").trimmingCharacters(in: .whitespaces)
            let sortCol = try? req.query.get(Int.self, at: "sortCol")
            let sortDir = try? req.query.get(String.self, at: "sortDir").trimmingCharacters(in: .whitespaces)
            let filter = TimeBillingSessionFilter(contract: sesContract, project: sesProject, dateFrom: sesDateFrom, dateTo: sesDateTo, durationFrom: sesDurFrom, durationTo: sesDurTo, noteFilter: sesNote, sortColumn: sortCol ?? 3, sortDirection: sortDir ?? "desc")
            
            try UserAndTokenController.saveSessionInfo(req: req, info: filter, sessionKey: "filter")
            print ("Saved to session: \(filter)")
            return try await ("ok").encodeResponse(for: req)
        }
    }
    
    private func addEditTimeEntry(_ req: Request) async throws -> Response {
        let timeId = try? req.query.get(Int.self, at: "timeId")
        let projectIdOpt = try? req.query.get(Int.self, at: "projectId")
        let workDateOpt = (try? req.query.get(at: "datepicker")).toDate()
        let durationOpt: Double? = try? req.query.get(at: "duration")
        let useOtRate = (try? req.query.get(at: "ot")).toBool()
        let preDelivery = (try? req.query.get(at: "pre")).toBool()
        let notes: String = (try? req.query.get(at: "notes")) ?? ""
        let doNotBill = (try? req.query.get(at: "nobill")).toBool()
    
        guard let projectId = projectIdOpt, let workDate = workDateOpt, let duration = durationOpt else {
            throw Abort(.badRequest, reason: "Time entry submitted without at least one required value (project, date, duration).")
        }
        return try await UserAndTokenController.ifVerifiedDo(req, accessLevel: .timeBilling) { user in
            let time = Time(id: timeId, personId: user.id, projectId: projectId, workDate: workDate, duration: duration, useOTRate: useOtRate, notes: notes, exportStatus: 0, preDeliveryFlag: preDelivery, doNotBillFlag: doNotBill)
            try await time.save(on: req.db)
            var urlAddString = ""
            if time.id != nil {
                // i can't think of how this comes back nil, but I'll stick this line in an if, just in case...
                urlAddString = "?highlightRow=\(time.id!)"
            }
            return req.redirect(to: "TBTable\(urlAddString)")
        }
    }
    
    private func deleteTimeEntry(_ req: Request) async throws -> Response {
        return try await UserAndTokenController.ifVerifiedDo(req, accessLevel: .timeBilling) { user in
            guard let time = try? req.query.get(Int.self, at: "timeId") else {
                throw Abort(.internalServerError, reason: "Attempt to delete time row that is not in the database.")
            }
            try await Time.query(on: req.db).filter(\.$id == time).delete()
            return try await ("[\"OK\" : \"OK\"]").encodeResponse(for: req)
        }
    }
}


