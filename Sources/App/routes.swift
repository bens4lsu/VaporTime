import Vapor
import FluentMySQL
import Crypto

/// Register your application's routes here.
public func routes(_ router: Router) throws {
    
    // Yuck with this hack.  Right now, there doesn't seem to be a way to tell Vapor that the dates coming back from the database
    // are in my local time zone.  So it assumes Zulu, which is fine, except that we're not storing a time at all, and that gets translated
    // by Vapor to 0:00:00 when it populates the time part in a date variable.  This means that in the US, the dates are off by one day.
    // This is just an issue when selecting dates from the database.  Saves are saving the correct value.
    let ZTimeOffsetInterval = 12
    
    
    let userAndTokenController = UserAndTokenController()
    try router.register(collection: userAndTokenController)
    try router.register(collection: TimeBillingController(userAndTokenController))
    
    router.get { req-> Future<Response> in
        return try UserAndTokenController.verifyAccess(req, accessLevel: .activeOnly) { user in
            return try req.view().render("index", user.accessDictionary()).encode(for: req)
        }
    }

}
