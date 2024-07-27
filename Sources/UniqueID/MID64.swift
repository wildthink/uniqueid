//
//  MID64.swift
//  
//
//  Created by Jason Jobe on 1/15/24.
//

import Foundation

/// The MID64 is a simple UUID generator that fits into 64 bits
/// that provides acceptable performance on a given machine.
/**
 To determine how many unique identifiers the `MID64 (UniqueIDGenerator)` can produce and over what period, we need to analyze the bit allocation for both the timestamp and the counter in the 64-bit identifier:
 
 1. **Timestamp Allocation**: The timestamp uses 48 bits. Since the timestamp is in milliseconds, this means \( 2^{48} \) different timestamps can be represented.
 
 2. **Counter Allocation**: The counter uses the remaining 16 bits of the 64-bit integer. This means the counter can represent \( 2^{16} \) different values, which is 65,536 unique values.
 
 Now, let's calculate the total number of unique identifiers and the period over which they can be generated:
 
 - **Total Unique Identifiers**: For each millisecond timestamp, there can be 65,536 unique identifiers (due to the counter). Therefore, the total number of unique identifiers is \( 2^{48} \times 2^{16} = 2^{64} \).
 
 - **Period of Time**: Since the timestamp is in milliseconds and it's a 48-bit number, the total period it can cover is \( 2^{48} \) milliseconds. To convert this to years:
 
 \[
 2^{48} \text{ milliseconds} \times \frac{1 \text{ second}}{1000 \text{ milliseconds}} \times \frac{1 \text{ minute}}{60 \text{ seconds}} \times \frac{1 \text{ hour}}{60 \text{ minutes}} \times \frac{1 \text{ day}}{24 \text{ hours}} \times \frac{1 \text{ year}}{365.25 \text{ days}}
 \]
 
 \[
 \approx 8.77 \times 10^{11} \text{ years}
 \]
 
 Thus, the `MID64` can produce \( 2^{64} \) (approximately 18.4 quintillion) unique identifiers over a period of approximately 877 billion years. This vast range makes it extremely unlikely to exhaust the unique identifiers in any practical application.
 
 Keep in mind, the actual usable period might be less depending on the chosen epoch. For instance, if the epoch is set to January 1, 2020, then the period during which identifiers can be generated starts from that date.
 */
public struct MID64: Codable, Hashable, Equatable, Comparable {
    
    public let value: UInt64
    public var timestamp: Date { value.extractDate() }
    public var counter: Int { Int((value << timestampBits) >> timestampBits) }
    public var tag: Int { Int((value << (64-tagBits)) >> (64-tagBits)) }

    public init(_ value: UInt64) {
        self.value = value
    }
    
    public init(tag: UInt8 = 0) {
        self.value = MID64Generator.shared.generateID(tag: tag)
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.value = try container.decode(UInt64.self)
    }
        
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.value)
    }
    
    public static func < (lhs: MID64, rhs: MID64) -> Bool {
        lhs.value < rhs.value
    }
    public static func new(tag: UInt8 = 0) -> MID64 { .init(tag: tag) }
    public static var null: MID64 = 0
}

fileprivate let timestampBits = 48
fileprivate let counterBits = 16
fileprivate let tagBits = 8

extension MID64: CustomStringConvertible {
    public var description: String {
        String(value)
    }
}

extension MID64: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: UInt64) {
        self.value = value
    }
}

public class MID64Generator {
    public static var shared: MID64Generator = .init()
    
    private var lastTimestamp: UInt64 = 0
    private var counter: UInt16 = 0
    private let epoch: UInt64 = 1577836800000 // January 1, 2020, in milliseconds
    private let lock = NSLock()
    
    public init() {}
    
    public func generateID(tag: UInt8 = 0) -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        
        let currentTimestamp = UInt64(Date().timeIntervalSince1970 * 1000) - epoch
        
        if currentTimestamp != lastTimestamp {
            lastTimestamp = currentTimestamp
            counter = 0
        } else {
            counter &+= 1
        }
        
        let id = (lastTimestamp << (64-timestampBits))
            | UInt64(counter << tagBits)
            | UInt64(tag)
        return id
    }
}

extension UInt64 {
    private var epoch: UInt64 { 1577836800000 } // January 1, 2020, in milliseconds
    
    public func extractDate() -> Date {
        let timestamp = (self >> (64-timestampBits)) + epoch
        return Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
    }
}

// Example Usage
func example() {
    let generator = MID64Generator()
    let uniqueID = generator.generateID()
    print("Unique ID: \(uniqueID)")
    
    let extractedDate = uniqueID.extractDate()
    print("Extracted Date: \(extractedDate)")
}

//
public extension FixedWidthInteger {
    
    var bytes:[UInt8] {
        var bigEndianValue = self.bigEndian
        let byteCount = MemoryLayout<Self>.size
        var byteArray: [UInt8] = []
        for _ in 0..<byteCount {
            byteArray.append(UInt8(bigEndianValue & 0xff))
            bigEndianValue >>= 8
        }
        return byteArray.reversed()
    }
    
    init?(bytes: [UInt8]) {
        guard bytes.count == MemoryLayout<Self>.size else {
            // Invalid byte array length for conversion
            return nil
        }
        var value: Self = 0
        for byte in bytes {
            value <<= 8
            value |= Self(byte)
        }
        self = value
    }
}
