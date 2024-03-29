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

//enum ProjectNonFatalError: Codable {
//    // associated value is for the project id that has an error
//    case projectDescriptionMissing
//    case overlappingRateSchedules
//
//    var message: String {
//        switch self {
//        case .projectDescriptionMissing:
//            return "Project Description can not be empty.  Change was not saved."
//        case .overlappingRateSchedules:
//            return "Overlapping Rate Schedules are not allowed.  Change was not saved."
//        }
//    }
//}


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
    
    private func renderProjectTree(_ req: Request) async throws -> Response {
        return try await UserAndTokenController.ifVerifiedDo(req, accessLevel: .timeBilling) { user in
            let context = try await cache.getProjectTree(req, userId: user.id)
            var updatePage = context
            updatePage.editPage = "ProjectAddEdit"
            updatePage.heading = "Edit Project"
            updatePage.parentWindow = "frPrDetails"
            return try await req.view.render("time-tree", updatePage).encodeResponse(for: req)
        }

    }
    
    private func renderProjectAddEdit(_ req: Request) async throws -> Response {
        let optProjectId = try? req.query.get(Int.self, at: "projectId")
        
        return try await UserAndTokenController.ifVerifiedDo(req, accessLevel: .timeBilling) { user in
            async let lookupTask = cache.getLookupContext(req)
            
            guard let projectId = optProjectId else {
                return try await req.view.render("project", ["lookup" : try await lookupTask]).encodeResponse(for: req)
            }
            
            guard let project = try await Project.find(projectId, on: req.db) else {
                throw Abort(.badRequest, reason: "no project returned based on request with project id \(projectId)")
            }

            project.startDate = project.startDate?.asLocal
            project.projectedDateComplete = project.projectedDateComplete?.asLocal
            async let totalTimeTask = db.getTimeForProject(req, projectId: projectId)
            async let rateListsTask = db.getRatesForProject(req, projectId: projectId)
            async let journalsTask = db.getJournalForProject(req, projectId: projectId)
            var strBugID = ""
            if let bugId = project.mantisProjectId {
                strBugID = "\(bugId)"
            }
            let bugLink = cache.configKeys.bugUrl.replacingOccurrences(of: "#(projectId)", with: strBugID)
            print (try await rateListsTask)
            let context = ProjectAddEdit(lookup: try await lookupTask,
                                         project: project,
                                         totalTime: try await totalTimeTask,
                                         buglink: bugLink,
                                         journals: try await journalsTask,
                                         rateLists: try await rateListsTask
            //                             errorMessage: nonFatalError?.message
            )
            return try await req.view.render("project", context).encodeResponse(for: req)
        }
    }
    
    
    // MARK: Updating routes
    
    private func addEditProject(_ req: Request) async throws -> Response {
        struct PostVars: Content {
            var projectId: String?
            var contractId: String?
            var companyId: String?
            var description: String?
            var projectNumber: String?
            var statusId: String?
            var notes: String?
            var mantisId: String?
            var hideTimeReporting: String?
            var projectedTime: String?
            var startDate: String?
            var endDate: String?
        }
        let pv = try req.content.decode(PostVars.self)
        
        guard let contractId = pv.contractId.toInt(), let servicesForCompanyId = pv.companyId.toInt(), let description = pv.description else {
            throw Abort(.badRequest, reason: "Project add or update entry submitted without at least one required value (contract, services for, description).")
        }
        
        let projectId = pv.projectId.toInt()
        let projectNumber = pv.projectNumber
        let statusId = pv.statusId.toInt()
        let notes = pv.notes ?? ""
        let mantisId = pv.mantisId.toInt()
        let hideTimeReporting = pv.hideTimeReporting.toBool()
        let projectedTime = pv.projectedTime.toInt()
        let startDate = pv.startDate.toDate()
        let endDate = pv.endDate.toDate()
        
        let isNewProject = projectId == nil

        return try await UserAndTokenController.ifVerifiedDo(req, accessLevel: .timeBilling) { user in
                        
            guard description.trimmingCharacters(in: .whitespaces) != "" else {
                throw Abort(.internalServerError, reason: "The project description can not be empty.")
            }
            
            async let oldProject = getPreUpdatedProject(projectId, on: req)
            let project = Project(id: projectId, contractId: contractId, companyId: servicesForCompanyId, description: description, statusId: statusId, projectNumber: projectNumber, statusNotes: notes, mantisProjectId: mantisId, isActive: true, projectedTime: projectedTime, projectedDateComplete: endDate, pmProjectId: nil, hideTimeReporting: hideTimeReporting, startDate: startDate)
            try await project.save(on: req.db)
            
            guard let newProjectId: Int = project.id else {
                throw Abort(.internalServerError, reason: "The update to the project table may have failed.  Check system logs.")
            }
            
            cache.clear()
            if isNewProject {
                let projectEvent = ProjectEvent(projectId: newProjectId, eventId: 21, personId: user.id)
                try await projectEvent.save(on: req.db)
                return req.redirect(to: "ProjectAddEdit?projectId=\(newProjectId)")
            }
            else {
                try await addProjectJournalUpdateEntries(oldProject: oldProject, project: project, req: req, person: user.id)
                return req.redirect(to: "ProjectAddEdit?projectId=\(newProjectId)")
            }
        }
    }
    
    
    private func closeProject(_ req: Request) async throws -> Response {
        struct PostVars: Content {
            var projectId: String?
        }
        let pv = try req.content.decode(PostVars.self)
        
        guard let projectId = pv.projectId.toInt() else {
            throw Abort (.badRequest, reason: "Request to close a project without a projectID")
        }
        
        return try await UserAndTokenController.ifVerifiedDo(req, accessLevel: .timeBilling) { user in
            let optionalProject = try await Project.find(projectId, on: req.db)
                
            guard let project = optionalProject else {
                return try await ("Error:  no project found with id number \(projectId).").encodeResponse(for: req)
            }
            
            project.isActive = false
            async let savedProject: Project = project.saveAndReturn(on: req.db)
            self.cache.clear()
                    
            // now we have to clear associated time billing items
            async let tbMarker = db.markTimeBillingItemsAsSatisfiedForProject(req, projectId: projectId)
            let _ = try await savedProject
            let _ = try await tbMarker
            return try await ("ok").encodeResponse(for: req)
        }
    }
    
    
    private func addJournal(_ req: Request) async throws -> Response {
        struct PostVars: Content {
            var projectId: String?
            var journalId: String?
            var eventId: String?
            var eventDate: String?
            var notes: String?
        }
        let pv = try req.content.decode(PostVars.self)

        let journalId = pv.journalId.toInt()
        let eventId = pv.eventId.toInt()
        let ajaxEventDate = pv.eventDate.toDate()
        let notes = pv.notes ?? ""

        guard let projectId = pv.projectId.toInt() else {
            throw Abort (.badRequest, reason: "Request to close a project without a projectID")
        }
        
        guard let eventDate = ajaxEventDate else {
            throw Abort (.badRequest, reason: "Journal entries require an event date.")
        }
    
        return try await UserAndTokenController.ifVerifiedDo(req, accessLevel: .timeBilling) { user in
            let entry = ProjectEvent(projectId: projectId, id: journalId, eventId: eventId, eventDate: eventDate, personId: user.id, notes: notes)
            try await entry.save(on: req.db)
            return try await ("ok").encodeResponse(for: req)
        }
    }
    
    
    private func addRateSchedule(_ req: Request) async throws -> Response {
        struct PostVars: Content {
            var projectId: String?
            var personId: String?
            var rateScheduleId: String?
            var rateStartDate: String?
            var rateEndDate: String?
        }
        let pv = try req.content.decode(PostVars.self)

        guard let projectId = pv.projectId.toInt(), let personId = pv.projectId.toInt(), let rateScheduleId = pv.rateScheduleId.toInt() else {
            throw Abort(.badRequest, reason: "Add Rate Schedule requested with at least one required field missing (project ID, person ID, rate schedule ID.")
        }
        
        let rateStartDate = pv.rateStartDate.toDate()
        let rateEndDate = pv.rateEndDate.toDate()
    
        //TODO: ("bms  - call function to verify no overlap")
        return try await UserAndTokenController.ifVerifiedDo(req, accessLevel: .timeBilling) { user in
            try await db.addProjectRateSchedule(req, projectId: projectId, personId: personId, rateScheduleId: rateScheduleId, startDate: rateStartDate, endDate: rateEndDate)
            return try await ("ok").encodeResponse(for: req)
        }
    }
    
    
    // MARK:  Helper functions
    
    private func getPreUpdatedProject(_ id: Int?, on req: Request) async -> Project? {
        
        guard let projectId = id else {
            return nil
        }
        
        guard let project = try? await Project.find(projectId, on: req.db) else {
            return nil
        }
            
        project.startDate = project.startDate?.asLocal
        project.projectedDateComplete = project.projectedDateComplete?.asLocal
        return project
    }
    
    private func addProjectJournalUpdateEntries(oldProject: Project?, project new: Project, req: Request, person: Int) async throws {
        guard let old = oldProject, let id = new.id else {
            return
        }
        
        try await withThrowingTaskGroup(of: ProjectEvent.self) { group in
        
            // projected time changed
            if old.projectedTime != new.projectedTime {
                let oldTimeString = old.projectedTime == nil ? "not set" : String(old.projectedTime!)
                let newTimeString = new.projectedTime == nil ? "not set" : String(new.projectedTime!)
                let message = "Estimate changed from \(oldTimeString) to \(newTimeString) hours."
                group.addTask{
                    return try await ProjectEvent(projectId: id, eventId: 18, personId: person, notes: message).saveAndReturn(on: req.db)
                }
            }
        
            // projected date changed
            if !old.projectedDateComplete.isSameDayAs(new.projectedDateComplete) {
                let formatter = DateFormatter()
                formatter.dateFormat = "MM/dd/yyyy"
                formatter.timeZone = .current
                let oldDateString = old.projectedDateComplete == nil ? "not set" : formatter.string(from: old.projectedDateComplete!)
                let newDateString = new.projectedDateComplete == nil ? "not set" : formatter.string(from: new.projectedDateComplete!)
                let message = "Completion date changed from \(oldDateString) to \(newDateString)."
                group.addTask {
                    return try await ProjectEvent(projectId: id, eventId: 19, personId: person, notes: message).saveAndReturn(on:req.db)
                }
            }
            
            // status changed
            if old.statusId != new.statusId {
                async let oldStatusText = getProjectStatusDescription(forStatus: old.statusId, req: req)
                async let newStatusText = getProjectStatusDescription(forStatus: new.statusId, req: req)
                let message = "Status changed from \(try await oldStatusText) to \(try await newStatusText)."
                group.addTask {
                    return try await ProjectEvent(projectId: id, eventId: 20, personId: person, notes: message).saveAndReturn(on: req.db)
                }
            }
            
            // status note changed
            if old.statusNotes != new.statusNotes {
                group.addTask {
                    var message = ""
                    if old.statusNotes == nil || old.statusNotes == "" {
                        message = "Status notes added.  Status notes were previously empty."
                    }
                    else {
                        message = "Status notes updated.  Previous status notes were:  \n\(old.statusNotes!)"
                    }
                    return try await ProjectEvent(projectId: id, eventId: 25, personId: person, notes: message).saveAndReturn(on: req.db)
                }
            }
        }
    }
    
    private func getProjectStatusDescription(forStatus id: Int?, req: Request) async throws -> String {
        guard let _ = id else {
            return "not set"
        }
        
        let lookup = try await cache.getLookupContext(req)
        let ourStatus = lookup.projectStatuses.filter {
            $0.id == id
        }.first
            
        guard let ourStatusUnwrapped = ourStatus else {
            return "not set"
        }
            
        return ourStatusUnwrapped.statusDescription
    }
    
    private func validateNoOverlappingRateSchedules(_ req: Request, contractId: Int, projectId: Int, personId: Int, startDate: Date, endDate: Date) -> Bool {
        
        // if no record for this contract/project/person, all good.
        // else if record exists for this contract/project/person, one of these must be true (for each record)

        //  1.  it has an endDate, which is < newStartDate
        //  2.  it has a startDate which is > newEndDate
        //  3.  it has no endDate, in which case we have to set its endDate to one day before the new record's
        //      start date
        
        
        //TODO:  ("bms - complete logic for this method")
        return true
    }
}
