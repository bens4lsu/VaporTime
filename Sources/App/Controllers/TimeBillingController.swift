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
    var user: UserPersistInfo?
    let db: MySQLDirect
    
    init(_ userAndTokenController: UserAndTokenController) {
        self.userAndTokenController = userAndTokenController
        self.db = MySQLDirect(userAndTokenController)
    }
    
    func boot(router: Router) throws {
        router.get("TBTable", use: renderTimeTable)
        router.post("ajax/savesession", use: updateSessionFilters)
    }
    
    
    // MARK:  Methods connected to routes that return Views
    
    private func renderTimeTable(_ req: Request) throws -> Future<Response> {
        return try UserAndTokenController.verifyAccess(req) { user in
            return try db.getTBTable(req, userId: user.id).flatMap(to: Response.self) { rows in
                var context = ["rows" : rows]
                return try req.view().render("time-table", context).encode(for: req)
            }
        }
    }
    
    
    // MARK:  Methods connected to routes that return data
    
    private func updateSessionFilters(_ req: Request) throws -> Future<Response> {
        return try UserAndTokenController.verifyAccess(req) { user in
            // TODO:  save selected info change in the session
            return try "ok".encode(for: req)
        }
    }
}

struct TimeBillingSessionFilters: Codable {
    var contract: Int?
    var project: Int?
    var dateFrom: Date?
    var dateTo: Date?
    var durationFrom: Double?
    var durationTo: Double?
    var noteFilter: String?
    var sortColumn: Int?
    var sortDirection: Int?
}
