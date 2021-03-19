//
//  LuRateSchedules.swift
//  App
//
//  Created by Ben Schultz on 3/9/20.
//

import Foundation
import Fluent
import Vapor

final class LuRateSchedules: Content, Model, Codable {
    @ID(custom: "RateScheduleID")
    var id: Int?
    
    @Field(key: "RateDescription")
    var description: String
    
    @Field(key: "RegularRate")
    var regularRate: Double
    
    @Field(key: "OTRate")
    var otRate: Double?
    
    @Field(key: "DiscountPercent")
    var discountPercentage: Double?

//    typealias Database = MySQLDatabase
//    typealias ID = Int
//    static let idKey: IDKey = \.id
    static let schema = "LuRateSchedules"

    private enum CodingKeys: String, CodingKey {
        case id = "RateScheduleID",
        description = "RateDescription",
        regularRate = "RegularRate",
        otRate = "OTRate",
        discountPercentage = "DiscountPercent"
    }
    
    required init() { }
}
