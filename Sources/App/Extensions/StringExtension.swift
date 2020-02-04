//
//  StringExtension.swift
//  App
//
//  Created by Ben Schultz on 2/4/20.
//

import Foundation

extension String {

    public func replaceHTML() -> String {
        let charactersToReplace =
            ["&nbsp;" : "",
             "&quot;" : "\"",
             "&apos;" : "'",
             "&lt;" : "<",
             "&gt;" : ">"]
        var str = self
        for (html, plaintext) in charactersToReplace {
            str = str.replacingOccurrences(of: html, with: plaintext)
        }
        return str
    }
}
