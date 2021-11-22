import App
import Vapor
import XCTVapor
import XCTest

final class AppTests: XCTestCase {
    
    func testRoutes() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)
        
        try app.test(.GET, "sql") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string.prefix(1), "8")
        }
    }

    static let allTests = [
        ("testRoutes", testRoutes)
    ]
}
