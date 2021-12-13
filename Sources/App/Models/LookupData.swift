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

extension Array where Element == LookupTrinity {
    var contracts: Set<LookupContextPair>{
        var set = Set<LookupContextPair>()
        for elem in self {
            set.insert(LookupContextPair(name: elem.contractDescription, id: elem.contractId))
        }
    return set
    }
    
    var companies: Set<LookupContextPair>{
        var set = Set<LookupContextPair>()
        for elem in self {
            set.insert(LookupContextPair(name: elem.servicesForCompany, id: elem.companyId))
        }
        return set
    }
    
    var projects: Set<LookupContextPair>{
        var set = Set<LookupContextPair>()
        for elem in self {
            set.insert(LookupContextPair(name: elem.projectDescription, id: elem.projectId))
        }
        return set
    }
}


struct LookupPerson: Codable, Comparable {
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
    
    static func ==(lhs: LookupPerson, rhs: LookupPerson) -> Bool {
        return lhs.name == rhs.name
    }
    
    static func <(lhs: LookupPerson, rhs: LookupPerson) -> Bool {
        return lhs.name < rhs.name
    }
}

struct LookupContextPair: Codable , Hashable, Comparable {
    var name: String
    var id: Int
    
    static func ==(lhs: LookupContextPair, rhs: LookupContextPair) -> Bool {
        return lhs.name == rhs.name
    }
    
    static func <(lhs: LookupContextPair, rhs: LookupContextPair) -> Bool {
        return lhs.name < rhs.name
    }
}

struct LookupContext: Codable {
    var contracts: [LookupContextPair]
    var companies: [LookupContextPair]
    var projects: [LookupContextPair]
    var timeBillers: [LookupPerson]
    var groupBy: [LookupContextPair]
    var projectStatuses: [RefProjectStatusesDTO]
    var eventTypes: [LookupContextPair]
    var rateSchedules: [LuRateSchedules]
}
