//
//  Date.swift
//  App
//
//  Created by Ben Schultz on 3/20/20.
//

import Foundation

extension Date {
    
    var asLocal: Date {
        // for use when you get a date-only field from the database.  system assumes GMT.  This
        // makes it the same date, but in the local time zone.
        let tz1 = TimeZone(identifier: "GMT")!
        let tz2 = TimeZone.current
        return self.convertToTimeZone(initTimeZone: tz2, timeZone: tz1)
    }
    
    func isSameDayAs(_ otherDate: Date) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: self) == formatter.string(from: otherDate)
    }
    
    func convertToTimeZone(initTimeZone: TimeZone, timeZone: TimeZone) -> Date {
        let delta = TimeInterval(timeZone.secondsFromGMT(for: self) - initTimeZone.secondsFromGMT(for: self))
        return addingTimeInterval(delta)
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
    
    func isSameDayAs(_ otherDate: Date) -> Bool {
        guard let date = self else { return false }
        return date.isSameDayAs(otherDate)
    }
}
