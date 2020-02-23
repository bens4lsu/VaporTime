import Vapor
import FluentMySQL
import Crypto

/// Register your application's routes here.
public func routes(_ router: Router) throws {
        
    let userAndTokenController = UserAndTokenController()
    try router.register(collection: userAndTokenController)
    
    let projectTree = ProjectTree()
    try router.register(collection: TimeBillingController(userAndTokenController, projectTree))
    try router.register(collection: ReportController(userAndTokenController))
    try router.register(collection: ProjectController(userAndTokenController, projectTree))
    
    router.get { req-> Future<Response> in
        return try UserAndTokenController.verifyAccess(req, accessLevel: .activeOnly) { user in
            return try req.view().render("index", user.accessDictionary()).encode(for: req)
        }
    }

    router.post("ajax/refreshCaches") { req -> Future<HTTPResponse> in
        let headers: HTTPHeaders = .init()
        let body = HTTPBody(string: "")
        let httpReq = HTTPRequest(
            method: .POST,
            url: URL(string: "/post")!,
            headers: headers,
            body: body)

        let client = HTTPClient.connect(hostname: "./report/refreshCache", on: req)
        return client.flatMap(to: HTTPResponse.self) { client in
            return client.send(httpReq)
        }
        
        // TODO: refresh projectTree.savedTrees
    }

}
