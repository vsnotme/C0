/*
 Copyright 2018 S
 
 This file is part of C0.
 
 C0 is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 
 C0 is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with C0.  If not, see <http://www.gnu.org/licenses/>.
 */

import Foundation

protocol Localizable {
    var locale: Locale { get set }
}
struct Localization: Codable, Equatable {
    var baseLanguageCode: String, base: String, values: [String: String]
    init(baseLanguageCode: String, base: String, values: [String: String]) {
        self.baseLanguageCode = baseLanguageCode
        self.base = base
        self.values = values
    }
    init(_ noLocalizeString: String) {
        baseLanguageCode = "en"
        base = noLocalizeString
        values = [:]
    }
    init(english: String = "", japanese: String = "") {
        baseLanguageCode = "en"
        base = english
        values = ["ja": japanese]
    }
    var currentString: String {
        return string(with: Locale.current)
    }
    func string(with locale: Locale) -> String {
        if let languageCode = locale.languageCode, let value = values[languageCode] {
            return value
        }
        return base
    }
    var isEmpty: Bool {
        return base.isEmpty
    }
    func spacedUnion(_ other: Localization) -> Localization {
        var values = self.values
        if other.values.isEmpty {
            self.values.forEach { values[$0.key] = (values[$0.key] ?? "") + other.base }
        } else {
            for v in other.values {
                values[v.key] = (self.values[v.key] ?? self.base) + v.value
            }
        }
        return Localization(baseLanguageCode: baseLanguageCode,
                            base: base + " " + other.base,
                            values: values)
    }
    static func +(lhs: Localization, rhs: Localization) -> Localization {
        var values = lhs.values
        if rhs.values.isEmpty {
            lhs.values.forEach { values[$0.key] = (values[$0.key] ?? "") + rhs.base }
        } else {
            for v in rhs.values {
                values[v.key] = (lhs.values[v.key] ?? lhs.base) + v.value
            }
        }
        return Localization(baseLanguageCode: lhs.baseLanguageCode,
                            base: lhs.base + rhs.base,
                            values: values)
    }
    static func +=(lhs: inout Localization, rhs: Localization) {
        var values = lhs.values
        if rhs.values.isEmpty {
            lhs.values.forEach { values[$0.key] = (values[$0.key] ?? "") + rhs.base }
        } else {
            for v in rhs.values {
                values[v.key] = (lhs.values[v.key] ?? lhs.base) + v.value
            }
        }
        lhs.base = lhs.base + rhs.base
        lhs.values = values
    }
}
extension Localization: ExpressibleByStringLiteral {
    typealias StringLiteralType = String
    init(stringLiteral value: String) {
        self.init(value)
    }
}
extension Localization: Referenceable {
    static let name = Localization(english: "Text", japanese: "テキスト")
}
extension Localization: ObjectViewExpression {
    func thumbnail(withBounds bounds: Rect, _ sizeType: SizeType) -> View {
        return TextView(text: self, font: Font.default(with: sizeType),
                        frame: bounds, isSizeToFit: false)
    }
}
