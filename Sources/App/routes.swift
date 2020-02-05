import Vapor
import FluentMySQL
import Crypto

/// Register your application's routes here.
public func routes(_ router: Router) throws {
    
    let userAndTokenController = UserAndTokenController()
    try router.register(collection: userAndTokenController)
    try router.register(collection: TimeBillingController(userAndTokenController))
    
    router.get { req-> Future<Response> in
        return try UserAndTokenController.verifyAccess(req, accessLevel: .activeOnly) { user in
            return try req.view().render("index", user.accessDictionary()).encode(for: req)
        }
    }

}
