//
//  File.swift
//  
//
//  Created by Ben Schultz on 1/7/22.
//

import Foundation
import Vapor
import FluentMySQLDriver
import Leaf

class AdminController: RouteCollection {
    
    let cache: DataCache

    // MARK: Startup
    init(_ cache: DataCache) {
        self.cache = cache
    }
    
    func boot(routes: RoutesBuilder) throws {
        routes.get("AdminTree", use: renderAdminTree)
    }
    
    // MARK: Rendering Routes
    
    private func renderAdminTree(req: Request) async throws -> Response {
        let luContext = try await cache.getLookupContext(req)
        return try await req.view.render("admin-tree", luContext).encodeResponse(for: req)
    }
}
