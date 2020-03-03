//
//  ProjectController.swift
//  App
//
//  Created by Ben Schultz on 2/14/20.
//

import Foundation
import Vapor
import FluentMySQL
import Leaf

class ProjectController: RouteCollection {
    let userAndTokenController: UserAndTokenController
    let cache: DataCache
    let db = MySQLDirect()
        
    // MARK: Startup
    init(_ userAndTokenController: UserAndTokenController, _ cache: DataCache) {
        self.userAndTokenController = userAndTokenController
        self.cache = cache
    }

    func boot(router: Router) throws {
        router.get("ProjectTree", use: renderProjectTree)
        router.get("ProjectAddEdit", use: renderProjectAddEdit)
        router.post("ProjectAddEdit", use: addEditProject)
        
    }
    
    private func renderProjectTree(_ req: Request) throws -> Future<Response> {
        return try UserAndTokenController.verifyAccess(req, accessLevel: .timeBilling) { user in
            return try cache.getProjectTree(req, userId: user.id).flatMap(to:Response.self) { context in
                var updatePage = context
                updatePage.editPage = "ProjectAddEdit"
                updatePage.heading = "Edit Project"
                return try req.view().render("time-tree", updatePage).encode(for: req)
            }
        }
    }
    
    private func renderProjectAddEdit(_ req: Request)throws -> Future<Response> {
        return try UserAndTokenController.verifyAccess(req, accessLevel: UserAccessLevel.timeBilling) { user in
            let context = [String:String]()
            return try req.view().render("project", context).encode(for: req)
        }
    }
    
    private func addEditProject(_ req: Request) throws -> Future<Response> {
        return try req.future("ok").encode(for: req)
    }
}
