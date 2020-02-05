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
        let sql = "select t.TimeID, c.Description, p.ProjectNumber, p.ProjectDescription, t.WorkDate , t.Duration, t.UseOTRate, t.Notes, t.PreDeliveryFlag, t.ExportStatus, t.ProjectID from fTime t join fProjects p on t.ProjectID = p.ProjectID join fContracts c on p.ContractID = c.ContractID where t.PersonID = \(userId) and ExportStatus = 0 order by t.WorkDate"
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

}

