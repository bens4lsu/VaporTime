import Vapor
import FluentMySQL
import Crypto

/// Register your application's routes here.
public func routes(_ router: Router) throws {
        
    // establish data cache and read info from config.json
    let cache = DataCache()
    UserAndTokenController.tokenExpDuration = cache.configKeys.tokenExpDuration
    UserAndTokenController.resetKeyExpDuration = cache.configKeys.resetKeyExpDuration
    
    // route collections
    let userAndTokenController = UserAndTokenController()
    try router.register(collection: userAndTokenController)
    try router.register(collection: TimeBillingController(cache))
    try router.register(collection: ReportController(cache))
    try router.register(collection: ProjectController(cache))
    
    
    // MARK:  Miscellaneous Routes
    
    router.get { req-> Future<Response> in
        return try UserAndTokenController.verifyAccess(req, accessLevel: .activeOnly) { user in
            
            struct IndexContext: Codable {
                var version: String
                var accessDictionary: [String: Bool]
            }
            
            let version = Version().version
            let accessDictionary = user.accessDictionary()
            let context = IndexContext(version: version, accessDictionary: accessDictionary)
            
            return try req.view().render("index", context).encode(for: req)
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
    
    
    router.get("blankpage") { req in
        return try req.future("").encode(for: req)
    }
    
    
    router.get("clearcache") {req in
        return req.future(cache.clear()).map() {
            return try req.future("Caches Cleard.").encode(for: req)
        }
    }

}
