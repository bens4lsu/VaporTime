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
    
    init(_ userAndTokenController: UserAndTokenController) {
        self.userAndTokenController = userAndTokenController
    }
    
    func boot(router: Router) throws {
        router.get("TBTable", use: displayTimeTable)
    }
    
    
    // MARK:  Methods connected to routes that return Views
    
    private func displayTimeTable(_ req: Request) throws -> Future<Response> {
        return try UserAndTokenController.verifyAccess(req) { user in
            
            return try req.view().render("time-table").encode(for: req)
        }
    }

}
