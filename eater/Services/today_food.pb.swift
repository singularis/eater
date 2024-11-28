// DO NOT EDIT.
// swift-format-ignore-file
// swiftlint:disable all
//
// Generated by the Swift generator plugin for the protocol buffer compiler.
// Source: today_food.proto
//
// For information on using the generated types, please see the documentation:
//   https://github.com/apple/swift-protobuf/

import SwiftProtobuf

// If the compiler emits an error on this type, it is because this file
// was generated by a version of the `protoc` Swift plug-in that is
// incompatible with the version of SwiftProtobuf to which you are linking.
// Please ensure that you are building against the same version of the API
// that was used to generate this file.
private struct _GeneratedWithProtocGenSwiftVersion: SwiftProtobuf.ProtobufAPIVersionCheck {
    struct _2: SwiftProtobuf.ProtobufAPIVersion_2 {}
    typealias Version = _2
}

struct Contains: Sendable {
    // SwiftProtobuf.Message conformance is added in an extension below. See the
    // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
    // methods supported on all messages.

    var carbohydrates: Double = 0

    var fats: Double = 0

    var proteins: Double = 0

    var sugar: Double = 0

    var unknownFields = SwiftProtobuf.UnknownStorage()

    init() {}
}

struct Dish: Sendable {
    // SwiftProtobuf.Message conformance is added in an extension below. See the
    // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
    // methods supported on all messages.

    var dishName: String = .init()

    var estimatedAvgCalories: Int32 = 0

    var ingredients: [String] = []

    var totalAvgWeight: Int32 = 0

    var unknownFields = SwiftProtobuf.UnknownStorage()

    init() {}
}

struct TotalForDay: Sendable {
    // SwiftProtobuf.Message conformance is added in an extension below. See the
    // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
    // methods supported on all messages.

    var contains: Contains {
        get { return _contains ?? Contains() }
        set { _contains = newValue }
    }

    /// Returns true if `contains` has been explicitly set.
    var hasContains: Bool { return _contains != nil }
    /// Clears the value of `contains`. Subsequent reads from it will return its default value.
    mutating func clearContains() { _contains = nil }

    var totalAvgWeight: Int32 = 0

    var totalCalories: Int32 = 0

    var unknownFields = SwiftProtobuf.UnknownStorage()

    init() {}

    fileprivate var _contains: Contains? = nil
}

struct TodayFood: Sendable {
    // SwiftProtobuf.Message conformance is added in an extension below. See the
    // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
    // methods supported on all messages.

    var dishesToday: [Dish] = []

    var totalForDay: TotalForDay {
        get { return _totalForDay ?? TotalForDay() }
        set { _totalForDay = newValue }
    }

    /// Returns true if `totalForDay` has been explicitly set.
    var hasTotalForDay: Bool { return _totalForDay != nil }
    /// Clears the value of `totalForDay`. Subsequent reads from it will return its default value.
    mutating func clearTotalForDay() { _totalForDay = nil }

    var unknownFields = SwiftProtobuf.UnknownStorage()

    init() {}

    fileprivate var _totalForDay: TotalForDay? = nil
}

// MARK: - Code below here is support for the SwiftProtobuf runtime.

extension Contains: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName: String = "Contains"
    static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
        1: .same(proto: "carbohydrates"),
        2: .same(proto: "fats"),
        3: .same(proto: "proteins"),
        4: .same(proto: "sugar"),
    ]

    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            // The use of inline closures is to circumvent an issue where the compiler
            // allocates stack space for every case branch when no optimizations are
            // enabled. https://github.com/apple/swift-protobuf/issues/1034
            switch fieldNumber {
            case 1: try decoder.decodeSingularDoubleField(value: &carbohydrates)
            case 2: try decoder.decodeSingularDoubleField(value: &fats)
            case 3: try decoder.decodeSingularDoubleField(value: &proteins)
            case 4: try decoder.decodeSingularDoubleField(value: &sugar)
            default: break
            }
        }
    }

    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if carbohydrates.bitPattern != 0 {
            try visitor.visitSingularDoubleField(value: carbohydrates, fieldNumber: 1)
        }
        if fats.bitPattern != 0 {
            try visitor.visitSingularDoubleField(value: fats, fieldNumber: 2)
        }
        if proteins.bitPattern != 0 {
            try visitor.visitSingularDoubleField(value: proteins, fieldNumber: 3)
        }
        if sugar.bitPattern != 0 {
            try visitor.visitSingularDoubleField(value: sugar, fieldNumber: 4)
        }
        try unknownFields.traverse(visitor: &visitor)
    }

    static func == (lhs: Contains, rhs: Contains) -> Bool {
        if lhs.carbohydrates != rhs.carbohydrates { return false }
        if lhs.fats != rhs.fats { return false }
        if lhs.proteins != rhs.proteins { return false }
        if lhs.sugar != rhs.sugar { return false }
        if lhs.unknownFields != rhs.unknownFields { return false }
        return true
    }
}

extension Dish: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName: String = "Dish"
    static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
        1: .standard(proto: "dish_name"),
        2: .standard(proto: "estimated_avg_calories"),
        3: .same(proto: "ingredients"),
        4: .standard(proto: "total_avg_weight"),
    ]

    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            // The use of inline closures is to circumvent an issue where the compiler
            // allocates stack space for every case branch when no optimizations are
            // enabled. https://github.com/apple/swift-protobuf/issues/1034
            switch fieldNumber {
            case 1: try decoder.decodeSingularStringField(value: &dishName)
            case 2: try decoder.decodeSingularInt32Field(value: &estimatedAvgCalories)
            case 3: try decoder.decodeRepeatedStringField(value: &ingredients)
            case 4: try decoder.decodeSingularInt32Field(value: &totalAvgWeight)
            default: break
            }
        }
    }

    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !dishName.isEmpty {
            try visitor.visitSingularStringField(value: dishName, fieldNumber: 1)
        }
        if estimatedAvgCalories != 0 {
            try visitor.visitSingularInt32Field(value: estimatedAvgCalories, fieldNumber: 2)
        }
        if !ingredients.isEmpty {
            try visitor.visitRepeatedStringField(value: ingredients, fieldNumber: 3)
        }
        if totalAvgWeight != 0 {
            try visitor.visitSingularInt32Field(value: totalAvgWeight, fieldNumber: 4)
        }
        try unknownFields.traverse(visitor: &visitor)
    }

    static func == (lhs: Dish, rhs: Dish) -> Bool {
        if lhs.dishName != rhs.dishName { return false }
        if lhs.estimatedAvgCalories != rhs.estimatedAvgCalories { return false }
        if lhs.ingredients != rhs.ingredients { return false }
        if lhs.totalAvgWeight != rhs.totalAvgWeight { return false }
        if lhs.unknownFields != rhs.unknownFields { return false }
        return true
    }
}

extension TotalForDay: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName: String = "TotalForDay"
    static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
        1: .same(proto: "contains"),
        2: .standard(proto: "total_avg_weight"),
        3: .standard(proto: "total_calories"),
    ]

    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            // The use of inline closures is to circumvent an issue where the compiler
            // allocates stack space for every case branch when no optimizations are
            // enabled. https://github.com/apple/swift-protobuf/issues/1034
            switch fieldNumber {
            case 1: try decoder.decodeSingularMessageField(value: &_contains)
            case 2: try decoder.decodeSingularInt32Field(value: &totalAvgWeight)
            case 3: try decoder.decodeSingularInt32Field(value: &totalCalories)
            default: break
            }
        }
    }

    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        // The use of inline closures is to circumvent an issue where the compiler
        // allocates stack space for every if/case branch local when no optimizations
        // are enabled. https://github.com/apple/swift-protobuf/issues/1034 and
        // https://github.com/apple/swift-protobuf/issues/1182
        try { if let v = self._contains {
            try visitor.visitSingularMessageField(value: v, fieldNumber: 1)
        } }()
        if totalAvgWeight != 0 {
            try visitor.visitSingularInt32Field(value: totalAvgWeight, fieldNumber: 2)
        }
        if totalCalories != 0 {
            try visitor.visitSingularInt32Field(value: totalCalories, fieldNumber: 3)
        }
        try unknownFields.traverse(visitor: &visitor)
    }

    static func == (lhs: TotalForDay, rhs: TotalForDay) -> Bool {
        if lhs._contains != rhs._contains { return false }
        if lhs.totalAvgWeight != rhs.totalAvgWeight { return false }
        if lhs.totalCalories != rhs.totalCalories { return false }
        if lhs.unknownFields != rhs.unknownFields { return false }
        return true
    }
}

extension TodayFood: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName: String = "TodayFood"
    static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
        1: .standard(proto: "dishes_today"),
        2: .standard(proto: "total_for_day"),
    ]

    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            // The use of inline closures is to circumvent an issue where the compiler
            // allocates stack space for every case branch when no optimizations are
            // enabled. https://github.com/apple/swift-protobuf/issues/1034
            switch fieldNumber {
            case 1: try decoder.decodeRepeatedMessageField(value: &dishesToday)
            case 2: try decoder.decodeSingularMessageField(value: &_totalForDay)
            default: break
            }
        }
    }

    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        // The use of inline closures is to circumvent an issue where the compiler
        // allocates stack space for every if/case branch local when no optimizations
        // are enabled. https://github.com/apple/swift-protobuf/issues/1034 and
        // https://github.com/apple/swift-protobuf/issues/1182
        if !dishesToday.isEmpty {
            try visitor.visitRepeatedMessageField(value: dishesToday, fieldNumber: 1)
        }
        try { if let v = self._totalForDay {
            try visitor.visitSingularMessageField(value: v, fieldNumber: 2)
        } }()
        try unknownFields.traverse(visitor: &visitor)
    }

    static func == (lhs: TodayFood, rhs: TodayFood) -> Bool {
        if lhs.dishesToday != rhs.dishesToday { return false }
        if lhs._totalForDay != rhs._totalForDay { return false }
        if lhs.unknownFields != rhs.unknownFields { return false }
        return true
    }
}
