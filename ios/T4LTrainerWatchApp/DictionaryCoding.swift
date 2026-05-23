import Foundation

enum DictionaryCoding {
  static func decode<T: Decodable>(_ type: T.Type, from value: Any) throws -> T {
    let data = try JSONSerialization.data(withJSONObject: value)
    return try JSONDecoder().decode(type, from: data)
  }

  static func encode<T: Encodable>(_ value: T) throws -> [String: Any] {
    let data = try JSONEncoder().encode(value)
    let object = try JSONSerialization.jsonObject(with: data)
    return object as? [String: Any] ?? [:]
  }
}
