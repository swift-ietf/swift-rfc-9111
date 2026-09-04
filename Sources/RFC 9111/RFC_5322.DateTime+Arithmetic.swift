import RFC_5322

extension RFC_5322.DateTime {

    internal func timeIntervalSince(_ other: RFC_5322.DateTime) -> Double {
        return Double(self.secondsSinceEpoch - other.secondsSinceEpoch)
    }

    internal func adding(_ interval: Double) -> RFC_5322.DateTime {
        return RFC_5322.DateTime(secondsSinceEpoch: self.secondsSinceEpoch + Int(interval))
    }
}
