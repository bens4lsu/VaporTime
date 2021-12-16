//
//  OptionalPostVariables.swift
//  App
//
//  Created by Ben Schultz on 2/6/20.
//

import Foundation

extension Optional where Wrapped == String {
    
    func toBool() -> Bool {
        let trues = ["on", "true", "1", "yes"]
        if let str = self {
            return trues.contains(str)
        }
        return false
    }
    
    func toDate() -> Date? {
        guard let thisDate = self else{
            return nil
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd/yyyy"
        dateFormatter.timeZone = .current
        if let date = dateFormatter.date(from: thisDate) {
            return date
        }
        return nil
    }
    
    func toInt() -> Int? {
        Int(self ?? "")
    }
    
    func toDouble() -> Double? {
        Double(self ?? "")
    }
}
