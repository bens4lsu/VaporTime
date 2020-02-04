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

}

