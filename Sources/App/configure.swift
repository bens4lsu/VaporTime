import Fluent
import FluentMySQLDriver
import Vapor
import Leaf

/// Called before your application initializes.
public func configure(_ app: Application) throws {
    
    try routes(app)

    // Load values from Resources/Config.json
    let keys = ConfigKeys()
    
    app.http.server.configuration.port = keys.listenOnPort

    
    // Register database
    app.databases.use(.mysql(
        hostname: keys.database.hostname,
        username: keys.database.username,
        password: keys.database.password,
        database: keys.database.database,
        tlsConfiguration: nil
    ), as: .mysql)
            
    app.views.use(.leaf)
    
    app.leaf.tags["zebra"] = ZebraTag()
    app.leaf.tags["lowercase"] = LowercaseTag()
    
    /// setup public file middleware (for hosting our uploaded files)
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    app.middleware.use(app.sessions.middleware)
    
}
