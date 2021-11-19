//
//  File.swift
//  
//
//  Created by Ben Schultz on 11/1/21.
//

import Foundation
import Fluent
import Vapor

extension Model {
    
    // saveAndReturn() is just the same as save()
    // but with a Bool return value so I can use
    // async let and have the rest of this code running
    // while the save happens in the background.
    func saveAndReturn<T: Model>(on database: Database) async throws -> T {
        try await self.save(on: database)
        return self as! T
    }
}
