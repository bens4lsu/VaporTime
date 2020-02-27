//
//  DataCache.swift
//  App
//
//  Created by Ben Schultz on 2/27/20.
//

import Foundation
import Vapor

class DataCache {
    
    var cachedLookupContext: LookupContext?
    var savedTrees: [Int : TBTreeContext] = [:]
    
    public func clear() {
        cachedLookupContext = nil
        savedTrees = [:]
    }
}
