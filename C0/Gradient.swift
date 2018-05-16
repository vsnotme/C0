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

struct Gradient {
    struct Value {
        var color: Color
        var location: Real
    }
    
    var values = [Value]()
    var startPoint = Point(), endPoint = Point(x: 1, y: 0)
    
    var colors: [Color] {
        get {
            return values.map { $0.color }
        }
        set {
            newValue.enumerated().forEach { (i, color) in
                values[i].color = color
            }
        }
    }
    var locations: [Real] {
        get {
            return values.map { $0.location }
        }
        set {
            newValue.enumerated().forEach { (i, location) in
                values[i].location = location
            }
        }
    }
}
