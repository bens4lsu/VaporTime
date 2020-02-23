//
//  ConfigKeys.swift
//  App
//
//  Created by Ben Schultz on 2/13/20.
//

import Foundation
import Vapor

class ConfigKeys: Codable {
    
    struct Database: Codable {
        var hostname: String
        var port: Int
        var username: String
        var password: String
        var database: String
    }
    
    var database: ConfigKeys.Database
    var tokenExpDuration: Double
    
    init() {
    
        let path = DirectoryConfig.detect().workDir
        let url = URL(fileURLWithPath: path).appendingPathComponent("Resources", isDirectory: true).appendingPathComponent("Config.json")
        do {
            let data = try Data(contentsOf: url)
            let decoder = try JSONDecoder().decode(Self.self, from: data)
            self.database = decoder.database
            self.tokenExpDuration = decoder.tokenExpDuration
        }
        catch {
            print ("Could not initialize app from Config.json.  Initilizing with hard-coded default values. \n \(error)")
            self.database = Self.Database(hostname: "127.0.0.1", port: 3306, username: "devuser", password: "devpassword", database: "apps_timebill")
            self.tokenExpDuration = 3306
        }
    }
}

