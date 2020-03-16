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
    
    struct MyCompany: Codable {
        var name: String
        var homePage: String
        var logoFileName: String
        var faviconFileName: String
    }
    
    var database: ConfigKeys.Database
    var tokenExpDuration: Double
    var bugUrl: String
    var myCompany: MyCompany
    var resetKeyExpDuration: Double
    
    init() {
    
        let path = DirectoryConfig.detect().workDir
        let url = URL(fileURLWithPath: path).appendingPathComponent("Resources", isDirectory: true).appendingPathComponent("Config.json")
        do {
            let data = try Data(contentsOf: url)
            let decoder = try JSONDecoder().decode(ConfigKeys.self, from: data)
            self.database = decoder.database
            self.tokenExpDuration = decoder.tokenExpDuration
            self.bugUrl = decoder.bugUrl
            self.myCompany = decoder.myCompany
            self.resetKeyExpDuration = decoder.resetKeyExpDuration
        }
        catch {
            print ("Could not initialize app from Config.json.  Initilizing with hard-coded default values. \n \(error)")
            self.database = ConfigKeys.Database(hostname: "127.0.0.1", port: 3306, username: "devuser", password: "devpassword", database: "apps_timebill")
                //, useCachingSha2Pw: false)
            self.tokenExpDuration = 3306
            self.bugUrl = "#"
            self.myCompany = ConfigKeys.MyCompany(name: "Concord Business Services", homePage: "https://concordbusinessservicesllc.com", logoFileName: "logo.png", faviconFileName: "favicon.png")
            self.resetKeyExpDuration = 3600
        }
    }
}

