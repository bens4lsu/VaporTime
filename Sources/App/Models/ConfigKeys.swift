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
    
    
    struct Smtp: Codable {
        var hostname: String
        var port: Int32
        var username: String
        var password: String
        var timeout: UInt
    }
    
    var database: ConfigKeys.Database
    var listenOnPort: Int
    var tokenExpDuration: Double
    var bugUrl: String
    var myCompany: MyCompany
    var resetKeyExpDuration: Double
    var smtp: ConfigKeys.Smtp
    var systemRootPublicURL: String
    
    init() {
    
        let path = DirectoryConfiguration.detect().resourcesDirectory
        let url = URL(fileURLWithPath: path).appendingPathComponent("Resources", isDirectory: true).appendingPathComponent("Config.json")
        do {
            let data = try Data(contentsOf: url)
            let decoder = try JSONDecoder().decode(ConfigKeys.self, from: data)
            self.database = decoder.database
            self.listenOnPort = decoder.listenOnPort
            self.tokenExpDuration = decoder.tokenExpDuration
            self.bugUrl = decoder.bugUrl
            self.myCompany = decoder.myCompany
            self.resetKeyExpDuration = decoder.resetKeyExpDuration
            self.smtp = decoder.smtp
            if decoder.systemRootPublicURL.suffix(1) == "/" {
                let len = decoder.systemRootPublicURL.lengthOfBytes(using: .utf8)
                self.systemRootPublicURL = String(decoder.systemRootPublicURL.prefix(len))
            }
            else {
                self.systemRootPublicURL = decoder.systemRootPublicURL
            }
            
        }
        catch {
            print ("Could not initialize app from Config.json.  Initilizing with hard-coded default values. \n \(error)")
            exit(0)
        }
    }
}

