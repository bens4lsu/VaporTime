//
//  BreakLines.swift
//  App
//
//  Created by Ben Schultz on 4/10/20.
//

import Vapor
import Foundation
import Leaf

public final class BreakLinesTag: LeafTag {
    public func render(_ parsed: LeafContext) throws -> LeafData {
        try parsed.requireParameterCount(1)
        
        if let str = parsed.parameters[0].string {
            return .string(str.replacingOccurrences(of: "\r\n", with: "<br>")
                              .replacingOccurrences(of: "\n", with: "<br>"))
        } else {
            return .nil(.string)
        }
    }
}
