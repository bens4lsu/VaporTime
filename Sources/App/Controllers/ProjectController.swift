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
        guard let projectId = try? req.query.get(Int.self, at: "projectId") else {
            throw Abort(.badRequest, reason: "Time edit requested with no projectId.")
        }
        return try UserAndTokenController.verifyAccess(req, accessLevel: UserAccessLevel.timeBilling) { user in
            return try cache.getLookupContext(req).flatMap(to:Response.self) { lookup in
                return Project.find(projectId, on: req).flatMap(to: Response.self) { project in
                    guard let project = project else {
                        throw Abort(.badRequest, reason: "no project returned based on request with project id \(projectId)")
                    }
                    return try self.db.getTimeForProject(req, projectId: projectId).flatMap(to: Response.self) { totalTime in
                        var strBugID = ""
                        if let bugId = project.mantisProjectId {
                            strBugID = "\(bugId)"
                        }
                        let bugLink = self.cache.configKeys.bugUrl.replacingOccurrences(of: "#(projectId)", with: strBugID)
                        let context = ProjectAddEdit(lookup: lookup, project: project, totalTime: totalTime, buglink: bugLink)
                        return try req.view().render("project", context).encode(for: req)
                    }
                }
            }
        }
    }
    
    private func addEditProject(_ req: Request) throws -> Future<Response> {
        let projectId = try? req.content.syncGet(Int.self, at: "projectId")
        let inp_contractId = try? req.content.syncGet(Int.self, at: "contractId")
        let inp_servicesForCompanyId = try? req.content.syncGet(Int.self, at: "companyId")
        let inp_description = (try? req.content.syncGet(String.self, at: "description"))
        let projectNumber = (try? req.content.syncGet(String.self, at: "projectNumber")) ?? ""
        let statusId = try? req.content.syncGet(Int.self, at: "statusId")
        let notes = (try? req.content.syncGet(String.self, at: "notes")) ?? ""
        let mantisId = try? req.content.syncGet(Int.self, at: "mantisId")
        let hideTimeReporting = (try? req.content.syncGet(at: "hideTimeReporting")).toBool()
        let projectedTime = try? req.content.syncGet(Double.self, at: "projectedTime")
        let startDate = (try? req.content.syncGet(at: "startDate")).toDate()
        let endDate = (try? req.content.syncGet(at: "endDate")).toDate()
        
        guard let contractId = inp_contractId, let servicesForCompanyId = inp_servicesForCompanyId, let description = inp_description else {
            throw Abort(.badRequest, reason: "Project add or update entry submitted without at least one required value (contract, services for, description).")
        }
        return try UserAndTokenController.verifyAccess(req, accessLevel: .timeBilling) { user in
            let project = Project(id: projectId, contractId: contractId, companyId: servicesForCompanyId, description: description, statusId: statusId, projectNumber: projectNumber, statusNotes: notes, mantisProjectId: mantisId, isActive: true, projectedTime: projectedTime, projectedDateComplete: endDate, pmProjectId: nil, hideTimeReporting: hideTimeReporting, startDate: startDate)
            return project.save(on: req).map(to: Response.self) { projectRow in
                if let newProjectId = projectRow.id {
                    self.cache.clear()b
                    return req.redirect(to: "ProjectAddEdit?projectId=\(newProjectId)")
                }
                else {
                    throw Abort(.internalServerError, reason: "The update to the project table may have failed.  Check system logs.")
                }
            }
        }
    }
}
