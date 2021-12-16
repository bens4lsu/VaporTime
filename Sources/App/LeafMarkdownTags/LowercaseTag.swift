//
//  File.swift
//  
//
//  Created by Ben Schultz on 12/16/21.
//

import Foundation
import Vapor
import Leaf

public final class LowercaseTag: LeafTag {
    public func render(_ parsed: LeafContext) throws -> LeafData {
        try parsed.requireParameterCount(1)
        let text = parsed.parameters[0].string
        return LeafData.string(text?.lowercased())
    }
}
