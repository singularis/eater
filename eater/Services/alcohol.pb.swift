// DO NOT EDIT.
// swift-format-ignore-file
// swiftlint:disable all
//
// Hand-crafted SwiftProtobuf definitions for Alcohol messages.
// These mirror the backend proto contract for alcohol endpoints.

import SwiftProtobuf

private struct _GeneratedWithProtocGenSwiftVersion: SwiftProtobuf.ProtobufAPIVersionCheck {
    struct _2: SwiftProtobuf.ProtobufAPIVersion_2 {}
    typealias Version = _2
}

struct Eater_AlcoholDaySummary: Sendable {
    var totalDrinks: Int32 = 0
    var totalCalories: Int32 = 0
    var drinksOfDay: [String] = []
    var unknownFields = SwiftProtobuf.UnknownStorage()
    init() {}
}

struct Eater_AlcoholEvent: Sendable {
    var time: Int64 = 0
    /// yyyy-MM-dd in responses
    var date: String = .init()
    var drinkName: String = .init()
    var calories: Int32 = 0
    var quantity: Int32 = 0
    var unknownFields = SwiftProtobuf.UnknownStorage()
    init() {}
}

struct Eater_GetAlcoholLatestRequest: Sendable {
    var unknownFields = SwiftProtobuf.UnknownStorage()
    init() {}
}

struct Eater_GetAlcoholLatestResponse: Sendable {
    var todaySummary: Eater_AlcoholDaySummary {
        get { return _todaySummary ?? Eater_AlcoholDaySummary() }
        set { _todaySummary = newValue }
    }

    var hasTodaySummary: Bool { return _todaySummary != nil }
    mutating func clearTodaySummary() { _todaySummary = nil }
    var unknownFields = SwiftProtobuf.UnknownStorage()
    init() {}
    fileprivate var _todaySummary: Eater_AlcoholDaySummary?
}

struct Eater_GetAlcoholRangeRequest: Sendable {
    /// dd-MM-yyyy
    var startDate: String = .init()
    /// dd-MM-yyyy
    var endDate: String = .init()
    var unknownFields = SwiftProtobuf.UnknownStorage()
    init() {}
}

struct Eater_GetAlcoholRangeResponse: Sendable {
    var events: [Eater_AlcoholEvent] = []
    var unknownFields = SwiftProtobuf.UnknownStorage()
    init() {}
}

// MARK: - SwiftProtobuf conformance

private let _protobuf_package = "eater"

extension Eater_AlcoholDaySummary: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName: String = _protobuf_package + ".AlcoholDaySummary"
    static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
        1: .standard(proto: "total_drinks"),
        2: .standard(proto: "total_calories"),
        3: .standard(proto: "drinks_of_day"),
    ]

    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularInt32Field(value: &totalDrinks)
            case 2: try decoder.decodeSingularInt32Field(value: &totalCalories)
            case 3: try decoder.decodeRepeatedStringField(value: &drinksOfDay)
            default: break
            }
        }
    }

    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if totalDrinks != 0 { try visitor.visitSingularInt32Field(value: totalDrinks, fieldNumber: 1) }
        if totalCalories != 0 { try visitor.visitSingularInt32Field(value: totalCalories, fieldNumber: 2) }
        if !drinksOfDay.isEmpty { try visitor.visitRepeatedStringField(value: drinksOfDay, fieldNumber: 3) }
        try unknownFields.traverse(visitor: &visitor)
    }

    static func == (lhs: Eater_AlcoholDaySummary, rhs: Eater_AlcoholDaySummary) -> Bool {
        if lhs.totalDrinks != rhs.totalDrinks { return false }
        if lhs.totalCalories != rhs.totalCalories { return false }
        if lhs.drinksOfDay != rhs.drinksOfDay { return false }
        if lhs.unknownFields != rhs.unknownFields { return false }
        return true
    }
}

extension Eater_AlcoholEvent: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName: String = _protobuf_package + ".AlcoholEvent"
    static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
        1: .same(proto: "time"),
        2: .same(proto: "date"),
        3: .standard(proto: "drink_name"),
        4: .same(proto: "calories"),
        5: .same(proto: "quantity"),
    ]

    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularInt64Field(value: &time)
            case 2: try decoder.decodeSingularStringField(value: &date)
            case 3: try decoder.decodeSingularStringField(value: &drinkName)
            case 4: try decoder.decodeSingularInt32Field(value: &calories)
            case 5: try decoder.decodeSingularInt32Field(value: &quantity)
            default: break
            }
        }
    }

    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if time != 0 { try visitor.visitSingularInt64Field(value: time, fieldNumber: 1) }
        if !date.isEmpty { try visitor.visitSingularStringField(value: date, fieldNumber: 2) }
        if !drinkName.isEmpty { try visitor.visitSingularStringField(value: drinkName, fieldNumber: 3) }
        if calories != 0 { try visitor.visitSingularInt32Field(value: calories, fieldNumber: 4) }
        if quantity != 0 { try visitor.visitSingularInt32Field(value: quantity, fieldNumber: 5) }
        try unknownFields.traverse(visitor: &visitor)
    }

    static func == (lhs: Eater_AlcoholEvent, rhs: Eater_AlcoholEvent) -> Bool {
        if lhs.time != rhs.time { return false }
        if lhs.date != rhs.date { return false }
        if lhs.drinkName != rhs.drinkName { return false }
        if lhs.calories != rhs.calories { return false }
        if lhs.quantity != rhs.quantity { return false }
        if lhs.unknownFields != rhs.unknownFields { return false }
        return true
    }
}

extension Eater_GetAlcoholLatestRequest: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName: String = _protobuf_package + ".GetAlcoholLatestRequest"
    static let _protobuf_nameMap = SwiftProtobuf._NameMap()

    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let _ = try decoder.nextFieldNumber() {}
    }

    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        try unknownFields.traverse(visitor: &visitor)
    }

    static func == (lhs: Eater_GetAlcoholLatestRequest, rhs: Eater_GetAlcoholLatestRequest) -> Bool {
        if lhs.unknownFields != rhs.unknownFields { return false }
        return true
    }
}

extension Eater_GetAlcoholLatestResponse: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName: String = _protobuf_package + ".GetAlcoholLatestResponse"
    static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
        1: .standard(proto: "today_summary"),
    ]

    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularMessageField(value: &_todaySummary)
            default: break
            }
        }
    }

    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        try { if let v = self._todaySummary { try visitor.visitSingularMessageField(value: v, fieldNumber: 1) } }()
        try unknownFields.traverse(visitor: &visitor)
    }

    static func == (lhs: Eater_GetAlcoholLatestResponse, rhs: Eater_GetAlcoholLatestResponse) -> Bool {
        if lhs._todaySummary != rhs._todaySummary { return false }
        if lhs.unknownFields != rhs.unknownFields { return false }
        return true
    }
}

extension Eater_GetAlcoholRangeRequest: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName: String = _protobuf_package + ".GetAlcoholRangeRequest"
    static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
        1: .standard(proto: "start_date"),
        2: .standard(proto: "end_date"),
    ]

    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularStringField(value: &startDate)
            case 2: try decoder.decodeSingularStringField(value: &endDate)
            default: break
            }
        }
    }

    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !startDate.isEmpty { try visitor.visitSingularStringField(value: startDate, fieldNumber: 1) }
        if !endDate.isEmpty { try visitor.visitSingularStringField(value: endDate, fieldNumber: 2) }
        try unknownFields.traverse(visitor: &visitor)
    }

    static func == (lhs: Eater_GetAlcoholRangeRequest, rhs: Eater_GetAlcoholRangeRequest) -> Bool {
        if lhs.startDate != rhs.startDate { return false }
        if lhs.endDate != rhs.endDate { return false }
        if lhs.unknownFields != rhs.unknownFields { return false }
        return true
    }
}

extension Eater_GetAlcoholRangeResponse: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName: String = _protobuf_package + ".GetAlcoholRangeResponse"
    static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
        1: .same(proto: "events"),
    ]

    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeRepeatedMessageField(value: &events)
            default: break
            }
        }
    }

    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !events.isEmpty { try visitor.visitRepeatedMessageField(value: events, fieldNumber: 1) }
        try unknownFields.traverse(visitor: &visitor)
    }

    static func == (lhs: Eater_GetAlcoholRangeResponse, rhs: Eater_GetAlcoholRangeResponse) -> Bool {
        if lhs.events != rhs.events { return false }
        if lhs.unknownFields != rhs.unknownFields { return false }
        return true
    }
}
