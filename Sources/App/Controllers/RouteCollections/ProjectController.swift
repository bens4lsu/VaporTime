//
//  ProjectController.swift
//  App
//
//  Created by Ben Schultz on 2/14/20.
//

import Foundation
import Vapor
import FluentMySQLDriver
import Leaf

class ProjectController: RouteCollection {
    
    let cache: DataCache
    let db = MySQLDirect()
        
    // MARK: Startup
    init(_ cache: DataCache) {
        self.cache = cache
    }

    func boot(routes: RoutesBuilder) throws {
        routes.get("ProjectTree", use: renderProjectTree)
        routes.get("ProjectAddEdit", use: renderProjectAddEdit)
        routes.post("ProjectAddEdit", use: addEditProject)
        routes.post("ProjectClose", use: closeProject)
        routes.post("ProjectAddJournal", use: addJournal)
        routes.post("ProjectAddRate", use: addRateSchedule)
        
    }
    
    
    // MARK:  Rendering Routes
    
    private func renderProjectTree(_ req: Request) throws -> EventLoopFuture<Response> {
        return try UserAndTokenController.verifyAccess(req, accessLevel: .timeBilling) { user in
            return try self.cache.getProjectTree(req, userId: user.id).flatMap(to:Response.self) { context in
                var updatePage = context
                updatePage.editPage = "ProjectAddEdit"
                updatePage.heading = "Edit Project"
                updatePage.parentWindow = "frPrDetails"
                return try req.view.render("time-tree", updatePage).encode(for: req)
            }
        }
    }
    
    private func renderProjectAddEdit(_ req: Request)throws -> EventLoopFuture<Response> {
        let optProjectId = try? req.query.get(Int.self, at: "projectId")
        
        return try UserAndTokenController.verifyAccess(req, accessLevel: UserAccessLevel.timeBilling) { user in
            
            return try self.cache.getLookupContext(req).flatMap(to:Response.self) { lookup in
                
                guard let projectId = optProjectId else {
                    return try req.view.render("project", ["lookup" : lookup]).encode(for: req)
                }
                
                //update existing project
                return Project.find(projectId, on: req).flatMap(to: Response.self) { project in
                    guard var project = project else {
                        throw Abort(.badRequest, reason: "no project returned based on request with project id \(projectId)")
                    }
                    
                    project.startDate = project.startDate?.asLocal
                    project.projectedDateComplete = project.projectedDateComplete?.asLocal
                    
                    return try self.db.getTimeForProject(req, projectId: projectId).flatMap(to: Response.self) { totalTime in
                        
                        return try self.db.getRatesForProject(req, projectId: projectId).flatMap(to: Response.self) { rateLists in
                            
                            return try self.db.getJournalForProject(req, projectId: projectId).flatMap(to: Response.self) { journals in
                            
                                var strBugID = ""
                                if let bugId = project.mantisProjectId {
                                    strBugID = "\(bugId)"
                                }
                                let bugLink = self.cache.configKeys.bugUrl.replacingOccurrences(of: "#(projectId)", with: strBugID)
                                let context = ProjectAddEdit(lookup: lookup, project: project, totalTime: totalTime, buglink: bugLink, journals: journals, rateLists: rateLists)
                                return try req.view.render("project", context).encode(for: req)
                            }
                        }
                    }
                }
            }
        }
    }
    
    
    // MARK: Updating routes
    
    private func addEditProject(_ req: Request) throws -> EventLoopFuture<Response> {
        
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
            return self.getPreUpdatedProject(projectId, on: req).flatMap(to: Response.self) { oldProject in
            
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
    
    
    private func closeProject(_ req: Request) throws -> EventLoopFuture<Response> {
        let ajaxProjectId = try? req.content.syncGet(Int.self, at: "projectId")
        
        guard let projectId = ajaxProjectId else {
            throw Abort (.badRequest, reason: "Request to close a project without a projectID")
        }
        
        return try UserAndTokenController.verifyAccess(req, accessLevel: .timeBilling) { user in
            
            return Project.find(projectId, on: req).flatMap(to: Response.self) { optionalProject in
                
                guard var project = optionalProject else {
                    return try ("Error:  no project found with id number \(projectId).").encode(for: req)
                }
            
                project.isActive = false
                return project.save(on: req).flatMap(to: Response.self) { _ in
                    self.cache.clear()
                    
                    // now we have to clear associated time billing items
                    return try self.db.markTimeBillingItemsAsSatisfiedForProject(req, projectId: projectId).flatMap(to: Response.self) {
                        return try ("ok").encode(for: req)
                    }
                }
            }
        }
    }
    
    
    private func addJournal(_ req: Request)throws -> EventLoopFuture<Response> {
        let ajaxProjectId = try? req.content.syncGet(Int.self, at: "projectId")
        let journalId = try? req.content.syncGet(Int.self, at: "journalId")
        let eventId = try? req.content.syncGet(Int.self, at: "eventId")
        let ajaxEventDate = (try? req.content.syncGet(at: "eventDate")).toDate()
        let notes = (try? req.content.syncGet(String.self, at: "notes")) ?? ""

        guard let projectId = ajaxProjectId else {
            throw Abort (.badRequest, reason: "Request to close a project without a projectID")
        }
        
        guard let eventDate = ajaxEventDate else {
            throw Abort (.badRequest, reason: "Journal entries require an event date.")
        }
    
        return try UserAndTokenController.verifyAccess(req, accessLevel: .timeBilling) { user in
            
            let entry = ProjectEvent(projectId: projectId, id: journalId, eventId: eventId, eventDate: eventDate, personId: user.id, notes: notes)
         
            return entry.save(on: req).flatMap(to: Response.self) { _ in
                return try req.future("ok").encode(for: req)
            }
        }
    }
    
    
    private func addRateSchedule(_ req: Request)throws -> EventLoopFuture<Response> {
        let ajaxProjectId = try? req.content.syncGet(Int.self, at: "projectId")
        let ajaxPersonId = try? req.content.syncGet(Int.self, at: "personId")
        let ajaxRateScheduleId = try? req.content.syncGet(Int.self, at: "rateScheduleId")
        let rateStartDate = (try? req.content.syncGet(at: "rateStartDate")).toDate()
        let rateEndDate = (try? req.content.syncGet(at: "rateEndDate")).toDate()
        
        guard let projectId = ajaxProjectId, let personId = ajaxPersonId, let rateScheduleId = ajaxRateScheduleId else {
            throw Abort(.badRequest, reason: "Add Rate Schedule requested with at least one required field missing (project ID, person ID, rate schedule ID.")
        }
    
        return try UserAndTokenController.verifyAccess(req, accessLevel: .timeBilling) { user in
            
            return try self.db.addProjectRateSchedule(req, projectId: projectId, personId: personId, rateScheduleId: rateScheduleId, startDate: rateStartDate, endDate: rateEndDate).flatMap(to:Response.self) { _ in
                
                return try req.future("ok").encode(for: req)
            }
        }
    }
    
    
    // MARK:  Helper functions
    
    private func getPreUpdatedProject(_ id: Int?, on req: Request) -> EventLoopFuture<Project?> {
        
        guard let projectId = id else {
            return req.future(nil)
        }
        return Project.find(projectId, on: req).map(to: Project?.self) { foundProject in
            guard var project = foundProject else {
                return nil
            }
            
            project.startDate = project.startDate?.asLocal
            project.projectedDateComplete = project.projectedDateComplete?.asLocal
            return project
        }
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
        if !old.projectedDateComplete.isSameDayAs(new.projectedDateComplete) {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM/dd/yyyy"
            formatter.timeZone = .current
            let oldDateString = old.projectedDateComplete == nil ? "not set" : formatter.string(from: old.projectedDateComplete!)
            let newDateString = new.projectedDateComplete == nil ? "not set" : formatter.string(from: new.projectedDateComplete!)
            let message = "Completion date changed from \(oldDateString) to \(newDateString)."
            let _ = ProjectEvent(projectId: id, eventId: 19, personId: person, notes: message).save(on:req)
            //let _ = ProjectEvent(projectId: id, eventId: 19, personId: person, notes: message).save(on: req)
        }
        
        
        // status changed
        if old.statusId != new.statusId {
            let _ =  try getProjectStatusDescription(forStatus: old.statusId, req: req).flatMap() { oldStatusText -> EventLoopFuture<ProjectEvent> in
                try self.getProjectStatusDescription(forStatus: new.statusId, req: req).flatMap() { newStatusText -> EventLoopFuture<ProjectEvent> in
                    let message = "Status changed from \(oldStatusText) to \(newStatusText)."
                    return ProjectEvent(projectId: id, eventId: 20, personId: person, notes: message).save(on: req)
                }
            }
        }
        
        // status note changed
        if old.statusNotes != new.statusNotes {
            var message = ""
            if old.statusNotes == nil || old.statusNotes == "" {
                message = "Status notes added.  Status notes were previously empty."
            }
            else {
                message = "Status notes updated.  Previous status notes were:  \n\(old.statusNotes!)"
            }
            let _ = ProjectEvent(projectId: id, eventId: 25, personId: person, notes: message).save(on: req)
        }
    }
    
        
    private func futureRedirectResponse(path: String, req: Request) ->  EventLoopFuture<Response> {
        return req.future().map(to: Response.self) {
            return req.redirect(to: path)
        }
    }
    
    private func getProjectStatusDescription(forStatus id: Int?, req: Request) throws -> EventLoopFuture<String> {
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
    
    private func validateNoOverlappingRateSchedules(_ req: Request, contractId: Int, projectId: Int, personId: Int, startDate: Date, endDate: Date) -> EventLoopFuture<Bool> {
        
        // if no record for this contract/project/person, all good.
        // else if record exists for this contract/project/person, one of these must be true (for each record)

        //  1.  it has an endDate, which is < newStartDate
        //  2.  it has a startDate which is > newEndDate
        
        
        // TODO:  complete logic for this method
        return req.future().map(to: Bool.self) {
            return true
        }
    }
}
