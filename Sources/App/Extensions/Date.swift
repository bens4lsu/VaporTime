//
//  Date.swift
//  App
//
//  Created by Ben Schultz on 3/20/20.
//

import Foundation

extension Date {
    
    func isSameDayAs(_ otherDate: Date) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: self) == formatter.string(from: otherDate)
    }
}

extension Optional where Wrapped == Date {
    func isSameDayAs(_ otherDate: Date?) -> Bool {
        var isDateChanged = (self == nil && otherDate != nil) ||
                            (self != nil && otherDate == nil)
        if let date1 = self, let date2 = otherDate {
            isDateChanged = isDateChanged || date1.isSameDayAs(date2)
        }
        return isDateChanged
    }
}
