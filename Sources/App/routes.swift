import Vapor
import FluentMySQL
import Crypto

/// Register your application's routes here.
public func routes(_ router: Router) throws {
    
    let userAndTokenController = UserAndTokenController()
    try router.register(collection: userAndTokenController)
    try router.register(collection: TimeBillingController(userAndTokenController))
    

}
