//
//  BreakLines.swift
//  App
//
//  Created by Ben Schultz on 4/10/20.
//

import Async
import Foundation
import Leaf

public final class BreakLinesTag: TagRenderer {
    public func render(tag parsed: TagContext) throws -> Future<TemplateData> {
        try parsed.requireParameterCount(1)
        
        return Future.map(on: parsed.container) {
            if let str = parsed.parameters[0].string {
                return .string(str.replacingOccurrences(of: "\r\n", with: "<br>")
                                  .replacingOccurrences(of: "\n", with: "<br>"))
            } else {
                return .null
            }
        }
    }
}
