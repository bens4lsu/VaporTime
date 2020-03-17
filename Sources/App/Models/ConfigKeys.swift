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
        var port: Int
        var username: String
        var password: String
        private var security: String
        
        var secure: SmtpSecureChannel {
            if security == "ssl" || security == ".ssl" {
                return .ssl
            }
            if security == "startTls" ||  security == ".startTls" {
                return .startTls
            }
            if security == "startTlsWhenAvailable" || security == ".startTlsWhenAvailable" {
                return .startTlsWhenAvailable
            }
            else {
                return .none
            }
        }
    }
    
    var database: ConfigKeys.Database
    var tokenExpDuration: Double
    var bugUrl: String
    var myCompany: MyCompany
    var resetKeyExpDuration: Double
    var smtp: ConfigKeys.Smtp
    
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
            self.smtp = decoder.smtp
            
        }
        catch {
            print ("Could not initialize app from Config.json.  Initilizing with hard-coded default values. \n \(error)")
            
            exit(0)
        }
    }
}

