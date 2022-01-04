//
//  File.swift
//  
//
//  Created by Ben Schultz on 12/21/21.
//

import Foundation
import Fluent
import FluentMySQLDriver
import Vapor


final class Invoice: Content, Model, Codable {
    static var schema = "InvoiceItems"
    
 
    enum InvoiceStatus: Int, Codable{
        case pending = 1
        case sent
        case paid
        case writeoff
        case canceled
    }

    typealias TimebillItem = Int
    
    @ID(custom: "BillingID")
    var id: Int?
    
    @Field(key: "BillingDescription")
    var billDescription: String
    
    @Field(key: "InvoiceNumber")
    var invoiceNumber: String
    
    @Field(key: "ContractID")
    var contractId: Int
    
    @Field(key: "BillDate")
    var billDate: Date
    
    @Field(key: "BillPeriodStartDate")
    var billPeriodStart: Date
    
    @Field(key: "BillPeriodEndDate")
    var billPeriodEnd: Date
    
    @OptionalField(key: "ClientAdditionalInfo")
    var additionalInfo: String?
    
    @Field(key: "Amount")
    var amount: Double
    
    @Field(key: "Status")
    var status: InvoiceStatus
    
    @OptionalField(key: "FilePath")
    var filePath: String?
    
    var time: [Int] = []
    
    required init() { }
    
    convenience init (_ id: Int) {
        self.init()
        self.id = id
        self.billDescription = "billDescription"
        self.invoiceNumber = "90122287A-8"
        self.contractId = 0
        self.billDate = Date()
        self.billPeriodStart = Date() - 30
        self.billPeriodEnd = Date()
        self.amount = 999.09
        self.status = .pending
    }
}
