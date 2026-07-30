# swift-rfc-9111

![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)

Swift implementation of RFC 9111: HTTP Caching

## Overview

This package implements [RFC 9111 - HTTP Caching](https://www.rfc-editor.org/rfc/rfc9111.html), which obsoletes RFC 7234 (June 2022).

RFC 9111 defines how HTTP caches work, including cache control directives, freshness calculations, validation, and cache key computation.

## Status

**Alpha** - Initial implementation complete

### Implemented

- ✅ `HTTP.CacheControl` - Cache-Control directives (Section 5.2)
  - Request directives: max-age, max-stale, min-fresh, no-cache, no-store, no-transform, only-if-cached
  - Response directives: public, private, must-revalidate, must-understand, proxy-revalidate, s-maxage, immutable, stale-while-revalidate, stale-if-error
  - Full parsing and serialization

- ✅ `HTTP.Age` - Age header field (Section 5.1)
  - Indicates time since response generation/validation
  - ExpressibleByIntegerLiteral support

- ✅ `HTTP.Expires` - Expires header field (Section 5.3)
  - HTTP-date format for expiration times
  - Convenience methods: `isExpired()`, `timeRemaining()`

- ✅ `HTTP.Vary` - Vary header field (Section 4.1)
  - Cache key computation support
  - Wildcard ("*") support
  - Header matching utilities

- ✅ `HTTP.Freshness` - Freshness calculation utilities (Section 4.2)
  - `calculateFreshnessLifetime()` - Compute freshness lifetime from headers
  - `calculateAge()` - RFC 9111 Section 4.2.3 age calculation
  - `isFresh()` - Determine if cached response is fresh
  - `calculateHeuristicFreshness()` - 10% heuristic based on Last-Modified
  - Supports both shared and private caches

## Usage

### Cache-Control

```swift
import RFC_9111

// Creating Cache-Control directives
var cc = HTTP.CacheControl()
cc.isPublic = true
cc.maxAge = 3600
cc.mustRevalidate = true

print(cc.headerValue)
// "public, max-age=3600, must-revalidate"

// Parsing
let parsed = HTTP.CacheControl.parse("public, max-age=3600, must-revalidate")
// parsed.isPublic == true
// parsed.maxAge == 3600
// parsed.mustRevalidate == true
```

### Age

```swift
let age = HTTP.Age(seconds: 120)
print(age.headerValue)  // "120"

// ExpressibleByIntegerLiteral
let age2: HTTP.Age = 120
```

### Expires

```swift
let expirationDate = Date().addingTimeInterval(3600)
let expires = HTTP.Expires(date: expirationDate)

print(expires.headerValue)
// "Wed, 17 Nov 2025 09:37:45 GMT"

// Check if expired
if expires.isExpired() {
    print("Response has expired")
}

// Time remaining
let remaining = expires.timeRemaining()
print("Expires in \(remaining) seconds")
```

### Vary

```swift
// Vary by Accept-Encoding and Accept-Language
let vary = HTTP.Vary(fieldNames: ["Accept-Encoding", "Accept-Language"])
print(vary.headerValue)
// "accept-encoding, accept-language"

// Check if varies on a specific field
vary.includes("Accept-Encoding")  // true

// Check if cached response matches new request
vary.matches(
    requestHeaders: ["accept-encoding": "gzip"],
    cachedRequestHeaders: ["accept-encoding": "gzip"]
)  // true

// Vary: * (varies on all aspects)
let varyAll = HTTP.Vary.all
```

### Freshness Calculations

```swift
let response = HTTP.Response(
    status: .ok,
    headers: [
        try .init(name: "Cache-Control", value: "max-age=3600"),
        try .init(name: "Date", value: HTTP.Date(Date()).headerValue)
    ]
)

// Calculate freshness lifetime
let lifetime = HTTP.Freshness.calculateFreshnessLifetime(response: response)
// lifetime == 3600

// Calculate age
let age = HTTP.Freshness.calculateAge(
    response: response,
    now: Date(),
    responseTime: Date()
)

// Check if fresh
if HTTP.Freshness.isFresh(response: response) {
    print("Response is fresh, can serve from cache")
} else {
    print("Response is stale, must revalidate")
}

// Calculate when response becomes stale
if let staleDate = HTTP.Freshness.staleDate(
    response: response,
    responseTime: Date()
) {
    print("Response will be stale at: \(staleDate)")
}
```

### Heuristic Freshness

```swift
let response = HTTP.Response(
    status: .ok,
    headers: [
        try .init(name: "Date", value: HTTP.Date(Date()).headerValue),
        try .init(name: "Last-Modified", value: HTTP.Date(Date().addingTimeInterval(-864000)).headerValue)
    ]
)

// Use heuristic freshness (10% of time since Last-Modified, capped at 24 hours)
let lifetime = HTTP.Freshness.calculateFreshnessLifetime(
    response: response,
    allowHeuristics: true
)
// lifetime will be ~86400 (10% of 10 days, capped at 24 hours)
```

## Requirements

- Swift 6.0+
- macOS 14.0+, iOS 17.0+, tvOS 17.0+, watchOS 10.0+

## Dependencies

- [swift-rfc-9110](https://github.com/swift-ietf/swift-rfc-9110) - HTTP Semantics

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/swift-ietf/swift-rfc-9111", from: "0.0.4")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "RFC 9111", package: "swift-rfc-9111")
        ]
    )
]
```

## Relationship to Other RFCs

- **RFC 9110** - HTTP Semantics (swift-rfc-9110)
- **RFC 9111** (this package) - HTTP Caching
- **RFC 9112** - HTTP/1.1 Message Syntax (swift-rfc-9112)

Together, these three RFCs replace the obsolete RFC 7230-7235 series.

## Design Principles

Following the established patterns from swift-rfc-9110:

- ✅ Types extend `RFC_9110` namespace
- ✅ Convenience typealias: `HTTP = RFC_9110`
- ✅ Comprehensive conformances: Sendable, Equatable, Hashable, Codable
- ✅ Full documentation with RFC section references
- ✅ Swift 6.0 strict concurrency enabled

## Testing

```bash
swift test
```

Current test coverage: 101 tests, all passing

- 13 tests for HTTP.Age
- 16 tests for HTTP.Expires
- 20 tests for HTTP.Vary
- 27 tests for HTTP.CacheControl
- 25 tests for HTTP.Freshness

## License

[Apache 2.0](LICENSE)

## References

- [RFC 9111: HTTP Caching](https://www.rfc-editor.org/rfc/rfc9111.html)
- [RFC 9111 Section 4.1: Cache Keys](https://www.rfc-editor.org/rfc/rfc9111.html#section-4.1)
- [RFC 9111 Section 4.2: Freshness](https://www.rfc-editor.org/rfc/rfc9111.html#section-4.2)
- [RFC 9111 Section 5.1: Age](https://www.rfc-editor.org/rfc/rfc9111.html#section-5.1)
- [RFC 9111 Section 5.2: Cache-Control](https://www.rfc-editor.org/rfc/rfc9111.html#section-5.2)
- [RFC 9111 Section 5.3: Expires](https://www.rfc-editor.org/rfc/rfc9111.html#section-5.3)
