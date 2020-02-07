import FluentMySQL
import Vapor
import Leaf

/// Called before your application initializes.
public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {
    // Register providers first
  //FluentMySQL  try services.register(FluentMySQL())

    // Register routes to the router
    let router = EngineRouter.default()
    try routes(router)
    services.register(router, as: Router.self)

    // Register database
    try services.register(FluentMySQLProvider())
    let databaseConfig = MySQLDatabaseConfig(hostname: "192.168.56.20", port: 3306, username: "devuser", password: "6ZoLeCKL8X86", database: "apps_timebill") //, transport: .unverifiedTLS)
        
    services.register(databaseConfig)
    // this in lieu of migration, which I don't want this system
    // doing on a legacy database
    User.defaultDatabase = .mysql
    Time.defaultDatabase = .mysql
    
    try services.register(LeafProvider())
    config.prefer(LeafRenderer.self, for: ViewRenderer.self)
    /// Leaf add tags
    services.register { container -> LeafTagConfig in
        var config = LeafTagConfig.default()
        config.use(Raw(), as: "raw")   // #raw(<myVar>) to print it as raw html in leaf vars
        return config
    }
    
    var middlewareConfig = MiddlewareConfig.default()
    middlewareConfig.use(SessionsMiddleware.self)
    middlewareConfig.use(FileMiddleware.self)
    services.register(middlewareConfig)
    config.prefer(MemoryKeyedCache.self, for: KeyedCache.self)
    
}
