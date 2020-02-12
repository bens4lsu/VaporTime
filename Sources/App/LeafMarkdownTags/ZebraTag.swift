//
//  ZebraTag.swift
//  App
//
//  Created by Ben Schultz on 2/12/20.
//

import Async
import Foundation
import Leaf

public final class ZebraTag: TagRenderer {
    public func render(tag parsed: TagContext) throws -> Future<TemplateData> {
        try parsed.requireParameterCount(1)
        
        return Future.map(on: parsed.container) {
            if let index = parsed.parameters[0].int {
                let zebraVal = index % 2 == 1 ? "odd" : "even"
                return .string(zebraVal)
            } else {
                return .null
            }
        }
    }
}
