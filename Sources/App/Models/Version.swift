//
//  Version.swift
//  App
//
//  Created by Ben Schultz on 3/6/20.
//

import Foundation
import Vapor

class Version: Codable {
    
    var version: String
    
    init() {
    
        let path = DirectoryConfig.detect().workDir
        let url = URL(fileURLWithPath: path).appendingPathComponent("Resources", isDirectory: true).appendingPathComponent("Version.json")
        do {
            let data = try Data(contentsOf: url)
            let decoder = try JSONDecoder().decode(Version.self, from: data)
            self.version = decoder.version
        }
        catch {
            self.version = "Could not load version from ./Resources/Version.json.  Please check file."
        }
    }
}
