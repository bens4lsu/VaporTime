//
//  LuRateSchedules.swift
//  App
//
//  Created by Ben Schultz on 3/9/20.
//

import Foundation
import FluentMySQL
import Vapor

struct LuRateSchedules: Content, MySQLModel, Codable {
    var id: Int?
    var description: String
    var regularRate: Double
    var otRate: Double?
    var discountPercentage: Double?

    typealias Database = MySQLDatabase
    typealias ID = Int
    static let idKey: IDKey = \.id
    static let entity = "LuRateSchedules"

    private enum CodingKeys: String, CodingKey {
        case id = "RateScheduleID",
        description = "RateDescription",
        regularRate = "RegularRate",
        otRate = "OTRate",
        discountPercentage = "DiscountPercent"
    }
}
