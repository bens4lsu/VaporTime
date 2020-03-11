//
//  LookupData.swift
//  App
//
//  Created by Ben Schultz on 2/7/20.
//

import Foundation

struct LookupTrinity: Codable {
    var contractDescription: String
    var projectDescription: String
    var servicesForCompany: String
    var isActive: Bool
    var contractId: Int
    var projectId: Int
    var companyId: Int
    
    private enum CodingKeys: String, CodingKey {
        case contractDescription = "ContractDescription",
        projectDescription = "ProjectDescription",
        servicesForCompany = "CompanyName",
        isActive = "IsActive",
        contractId = "ContractID",
        projectId = "ProjectID",
        companyId = "CompanyID"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.contractDescription = try container.decodeIfPresent(String.self, forKey: .contractDescription)!
        self.projectDescription = try container.decodeIfPresent(String.self, forKey: .projectDescription)!
        self.servicesForCompany = try container.decodeIfPresent(String.self, forKey: .servicesForCompany)!
        self.isActive = (try? container.decodeIfPresent(String.self, forKey: .isActive)) == "1" ? true : false
        self.contractId = try container.decodeIfPresent(Int.self, forKey: .contractId)!
        self.projectId = try container.decodeIfPresent(Int.self, forKey: .projectId)!
        self.companyId = try container.decodeIfPresent(Int.self, forKey: .companyId)!
    }
}

struct LookupPerson: Codable {
    var name: String
    var id: Int
    
    private enum CodingKeys: String, CodingKey {
        case name = "Name",
        id = "PersonID"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decodeIfPresent(String.self, forKey: .name)!
        self.id = try container.decodeIfPresent(Int.self, forKey: .id)!
    }
}

struct LookupContextPair: Codable , Hashable{
    var name: String
    var id: Int
    
    static func ==(lhs: LookupContextPair, rhs: LookupContextPair) -> Bool {
        return lhs.id == rhs.id
    }
    
    static func <(lhs: LookupContextPair, rhs: LookupContextPair) -> Bool {
        return lhs.id < rhs.id
    }
}

struct LookupContext: Codable {
    var contracts: Set<LookupContextPair>
    var companies: Set<LookupContextPair>
    var projects: Set<LookupContextPair>
    var timeBillers: [LookupPerson]
    var groupBy: [LookupContextPair]
    var projectStatuses: [RefProjectStatuses]
    var eventTypes: [LookupContextPair]
    var rateSchedules: [LuRateSchedules]
}
