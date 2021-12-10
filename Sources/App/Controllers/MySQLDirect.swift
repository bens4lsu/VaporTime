//
//  MySQLDirect.swift
//  App
//
//  Created by Ben Schultz on 2/3/20.
//

import Foundation
import SQLKit
import FluentMySQLDriver
import Vapor

class MySQLDirect {
    
        
    let dateFormatter: DateFormatter =  {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    private func quotedDateOrNull(_ dt: Date?) -> String {
        guard let unwrapped = dt else {
            return "NULL"
        }
        return "'\(dateFormatter.string(from: unwrapped))'"
    }
    
    private func getResultsRows<T: Decodable>(_ req: Request, query: String, decodeUsing: T.Type) async throws -> [T] {
        let queryString = SQLQueryString(stringLiteral: query)
        return try await (req.db as! SQLDatabase).raw(queryString).all(decoding: T.self).get()
    }
    
    private func getResultRow<T: Decodable>(_ req: Request, query: String, decodeUsing: T.Type) async throws -> T? {
        let queryString = SQLQueryString(stringLiteral: query)
        return try await (req.db as! SQLDatabase).raw(queryString).first(decoding: T.self).get()
    }
    
    private func issueQuery (_ req: Request, query: String) async throws  {
        let queryString = SQLQueryString(stringLiteral: query)
        let _ = try await(req.db as! SQLDatabase).raw(queryString).all().get()
        return
    }
    
    
    func getTBTable(_ req: Request, userId: Int) async throws -> [TBTableColumns] {
        let sql = """
            SELECT t.TimeID, c.Description, p.ProjectNumber, p.ProjectDescription,
                t.WorkDate, t.Duration,
                t.UseOTRate, t.Notes, t.PreDeliveryFlag, t.ExportStatus, t.ProjectID,
                t.DoNotBillFlag
            FROM fTime t
                JOIN fProjects p on t.ProjectID = p.ProjectID
                JOIN fContracts c ON p.ContractID = c.ContractID
            WHERE t.PersonID = \(userId) AND ExportStatus = 0 ORDER BY t.WorkDate
        """
        
        return try await getResultsRows(req, query: sql, decodeUsing: TBTableColumns.self).map { $0.forGrid() }
    }
    
    func getTBTree(_ req: Request, userId: Int) async throws -> [TBTreeColumn] {
        let sql = """
            SELECT ppp.ContractID,
                ppp.ProjectID,
                c.Description AS ContractDescription,
                cc.CompanyName AS BillToCompany,
                p.ProjectNumber,
                p.ProjectDescription,
                pc.CompanyName AS ServicesForCompany
            FROM vwPersonProjectPermissions ppp
                JOIN fContracts c ON ppp.ContractID = c.ContractID
                JOIN LuCompanies cc ON c.BillToCompany = cc.CompanyID
                JOIN fProjects p ON ppp.ProjectID = p.ProjectID
                JOIN LuCompanies pc ON p.ServicesForCompany = pc.CompanyID
            WHERE c.ContractCompleted = 0
                AND p.IsActive = 1
                AND ppp.PersonID = \(userId)
        """
        return try await getResultsRows(req, query: sql, decodeUsing: TBTreeColumn.self)
    }
    
    func getTBAdd(_ req: Request, projectId: Int) async throws -> TBEditProjectLabel? {
            let sql = """
                SELECT c.Description, co.CompanyName, p.ProjectDescription, p.ProjectNumber, p.ProjectID
                FROM fProjects p
                    JOIN fContracts c ON p.ContractID = c.ContractID
                    JOIN LuCompanies co ON p.ServicesForCompany = co.CompanyID
                WHERE p.ProjectID = \(projectId)
            """
        return try await getResultRow(req, query: sql, decodeUsing: TBEditProjectLabel.self)
    }
    
    func getReportData(_ req: Request, filters: ReportFilters, userId: Int) async throws -> [ReportData] {
        var sql = """
            SELECT FirstDayOfWeekMonday AS FirstDayOfWeekMonday,
                FirstOfMonth AS FirstOfMonth,
                Duration,
                WorkDate,
                c.Description AS ContractDescription,
                p.ProjectDescription,
                pc.CompanyName AS ServicesForCompany,
                pe.`Name` AS BilledByName,
                t.Notes
            FROM fTime t
                JOIN fProjects p ON t.ProjectID = p.ProjectID
                JOIN fContracts c ON p.ContractID = c.ContractID
                JOIN LuCompanies pc ON p.ServicesForCompany = pc.CompanyID
                JOIN apps_tallydb.vwTally366Days v ON t.WorkDate = v.TallyDate
                JOIN LuPeople pe on t.PersonID = pe.PersonID
                LEFT OUTER JOIN vwPersonProjectPermissions ppp ON t.PersonID = ppp.PersonID AND t.ProjectID = ppp.ProjectID
            WHERE WorkDate >= '\(dateFormatter.string(from: filters.startDate))'
                AND WorkDate <= '\(dateFormatter.string(from: filters.endDate))'
                AND (ppp.PersonID IS NOT NULL OR t.PersonID = \(userId))
        """
        if let billedById = filters.billedById {
            sql += " AND t.PersonID = \(billedById)"
        }
        if let contractId = filters.contractId {
            sql += " AND p.ContractID = \(contractId)"
        }
        if let servicesForCompanyId = filters.servicesForCompanyId {
            sql += " AND p.ServicesForCompany = \(servicesForCompanyId)"
        }
        if let projectId = filters.projectId {
            sql += " AND p.ProjectID = \(projectId)"
        }
        return try await getResultsRows(req, query: sql, decodeUsing: ReportData.self).map { $0.toLocal() }
    }
    
    func getLookupTrinity(_ req: Request) async throws -> [LookupTrinity] {
            let sql = """
                SELECT c.Description AS ContractDescription,
                    p.ProjectDescription,
                    pc.CompanyName,
                    p.IsActive,
                    c.ContractID,
                    p.ProjectID,
                    pc.CompanyID
                FROM fContracts c
                    LEFT OUTER JOIN fProjects p ON p.ContractID = c.ContractID
                    JOIN LuCompanies pc ON p.ServicesForCompany = pc.CompanyID
                WHERE ContractCompleted = 0
            """
        return try await getResultsRows(req, query: sql, decodeUsing: LookupTrinity.self)
    }
    
    func getLookupPerson(_ req: Request) async throws -> [LookupPerson] {
        let sql = "SELECT PersonID, `Name` FROM LuPeople WHERE BillsTime = 1"
        return try await getResultsRows(req, query: sql, decodeUsing: LookupPerson.self)
    }
    
    func getTimeForProject(_ req: Request, projectId: Int) async throws -> TotalTime {
        let sql = """
            SELECT SUM(t.Duration) AS TotalTime,
                SUM(t.Duration) / MAX(ProjectedTime) * 100 AS CompletionByTime,
                DATEDIFF(NOW(), MAX(StartDate)) / DATEDIFF(MAX(ProjectedDateComplete), MAX(StartDate)) * 100 AS CompletionByDate
            FROM fTime t
                JOIN fProjects p on t.ProjectID = p.ProjectID
            WHERE t.ProjectID = \(projectId)
            GROUP BY t.ProjectID
        """
        let tt =  try await getResultRow(req, query: sql, decodeUsing: TotalTime.self)
        return TotalTime (
            TotalTime: tt?.TotalTime ?? 0.0,
            CompletionByTime: tt?.CompletionByTime ?? 0.1,
            CompletionByDate: tt?.CompletionByDate ?? 0.1)
        
    }
    
    func getJournalForProject(_ req: Request, projectId: Int) async throws ->  [Journal] {
        let sql = """
            SELECT ev.ReportDate, ev.Notes, r.EventDescription,
                r.EventWhoGenerates, p.Name,
                ev.ProjectEventID AS id
            FROM fProjectEvents ev
                LEFT OUTER JOIN LuPeople p ON ev.PersonID = p.PersonID
                LEFT OUTER JOIN RefProjectEventsReportable r ON ev.EventID = r.EventID
            WHERE ev.ProjectID = \(projectId)
            ORDER BY ev.ReportDate DESC, ev.ProjectEventID DESC
        """
        return try await getResultsRows(req, query: sql, decodeUsing: Journal.self).map {  $0.reportDateToLocal() }
    }
    
    func getRatesForProject(_ req: Request, projectId: Int) async throws -> [RateList] {
        let sql = """
            SELECT pe.Name, rs.RateDescription, r.StartDate, r.EndDate
            FROM fProjects p
                JOIN fProjectRates r ON p.ContractID = r.ContractID AND p.ProjectID = r.ProjectID
                JOIN LuRateSchedules rs On r.RateScheduleID = rs.RateScheduleID
                JOIN LuPeople pe ON r.PersonID = pe.PersonID
            WHERE p.ProjectID = \(projectId)
            ORDER BY pe.Name, r.StartDate
        """
        return try await getResultsRows(req, query: sql, decodeUsing: RateList.self).map { $0.toLocalDates() }
    }
    

    
    func getEventTypes(_ req: Request) async throws -> [LookupContextPair] {
        let sql = """
            SELECT EventID AS id, EventDescription AS name
            FROM RefProjectEventsReportable
            WHERE EventWhoGenerates = 'USER'
            ORDER BY SortOrder
        """
        return try await getResultsRows(req, query: sql, decodeUsing: LookupContextPair.self)
    }
    
    
    // MARK: Methods that modify data
    
    func markTimeBillingItemsAsSatisfiedForProject(_ req: Request, projectId: Int) async throws -> Bool {
        let sql = """
            UPDATE fTime
            SET ExportStatus = 1
            WHERE ProjectID = \(projectId)
        """
        try await issueQuery(req, query: sql)
        return true
    }
    
    func addProjectRateSchedule(_ req: Request, projectId: Int, personId: Int, rateScheduleId: Int, startDate: Date?, endDate: Date?) async throws {
        let startDateString = quotedDateOrNull(startDate)
        let endDateString = quotedDateOrNull(endDate)
        let sql = """
            INSERT fProjectRates (ContractID, ProjectID, PersonID, RateScheduleID, StartDate, EndDate)
            SELECT ContractID, ProjectID, \(personId), \(rateScheduleId), \(startDateString), \(endDateString)
            FROM fProjects
            WHERE ProjectID = \(projectId)
        """
        return try await issueQuery(req, query: sql)
    }
    
    func deleteExpiredAndCompleted(_ req: Request, resetKey: String) async throws -> Bool {
        let sql = """
            DELETE
            FROM fPasswordResetRequests
            WHERE BIN_TO_UUID(ResetRequestKey) = '\(resetKey)'
            OR Expiration < NOW()
        """
        try await issueQuery(req, query: sql)
        return true
    }
}

