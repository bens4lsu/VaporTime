import Fluent
import FluentMySQL
import Vapor
import Leaf

/// Called before your application initializes.
public func configure(_ app: Application) throws {
    // Register providers first
  //FluentMySQL  try services.register(FluentMySQL())

    // Register routes to the router
    let router = EngineRouter.default()
    try routes(router)
    services.register(router, as: Router.self)

    // Load values from Resources/Config.json
    let keys = ConfigKeys()
    let dbKeys = keys.database
    
    // Register database
    try services.register(FluentMySQLProvider())
    let databaseConfig = MySQLDatabaseConfig(hostname: dbKeys.hostname, port: dbKeys.port, username: dbKeys.username, password: dbKeys.password, database: dbKeys.database, transport: .unverifiedTLS)
        
    services.register(databaseConfig)
    // this in lieu of migration, which I don't want this system
    // doing on a legacy database
    User.defaultDatabase = .mysql
    Time.defaultDatabase = .mysql
    Project.defaultDatabase = .mysql
    ProjectEvent.defaultDatabase = .mysql
    RefProjectStatuses.defaultDatabase = .mysql
    LuRateSchedules.defaultDatabase = .mysql
    AccessLog.defaultDatabase = .mysql
    PasswordResetRequest.defaultDatabase = .mysql
    
    
    try services.register(LeafProvider())
    config.prefer(LeafRenderer.self, for: ViewRenderer.self)
    var tags = LeafTagConfig.default()
    tags.use(ZebraTag(), as: "zebra")
    tags.use(Raw(), as: "raw")
    tags.use(BreakLinesTag(), as: "linebreak")
    services.register(tags)
    
    var middlewareConfig = MiddlewareConfig.default()
    middlewareConfig.use(SessionsMiddleware.self)
    middlewareConfig.use(FileMiddleware.self)
    services.register(middlewareConfig)
    config.prefer(MemoryKeyedCache.self, for: KeyedCache.self)
    
}
