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
    var user: UserJWTInfo?
    
    init(_ userAndTokenController: UserAndTokenController) {
        self.userAndTokenController = userAndTokenController
    }
    
    func boot(router: Router) throws {
        router.get("TBTable", use: displayTimeTable)
    }
    
    
    private func verifyAccess(_ req: Request, onSuccess: () throws -> Future<Response>) throws -> Future<Response> {
        guard case .valid(let reqUser) = try userAndTokenController.verifyJWT(req) else {
            // authentication from the user token failed
            return req.future().map() {
                return req.redirect(to: "/security/login")
            }
        }
        self.user = reqUser
        return try onSuccess()
    }
    
    
    // MARK:  Methods connected to routes that return Views
    
    private func displayTimeTable(_ req: Request) throws -> Future<Response> {
        return try verifyAccess(req) { 
            return try req.view().render("time-table").encode(for: req)
        }
    }

}
