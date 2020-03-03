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
                updatePage.parentWindow = "frPrDetails"
                return try req.view().render("time-tree", updatePage).encode(for: req)
            }
        }
    }
    
    private func renderProjectAddEdit(_ req: Request)throws -> Future<Response> {
        let projectId = 222
        return try UserAndTokenController.verifyAccess(req, accessLevel: UserAccessLevel.timeBilling) { user in
            return try cache.getLookupContext(req).flatMap(to:Response.self) { lookup in
                return Project.find(projectId, on: req).flatMap(to: Response.self) { project in
                    guard let project = project else {
                        throw Abort(.badRequest, reason: "no project returned based on request with project id \(projectId)")
                    }
                    return try self.db.getTimeForProject(req, projectId: projectId).flatMap(to: Response.self) { totalTime in
                        let context = ProjectAddEdit(lookup: lookup, project: project, totalTime: totalTime)
                        return try req.view().render("project", context).encode(for: req)
                    }
                }
            }
        }
    }
    
    private func addEditProject(_ req: Request) throws -> Future<Response> {
        return try req.future("ok").encode(for: req)
    }
}
