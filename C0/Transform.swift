/*
 Copyright 2017 S
 
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

struct Transform: Codable, Initializable {//OrderedAfineTransform transformItems
    var translation: Point {
        didSet {
            affineTransform = Transform.affineTransform(translation: translation,
                                                        scale: scale, rotation: rotation)
        }
    }
    var scale: Point {
        get {
            return _scale
        }
        set {
            _scale = newValue
            _z = log2(newValue.x)
            affineTransform = Transform.affineTransform(translation: translation,
                                                        scale: scale, rotation: rotation)
        }
    }
    var z: Real {
        get {
            return _z
        }
        set {
            _z = newValue
            let pow2 = pow(2, z)
            _scale = Point(x: pow2, y: pow2)
            affineTransform = Transform.affineTransform(translation: translation,
                                                        scale: scale, rotation: rotation)
        }
    }
    private var _scale: Point, _z: Real
    var rotation: Real {
        didSet {
            affineTransform = Transform.affineTransform(translation: translation,
                                                        scale: scale, rotation: rotation)
        }
    }
    private(set) var affineTransform: CGAffineTransform
    
    init() {
        translation = Point()
        _z = 0
        _scale = Point(x: 1, y: 1)
        rotation = 0
        affineTransform = Transform.affineTransform(translation: translation,
                                                    scale: _scale, rotation: rotation)
    }
    init(translation: Point = Point(), z: Real, rotation: Real = 0) {
        let pow2 = pow(2, z)
        self.translation = translation
        _scale = Point(x: pow2, y: pow2)
        _z = z
        self.rotation = rotation
        affineTransform = Transform.affineTransform(translation: translation,
                                                    scale: _scale, rotation: rotation)
    }
    init(translation: Point = Point(), scale: Point, rotation: Real = 0) {
        self.translation = translation
        _z = log2(scale.x)
        _scale = scale
        self.rotation = rotation
        affineTransform = Transform.affineTransform(translation: translation,
                                                    scale: scale, rotation: rotation)
    }
    private init(translation: Point, z: Real, scale: Point, rotation: Real) {
        self.translation = translation
        _z = z
        _scale = scale
        self.rotation = rotation
        affineTransform = Transform.affineTransform(translation: translation,
                                                    scale: scale, rotation: rotation)
    }
    
    private static func affineTransform(translation: Point,
                                        scale: Point, rotation: Real) -> CGAffineTransform {
        var affine = CGAffineTransform(translationX: translation.x, y: translation.y)
        if rotation != 0 {
            affine = affine.rotated(by: rotation)
        }
        if scale != Point() {
            affine = affine.scaledBy(x: scale.x, y: scale.y)
        }
        return affine
    }
    
    var isIdentity: Bool {
        return translation == Point() && scale == Point(x: 1, y: 1) && rotation == 0
    }
}
extension Transform {
    static let zOption = RealOption(defaultModel: 0, minModel: -20, maxModel: 20,
                                    modelInterval: 0.01, exp: 1,
                                    numberOfDigits: 2, unit: "")
    static let thetaOption = RealOption(defaultModel: 0,
                                        minModel: -10000, maxModel: 10000,
                                        modelInterval: 0.5, exp: 1,
                                        numberOfDigits: 1, unit: "°")
}
extension Transform: Equatable {
    static func ==(lhs: Transform, rhs: Transform) -> Bool {
        return lhs.translation == rhs.translation
            && lhs.scale == rhs.scale && lhs.rotation == rhs.rotation
    }
}
extension Transform: Interpolatable {
    static func linear(_ f0: Transform, _ f1: Transform, t: Real) -> Transform {
        let translation = Point.linear(f0.translation, f1.translation, t: t)
        let scaleX = Real.linear(f0.scale.x, f1.scale.x, t: t)
        let scaleY = Real.linear(f0.scale.y, f1.scale.y, t: t)
        let rotation = Real.linear(f0.rotation, f1.rotation, t: t)
        return Transform(translation: translation,
                         scale: Point(x: scaleX, y: scaleY), rotation: rotation)
    }
    static func firstMonospline(_ f1: Transform, _ f2: Transform, _ f3: Transform,
                                with ms: Monospline) -> Transform {
        let translation = Point.firstMonospline(f1.translation, f2.translation,
                                                f3.translation, with: ms)
        let scaleX = Real.firstMonospline(f1.scale.x, f2.scale.x, f3.scale.x, with: ms)
        let scaleY = Real.firstMonospline(f1.scale.y, f2.scale.y, f3.scale.y, with: ms)
        let rotation = Real.firstMonospline(f1.rotation, f2.rotation, f3.rotation, with: ms)
        return Transform(translation: translation,
                         scale: Point(x: scaleX, y: scaleY), rotation: rotation)
    }
    static func monospline(_ f0: Transform, _ f1: Transform, _ f2: Transform, _ f3: Transform,
                           with ms: Monospline) -> Transform {
        let translation = Point.monospline(f0.translation, f1.translation,
                                           f2.translation, f3.translation, with: ms)
        let scaleX = Real.monospline(f0.scale.x, f1.scale.x, f2.scale.x, f3.scale.x, with: ms)
        let scaleY = Real.monospline(f0.scale.y, f1.scale.y, f2.scale.y, f3.scale.y, with: ms)
        let rotation = Real.monospline(f0.rotation, f1.rotation, f2.rotation, f3.rotation, with: ms)
        return Transform(translation: translation,
                         scale: Point(x: scaleX, y: scaleY), rotation: rotation)
    }
    static func lastMonospline(_ f0: Transform, _ f1: Transform, _ f2: Transform,
                               with ms: Monospline) -> Transform {
        let translation = Point.lastMonospline(f0.translation, f1.translation,
                                               f2.translation, with: ms)
        let scaleX = Real.lastMonospline(f0.scale.x, f1.scale.x, f2.scale.x, with: ms)
        let scaleY = Real.lastMonospline(f0.scale.y, f1.scale.y, f2.scale.y, with: ms)
        let rotation = Real.lastMonospline(f0.rotation, f1.rotation, f2.rotation, with: ms)
        return Transform(translation: translation,
                         scale: Point(x: scaleX, y: scaleY), rotation: rotation)
    }
}
extension Transform: Referenceable {
    static let name = Text(english: "Transform", japanese: "トランスフォーム")
}
extension Transform: KeyframeValue {}
extension Transform: MiniViewable {
    func thumbnailView(withFrame frame: Rect, _ sizeType: SizeType) -> View {
        return View(isLocked: true)
    }
}

struct TransformTrack: Track, Codable {
    private(set) var animation = Animation<Transform>()
    var animatable: Animatable {
        return animation
    }
}
extension TransformTrack: Referenceable {
    static let name = Text(english: "Transform Track", japanese: "トランスフォームトラック")
}

final class TransformView: View {
    var transform = Transform() {
        didSet {
            if transform != oldValue {
                updateWithTransform()
            }
        }
    }
    
    var standardTranslation = Point(x: 1, y: 1)
    
    let translationView = DiscretePointView(xInterval: 0.01, xNumberOfDigits: 2,
                                            yInterval: 0.01, yNumberOfDigits: 2,
                                            sizeType: .regular)
    let zView = DiscreteRealView(model: 0, option: Transform.zOption,
                                 frame: Layout.valueFrame(with: .regular))
    let thetaView = DiscreteRealView(model: 0, option: Transform.thetaOption,
                                     frame: Layout.valueFrame(with: .regular))
    
    private let classNameView = TextView(text: Transform.name, font: .bold)
    private let classZNameView = TextView(text: "z:")
    private let classRotationNameView = TextView(text: "θ:")
    
    override init() {
        super.init()
        children = [classNameView,
                    translationView,
                    classZNameView, zView,
                    classRotationNameView, thetaView]
        
        translationView.binding = { [unowned self] in self.setTransform(with: $0) }
        zView.binding = { [unowned self] in self.setTransform(with: $0) }
        thetaView.binding = { [unowned self] in self.setTransform(with: $0) }
    }
    
    override var defaultBounds: Rect {
        let padding = Layout.basicPadding
        let w = MaterialView.defaultWidth + padding * 2
        let h = Layout.basicHeight * 2 + classNameView.frame.height + padding * 3
        return Rect(x: 0, y: 0, width: w, height: h)
    }
    override func updateLayout() {
        let padding = Layout.basicPadding
        var y = bounds.height - padding - classNameView.frame.height
        classNameView.frame.origin = Point(x: padding, y: y)
        y -= Layout.basicHeight + Layout.basicPadding
        _ = Layout.leftAlignment([.view(classZNameView), .view(zView), .xPadding(padding),
                                  .view(classRotationNameView), .view(thetaView)],
                                 y: y, height: Layout.basicHeight)
        let tdb = translationView.defaultBounds
        translationView.frame = Rect(x: bounds.width - Layout.basicPadding - tdb.width, y: padding,
                                     width: tdb.width, height: tdb.height)
    }
    private func updateWithTransform() {
        translationView.point = transform.translation
        zView.model = transform.z
        thetaView.model = transform.rotation * 180 / (.pi)
    }
    
    struct Binding {
        let transformView: TransformView
        let transform: Transform, oldTransform: Transform, phase: Phase
    }
    var binding: ((Binding) -> ())?
    
    private var oldTransform = Transform()
    private func setTransform(with obj: DiscretePointView.Binding) {
        if obj.phase == .began {
            oldTransform = transform
            binding?(Binding(transformView: self,
                             transform: oldTransform, oldTransform: oldTransform, phase: .began))
        } else {
            transform.translation = obj.point
            binding?(Binding(transformView: self,
                             transform: transform, oldTransform: oldTransform, phase: obj.phase))
        }
    }
    private func setTransform(with obj: DiscreteRealView.Binding<Real>) {
        if obj.phase == .began {
            oldTransform = transform
            binding?(Binding(transformView: self,
                             transform: oldTransform, oldTransform: oldTransform, phase: .began))
        } else {
            switch obj.view {
            case zView:
                transform.z = obj.model
            case thetaView:
                transform.rotation = obj.model * (.pi / 180)
            default:
                fatalError("No case")
            }
            binding?(Binding(transformView: self,
                             transform: transform, oldTransform: oldTransform, phase: obj.phase))
        }
    }
    
    private func push(_ transform: Transform) {
//        registeringUndoManager?.registerUndo(withTarget: self) {
//            $0.set(oldTransform, oldTransform: transform)
//        }
        self.transform = transform
    }
}
extension TransformView: Localizable {
    func update(with locale: Locale) {
        updateLayout()
    }
}
extension TransformView: Queryable {
    static let referenceableType: Referenceable.Type = Transform.self
}
extension TransformView: Assignable {
    func delete(for p: Point) {
        push(Transform())
    }
    func copiedObjects(at p: Point) -> [Viewable] {
        return [transform]
    }
    func paste(_ objects: [Object], for p: Point) {
        for object in objects {
            if let transform = object as? Transform {
                push(transform)
                return
            }
        }
    }
}
