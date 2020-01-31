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
    let databaseConfig = MySQLDatabaseConfig(hostname: "192.168.56.20", port: 3306, username: "devuser", password: "6ZoLeCKL8X86", database: "swiftvapor") //, transport: .unverifiedTLS)
    services.register(databaseConfig)
    
    try services.register(MySQLProvider())
    
    var migrationConfig = MigrationConfig()
    migrationConfig.add(model: User.self, database: .mysql)
    services.register(migrationConfig)
    
    try services.register(LeafProvider())
    config.prefer(LeafRenderer.self, for: ViewRenderer.self)
    
}
