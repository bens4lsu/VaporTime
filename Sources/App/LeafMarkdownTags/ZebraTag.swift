//
//  ZebraTag.swift
//  App
//
//  Created by Ben Schultz on 2/12/20.
//

import Vapor
import Foundation
import Leaf

public final class ZebraTag: LeafTag {
    public func render(_ parsed: LeafContext) throws -> LeafData {
        try parsed.requireParameterCount(1)

        if let index = parsed.parameters[0].int {
            let zebraVal = index % 2 == 1 ? "odd" : "even"
            return LeafData.string(zebraVal)
        } else {
            return .nil(.string)
        }
        
    }
}
