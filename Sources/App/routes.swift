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
    
    app.get { req throws -> EventLoopFuture<Response> in
        
        struct IndexContext: Encodable, ResponseEncodable, Content {
            func encodeResponse(for request: Request) -> EventLoopFuture<Response> {
                let response = Response(status: HTTPResponseStatus(statusCode: 200))
                
                // TODO:  get rid of !
                try! response.content.encode(self)
                return request.eventLoop.future(response)
            }
            
            var version: String
            var accessDictionary: [String: Bool]
        }
        
        return try UserAndTokenController.verifyAccess(req, accessLevel: .activeOnly) { user in
            let version = Version().version
            let accessDictionary = user.accessDictionary()
            let context = IndexContext(version: version, accessDictionary: accessDictionary)
            return req.view.render("index", context).encodeResponse(for: req)
        }
    }
    

    // test sql connectivity
    struct MySQLVersion: Decodable {
        let version: String
    }
        
    app.get("sql") { req -> EventLoopFuture<String> in
        let queryString = SQLQueryString(stringLiteral: "SELECT @@version as version")
        return (req.db as! SQLDatabase).raw(queryString).first(decoding: MySQLVersion.self).map { mySqlVersion in
            return mySqlVersion?.version ?? "error retrieving mysql version"
        }
    }
    
    
    app.get("blankpage") { req in
        return req.eventLoop.makeSucceededFuture("")
    }
    
    
    app.get("clearcache") { req in
        return req.eventLoop.makeSucceededFuture(cache.clear()).map() {
            return req.eventLoop.makeSucceededFuture("Caches Cleard.")
        }
    }

}
