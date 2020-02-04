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
    
    
    // MARK:  Methods connected to routes that return data
    
    private func updateSessionFilters(_ req: Request) throws -> Future<Response> {
        return try UserAndTokenController.verifyAccess(req, accessLevel: .timeBilling) { user in
            // TODO:  save selected info change in the session
            return try "ok".encode(for: req)
        }
    }
}


