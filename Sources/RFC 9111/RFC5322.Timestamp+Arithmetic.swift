// RFC5322.Timestamp+Arithmetic.swift
// swift-rfc-9111
//
// Time arithmetic operations for RFC 9111 cache calculations
// RFC 9111 Section 4.2.3: Age Calculations
//
// These operations are defined by RFC 9111 for cache freshness calculations:
// "age_value = date_value + (now - request_time)"

import RFC_5322

// MARK: - Time Interval Operations (RFC 9111 Section 4.2.3)

extension RFC_5322.DateTime {
    /// Calculate time interval in seconds between two timestamps
    /// RFC 9111 Section 4.2.3: "age_value = date_value + (now - request_time)"
    internal func timeIntervalSince(_ other: RFC_5322.DateTime) -> Double {
        return Double(self.secondsSinceEpoch - other.secondsSinceEpoch)
    }

    /// Create new timestamp by adding time interval in seconds
    /// RFC 9111 Section 4.2.1: Calculating expiration from freshness lifetime
    internal func adding(_ interval: Double) -> RFC_5322.DateTime {
        return RFC_5322.DateTime(secondsSinceEpoch: self.secondsSinceEpoch + Int(interval))
    }
}
