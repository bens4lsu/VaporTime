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
    let projectTree: ProjectTree
    let db = MySQLDirect()
        
    // MARK: Startup
    init(_ userAndTokenController: UserAndTokenController, _ projectTree: ProjectTree) {
        self.userAndTokenController = userAndTokenController
        self.projectTree = projectTree
    }

    func boot(router: Router) throws {
        router.get("ProjectTree", use: renderProjectTree)
        router.get("ProjectAddEdit", use: renderProjectAddEdit)
        router.post("ProjectAddEdit", use: addEditProject)
        
    }
    
    private func renderProjectTree(_ req: Request) throws -> Future<Response> {
        return try UserAndTokenController.verifyAccess(req, accessLevel: .timeBilling) { user in
            return try projectTree.getTree(req, userId: user.id).flatMap(to:Response.self) { context in
                var updatePage = context
                updatePage.editPage = "ProjectAddEdit"
                updatePage.heading = "Edit Project"
                return try req.view().render("time-tree", updatePage).encode(for: req)
            }
        }
    }
    
    private func renderProjectAddEdit(_ req: Request)throws -> Future<Response> {
        try req.future("ok").encode(for: req)
    }
    
    private func addEditProject(_ req: Request) throws -> Future<Response> {
        try req.future("ok").encode(for: req)
    }
}
