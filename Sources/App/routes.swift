import Vapor
import FluentMySQL
import Crypto

/// Register your application's routes here.
public func routes(_ router: Router) throws {
        
    let userAndTokenController = UserAndTokenController()
    try router.register(collection: userAndTokenController)
    
    let cache = DataCache()
    let projectTree = ProjectTree(cache: cache)
    
    try router.register(collection: TimeBillingController(userAndTokenController, projectTree))
    try router.register(collection: ReportController(userAndTokenController, cache: cache))
    try router.register(collection: ProjectController(userAndTokenController, projectTree))
    
    router.get { req-> Future<Response> in
        return try UserAndTokenController.verifyAccess(req, accessLevel: .activeOnly) { user in
            return try req.view().render("index", user.accessDictionary()).encode(for: req)
        }
    }
    

    // test sql connectivity
    struct MySQLVersion: Codable {
        let version: String
    }
    
    router.get("sql") { req in
        return req.withPooledConnection(to: .mysql) { conn in
            return conn.raw("SELECT @@version as version")
                .all(decoding: MySQLVersion.self)
        }.map { rows in
            return rows[0].version
        }
    }

}
