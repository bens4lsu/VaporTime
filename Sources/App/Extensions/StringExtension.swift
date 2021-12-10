//
//  File.swift
//  
//
//  Created by Ben Schultz on 12/10/21.
//

import Foundation

extension String {
    func replaceLineBreaksHtml() -> String {
        self.replacingOccurrences(of: "\n", with: "<br>")
    }
}
