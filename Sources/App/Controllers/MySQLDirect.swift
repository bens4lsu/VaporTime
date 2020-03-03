//
//  MySQLDirect.swift
//  App
//
//  Created by Ben Schultz on 2/3/20.
//

import Foundation
import MySQL
import Vapor

class MySQLDirect {
        
    let dateFormatter: DateFormatter =  {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    private func getResultsRows<T: Decodable>(_ req: Request, query: String, decodeUsing: T.Type) throws -> Future<[T]> {
        return req.withPooledConnection(to: .mysql) { conn in
            return conn.raw(query).all(decoding: T.self)
        }
    }
    
    private func getResultRow<T: Decodable>(_ req: Request, query: String, decodeUsing: T.Type) throws -> Future<T?> {
        return req.withPooledConnection(to: .mysql) { conn in
            return conn.raw(query).first(decoding: T.self)
        }
    }
    
    
    func getTBTable(_ req: Request, userId: Int) throws -> Future<[TBTableColumns]> {
        let sql = """
            SELECT t.TimeID, c.Description, p.ProjectNumber, p.ProjectDescription,
                t.WorkDate, t.Duration,
                t.UseOTRate, t.Notes, t.PreDeliveryFlag, t.ExportStatus, t.ProjectID
            FROM fTime t
                JOIN fProjects p on t.ProjectID = p.ProjectID
                JOIN fContracts c ON p.ContractID = c.ContractID
            WHERE t.PersonID = \(userId) AND ExportStatus = 0 ORDER BY t.WorkDate
        """
        return try getResultsRows(req, query: sql, decodeUsing: TBTableColumns.self)
    }
    
    func getTBTableCOpts(_ req: Request) throws -> Future<[TBTableSelectOpts]> {
        let sql = "select distinct left (Description, 30) AS description from fContracts c join fProjects p on c.ContractID = p.ContractID join fTime t on p.ProjectID = t.ProjectID where t.ExportStatus = 0 order by description"
        return try getResultsRows(req, query: sql, decodeUsing: TBTableSelectOpts.self)
    }
    
    func getTBTablePOpts(_ req: Request) throws -> Future<[TBTableSelectOpts]> {
        let sql = "select distinct left(ProjectDescription, 30) AS description from fProjects p join fTime t on p.ProjectID = t.ProjectID where t.ExportStatus = 0 order by description"
        return try getResultsRows(req, query: sql, decodeUsing: TBTableSelectOpts.self)
    }
    
    func getTBTree(_ req: Request, userId: Int) throws -> Future<[TBTreeColumn]> {
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
        return try getResultsRows(req, query: sql, decodeUsing: TBTreeColumn.self)
    }
    
    func getTBAdd(_ req: Request, projectId: Int) throws -> Future<TBEditProjectLabel?> {
            let sql = """
                SELECT c.Description, co.CompanyName, p.ProjectDescription, p.ProjectNumber, p.ProjectID
                FROM fProjects p
                    JOIN fContracts c ON p.ContractID = c.ContractID
                    JOIN LuCompanies co ON p.ServicesForCompany = co.CompanyID
                WHERE p.ProjectID = \(projectId)
            """
        return try getResultRow(req, query: sql, decodeUsing: TBEditProjectLabel.self)
    }
    
    func getReportData(_ req: Request, filters: ReportFilters, userId: Int) throws -> Future<[ReportData]> {
        var sql = """
            SELECT FirstDayOfWeekMonday + INTERVAL 12 HOUR AS FirstDayOfWeekMonday,
                FirstOfMonth + INTERVAL 12 HOUR AS FirstOfMonth,
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
        return try getResultsRows(req, query: sql, decodeUsing: ReportData.self)
    }
    
    func getLookupTrinity(_ req: Request) throws -> Future<[LookupTrinity]> {
            let sql = """
                SELECT c.Description AS ContractDescription,
                    p.ProjectDescription,
                    pc.CompanyName,
                    p.IsActive,
                    c.ContractID,
                    p.ProjectID,
                    pc.CompanyID
                FROM fProjects p
                    JOIN fContracts c ON p.ContractID = c.ContractID
                    JOIN LuCompanies pc ON p.ServicesForCompany = pc.CompanyID
                WHERE ContractCompleted = 0
            """
        return try getResultsRows(req, query: sql, decodeUsing: LookupTrinity.self)
    }
    
    func getLookupPerson(_ req: Request) throws -> Future<[LookupPerson]> {
        let sql = "SELECT PersonID, `Name` FROM LuPeople WHERE BillsTime = 1"
        return try getResultsRows(req, query: sql, decodeUsing: LookupPerson.self)
    }
    
    func getTimeForProject(_ req: Request, projectId: Int) throws -> Future<Double> {
        let sql = "SELECT SUM(Duration) AS TotalTime FROM fTime WHERE ProjectID = \(projectId)"
        return try getResultRow(req, query: sql, decodeUsing: TotalTime.self).flatMap(to:Double.self) { tt in
            let totalTime = tt?.TotalTime ?? 0.0
            return req.future().map() {
                totalTime
            }
        }
    }
}

