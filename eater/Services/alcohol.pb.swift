// DO NOT EDIT.
// swift-format-ignore-file
// swiftlint:disable all
//
// Hand-crafted SwiftProtobuf definitions for Alcohol messages.
// These mirror the backend proto contract for alcohol endpoints.

import SwiftProtobuf

fileprivate struct _GeneratedWithProtocGenSwiftVersion: SwiftProtobuf.ProtobufAPIVersionCheck {
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
  var date: String = String()
  var drinkName: String = String()
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
  fileprivate var _todaySummary: Eater_AlcoholDaySummary? = nil
}

struct Eater_GetAlcoholRangeRequest: Sendable {
  /// dd-MM-yyyy
  var startDate: String = String()
  /// dd-MM-yyyy
  var endDate: String = String()
  var unknownFields = SwiftProtobuf.UnknownStorage()
  init() {}
}

struct Eater_GetAlcoholRangeResponse: Sendable {
  var events: [Eater_AlcoholEvent] = []
  var unknownFields = SwiftProtobuf.UnknownStorage()
  init() {}
}

// MARK: - SwiftProtobuf conformance

fileprivate let _protobuf_package = "eater"

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
      case 1: try { try decoder.decodeSingularInt32Field(value: &self.totalDrinks) }()
      case 2: try { try decoder.decodeSingularInt32Field(value: &self.totalCalories) }()
      case 3: try { try decoder.decodeRepeatedStringField(value: &self.drinksOfDay) }()
      default: break
      }
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    if self.totalDrinks != 0 { try visitor.visitSingularInt32Field(value: self.totalDrinks, fieldNumber: 1) }
    if self.totalCalories != 0 { try visitor.visitSingularInt32Field(value: self.totalCalories, fieldNumber: 2) }
    if !self.drinksOfDay.isEmpty { try visitor.visitRepeatedStringField(value: self.drinksOfDay, fieldNumber: 3) }
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
      case 1: try { try decoder.decodeSingularInt64Field(value: &self.time) }()
      case 2: try { try decoder.decodeSingularStringField(value: &self.date) }()
      case 3: try { try decoder.decodeSingularStringField(value: &self.drinkName) }()
      case 4: try { try decoder.decodeSingularInt32Field(value: &self.calories) }()
      case 5: try { try decoder.decodeSingularInt32Field(value: &self.quantity) }()
      default: break
      }
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    if self.time != 0 { try visitor.visitSingularInt64Field(value: self.time, fieldNumber: 1) }
    if !self.date.isEmpty { try visitor.visitSingularStringField(value: self.date, fieldNumber: 2) }
    if !self.drinkName.isEmpty { try visitor.visitSingularStringField(value: self.drinkName, fieldNumber: 3) }
    if self.calories != 0 { try visitor.visitSingularInt32Field(value: self.calories, fieldNumber: 4) }
    if self.quantity != 0 { try visitor.visitSingularInt32Field(value: self.quantity, fieldNumber: 5) }
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
      case 1: try { try decoder.decodeSingularMessageField(value: &self._todaySummary) }()
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
      case 1: try { try decoder.decodeSingularStringField(value: &self.startDate) }()
      case 2: try { try decoder.decodeSingularStringField(value: &self.endDate) }()
      default: break
      }
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    if !self.startDate.isEmpty { try visitor.visitSingularStringField(value: self.startDate, fieldNumber: 1) }
    if !self.endDate.isEmpty { try visitor.visitSingularStringField(value: self.endDate, fieldNumber: 2) }
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
      case 1: try { try decoder.decodeRepeatedMessageField(value: &self.events) }()
      default: break
      }
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    if !self.events.isEmpty { try visitor.visitRepeatedMessageField(value: self.events, fieldNumber: 1) }
    try unknownFields.traverse(visitor: &visitor)
  }

  static func == (lhs: Eater_GetAlcoholRangeResponse, rhs: Eater_GetAlcoholRangeResponse) -> Bool {
    if lhs.events != rhs.events { return false }
    if lhs.unknownFields != rhs.unknownFields { return false }
    return true
  }
}


