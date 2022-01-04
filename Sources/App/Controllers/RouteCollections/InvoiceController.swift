//
//  File.swift
//  
//
//  Created by Ben Schultz on 12/21/21.
//

import Foundation
import Vapor
import FluentMySQLDriver
import Leaf


class InvoiceController: RouteCollection {
    
    let cache: DataCache

    // MARK: Startup
    init(_ cache: DataCache) {
        self.cache = cache
    }
    
    func boot(routes: RoutesBuilder) throws {
        routes.get("InvoiceTree", use: renderInvoiceTree)
    }
    
    private func renderInvoiceTree(req: Request) async throws -> Response {
        return try await "ok".encodeResponse(for: req)
    }
}
