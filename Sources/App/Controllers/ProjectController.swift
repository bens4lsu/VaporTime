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
        let optProjectId = try? req.query.get(Int.self, at: "projectId")
        
        return try UserAndTokenController.verifyAccess(req, accessLevel: UserAccessLevel.timeBilling) { user in
            
            return try cache.getLookupContext(req).flatMap(to:Response.self) { lookup in
                
                guard let projectId = optProjectId else {
                    return try req.view().render("project", ["lookup" : lookup]).encode(for: req)
                }
                
                //update existing project
                return Project.find(projectId, on: req).flatMap(to: Response.self) { project in
                    guard let project = project else {
                        throw Abort(.badRequest, reason: "no project returned based on request with project id \(projectId)")
                    }
                    return try self.db.getTimeForProject(req, projectId: projectId).flatMap(to: Response.self) { totalTime in
                        
                        return try self.db.getJournalForProject(req, projectId: projectId).flatMap(to: Response.self) { journals in
                            
                            var strBugID = ""
                            if let bugId = project.mantisProjectId {
                                strBugID = "\(bugId)"
                            }
                            let bugLink = self.cache.configKeys.bugUrl.replacingOccurrences(of: "#(projectId)", with: strBugID)
                            let context = ProjectAddEdit(lookup: lookup, project: project, totalTime: totalTime, buglink: bugLink, journals: journals)
                            return try req.view().render("project", context).encode(for: req)
                        }
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
        
        let isNewProject = projectId == nil
        
        guard let contractId = inp_contractId, let servicesForCompanyId = inp_servicesForCompanyId, let description = inp_description else {
            throw Abort(.badRequest, reason: "Project add or update entry submitted without at least one required value (contract, services for, description).")
        }
        
        return try UserAndTokenController.verifyAccess(req, accessLevel: .timeBilling) { user in
            return getPreUpdatedProject(projectId, on: req).flatMap(to: Response.self) { oldProject in
            
                let project = Project(id: projectId, contractId: contractId, companyId: servicesForCompanyId, description: description, statusId: statusId, projectNumber: projectNumber, statusNotes: notes, mantisProjectId: mantisId, isActive: true, projectedTime: projectedTime, projectedDateComplete: endDate, pmProjectId: nil, hideTimeReporting: hideTimeReporting, startDate: startDate)
                
                return project.save(on: req).flatMap(to: Response.self) { projectRow in
                    
                    guard let newProjectId = projectRow.id else {
                        throw Abort(.internalServerError, reason: "The update to the project table may have failed.  Check system logs.")
                    }
                        
                    // we're going to clear the cache on any update.  The description might have changed.
                    self.cache.clear()
                    
                    // for new projects add the system event to the journal and return the project page
                    if isNewProject {
                        let projectEvent = ProjectEvent(projectId: newProjectId, eventId: 21, personId: user.id)
                        return projectEvent.save(on: req).flatMap(to: Response.self) { event in
                            return self.futureRedirectResponse(path: "ProjectAddEdit?projectId=\(newProjectId)", req: req)
                        }
                    }
                        
                    // for existing projects, have to check for changes and add journal entries where they belong
                    else {
                        try self.addProjectJournalUpdateEntries(oldProject: oldProject, project: projectRow, req: req, person: user.id)
                        return self.futureRedirectResponse(path: "ProjectAddEdit?projectId=\(newProjectId)", req: req)
                    }
                }
            }
        }
    }
    
    private func getPreUpdatedProject(_ id: Int?, on req: Request) -> Future<Project?> {
        
        guard let projectId = id else {
            return req.future(nil)
        }
        
        return Project.find(projectId, on: req)
    }
    
    private func addProjectJournalUpdateEntries(oldProject: Project?, project new: Project, req: Request, person: Int) throws {
        guard let old = oldProject, let id = new.id else {
            return
        }
                
        // projected time changed
        if old.projectedTime != new.projectedTime {
            let oldTimeString = old.projectedTime == nil ? "not set" : String(old.projectedTime!)
            let newTimeString = new.projectedTime == nil ? "not set" : String(new.projectedTime!)
            let message = "Estimate changed from \(oldTimeString) to \(newTimeString) hours."
            let _ = ProjectEvent(projectId: id, eventId: 18, personId: person, notes: message).save(on: req)
        }
        
        
        
        // projected date changed
        if let oldDate = old.projectedDateComplete,
            let newDate = new.projectedDateComplete,
            let oldDatePartOnly = Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: oldDate),
            let newDatePartOnly = Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: newDate)
        
        {
            if (old.projectedDateComplete == nil && new.projectedDateComplete != nil) ||
                (old.projectedDateComplete != nil && new.projectedDateComplete == nil) ||
                oldDatePartOnly != newDatePartOnly
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "MM/dd/yyyy"
                formatter.timeZone = .current
                let oldDateString = old.projectedDateComplete == nil ? "not set" : formatter.string(from: old.projectedDateComplete!)
                let newDateString = new.projectedDateComplete == nil ? "not set" : formatter.string(from: new.projectedDateComplete!)
                let message = "Completion date changed from \(oldDateString) to \(newDateString)."
                let _ = ProjectEvent(projectId: id, eventId: 19, personId: person, notes: message).save(on:req)
                //let _ = ProjectEvent(projectId: id, eventId: 19, personId: person, notes: message).save(on: req)
            }
        }
        
        // status changed
        if old.statusId != new.statusId {
            let _ =  try getProjectStatusDescription(forStatus: old.statusId, req: req).flatMap() { oldStatusText -> Future<ProjectEvent> in
                try self.getProjectStatusDescription(forStatus: new.statusId, req: req).flatMap() { newStatusText -> Future<ProjectEvent> in
                    let message = "Status changed from \(oldStatusText) to \(newStatusText)."
                    return ProjectEvent(projectId: id, eventId: 20, personId: person, notes: message).save(on: req)
                }
            }
        }
        
        // status note changed
        if old.statusNotes != new.statusNotes {
            var message = ""
            if old.statusNotes == nil || old.statusNotes == "" {
                message = "Status notes added.  Status notes were previuosly empty."
            }
            else {
                message = "Status notes updated.  Previous status notes were:  \(old.statusNotes!)"
            }
            let _ = ProjectEvent(projectId: id, eventId: 25, personId: person, notes: message).save(on: req)
        }
    }
        
    private func futureRedirectResponse(path: String, req: Request) -> Future<Response> {
        return req.future().map(to: Response.self) {
            return req.redirect(to: path)
        }
    }
    
    private func getProjectStatusDescription(forStatus id: Int?, req: Request) throws -> Future<String> {
        guard let _ = id else {
            return req.future("not set")
        }
        
        return try self.cache.getLookupContext(req).flatMap(to: String.self) { lookup in
            let ourStatus = lookup.projectStatuses.filter {
                $0.id == id
            }.first
            
            guard let ourStatusUnwrapped = ourStatus else {
                return req.future("not set")
            }
            
            return req.future(ourStatusUnwrapped.description)
        }
    }
}
