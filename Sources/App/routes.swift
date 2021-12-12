import Vapor
import FluentMySQLDriver
import Crypto
import SQLKit

/// Register your application's routes here.
public func routes(_ app: Application) throws {
        
    // establish data cache and read info from config.json
    let cache = DataCache()
    
    // route collections
    let userAndTokenController = UserAndTokenController(cache)
    try app.register(collection: userAndTokenController)
    try app.register(collection: TimeBillingController(cache))
    try app.register(collection: ReportController(cache))
    try app.register(collection: ProjectController(cache))
    
    
    // MARK:  Miscellaneous Routes
    
    app.get { req async throws -> Response in
        
        struct IndexContext: Encodable, ResponseEncodable, Content {
            var version: String
            var accessDictionary: [String: Bool]
        }
        
        return try await UserAndTokenController.ifVerifiedDo(req, accessLevel: .activeOnly) { user in
            let version = Version().version
            let accessDictionary = user.accessDictionary()
            let context = IndexContext(version: version, accessDictionary: accessDictionary)
            return try await req.view.render("index", context).encodeResponse(for: req)
        }
    }
    
    app.get("blankpage") { req async throws in
        ("")
    }
    
    // MARK: Routes for developer
   
    // test sql connectivity
    app.get("sql") { req async throws -> String in
        struct MySQLVersion: Decodable {
            let version: String
        }
        
        let queryString = SQLQueryString(stringLiteral: "SELECT @@version as version")
        let mySqlVersion = try await (req.db as! SQLDatabase).raw(queryString).first(decoding: MySQLVersion.self).get()
        return mySqlVersion?.version ?? "error retrieving mysql version"
    }
    
    
    app.get("clearcache") { req async throws -> String in
        cache.clear()
        return "Caches Cleard."
    }
    
    #if DEBUG
    app.get("testEmail") { req async throws -> String in
        let concordMail = ConcordMail(configKeys: ConfigKeys())
        let mailResult = try await concordMail.testMail()
        switch mailResult {
        case .success:
            return ("Test mail send success")
        case .failure(let error):
            return ("Test mail send error: \(error)")
        }
    }
    
    #endif

}
