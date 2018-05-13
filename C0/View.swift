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
import CoreGraphics
import QuartzCore

struct Screen {
    static var shared = Screen()
    var backingScaleFactor = 1.0.cg
}

/**
 Issue: CoreGraphicsとQuartzCoreを廃止し、VulkanまたはMetalでGPUレンダリング
 Issue: リニアワークフロー、マクロ拡散光
 */
class View {
    static var selection: View {
        let view = View(isLocked: true)
        view.fillColor = .select
        view.lineColor = .selectBorder
        return view
    }
    static var deselection: View {
        let view = View(isLocked: true)
        view.fillColor = .deselect
        view.lineColor = .deselectBorder
        return view
    }
    static func knob(radius: Real = 5, lineWidth: Real = 1) -> View {
        let view = View(isLocked: true)
        view.fillColor = .knob
        view.lineColor = .getSetBorder
        view.lineWidth = lineWidth
        view.radius = radius
        return view
    }
    static func discreteKnob(_ size: Size = Size(width: 10, height: 10), lineWidth: Real = 1) -> View {
        let view = View(isLocked: true)
        view.fillColor = .knob
        view.lineColor = .getSetBorder
        view.lineWidth = lineWidth
        view.frame.size = size
        return view
    }
    
    fileprivate var caLayer: CALayer
    init() {
        caLayer = CALayer.interface()
    }
    init(isLocked: Bool) {
        self.isLocked = isLocked
        caLayer = CALayer.interface()
    }
    
    init(gradient: Gradient, isLocked: Bool = true) {
        self.isLocked = isLocked
        var actions = CALayer.disabledAnimationActions
        actions["colors"] = NSNull()
        actions["locations"] = NSNull()
        actions["startPoint"] = NSNull()
        actions["endPoint"] = NSNull()
        let caGradientLayer = CAGradientLayer()
        caGradientLayer.actions = actions
        caLayer = caGradientLayer
        self.gradient = gradient
        View.update(with: gradient, in: caGradientLayer)
    }
    var gradient: Gradient? {
        didSet {
            guard let gradient = gradient, let caGradientLayer = caLayer as? CAGradientLayer else {
                fatalError()
            }
            View.update(with: gradient, in: caGradientLayer)
        }
    }
    private static func update(with gradient: Gradient, in caGradientLayer: CAGradientLayer) {
        if gradient.values.isEmpty {
            caGradientLayer.colors = nil
            caGradientLayer.locations = nil
        } else {
            caGradientLayer.colors = gradient.values.map { $0.color.cg }
            caGradientLayer.locations = gradient.values.map { NSNumber(value: Double($0.location)) }
        }
        caGradientLayer.startPoint = gradient.startPoint
        caGradientLayer.endPoint = gradient.endPoint
    }
    
    init(path: CGPath, isLocked: Bool = true) {
        self.isLocked = isLocked
        let caShapeLayer = CAShapeLayer()
        var actions = CALayer.disabledAnimationActions
        actions["fillColor"] = NSNull()
        actions["strokeColor"] = NSNull()
        caShapeLayer.actions = actions
        caShapeLayer.fillColor = nil
        caShapeLayer.lineWidth = 0
        caShapeLayer.strokeColor = lineColor?.cg
        caShapeLayer.path = path
        caLayer = caShapeLayer
    }
    var path: CGPath? {
        get {
            guard let caShapeLayer = caLayer as? CAShapeLayer else {
                return nil
            }
            return caShapeLayer.path
        }
        set {
            guard let caShapeLayer = caLayer as? CAShapeLayer else { fatalError() }
            caShapeLayer.path = newValue
            changed(frame)
        }
    }
    
    init(drawClosure: ((CGContext, View) -> ())?,
         fillColor: Color? = .background, lineColor: Color? = .getSetBorder, isLocked: Bool = true) {
        
        self.isLocked = isLocked
        let caDrawLayer = C0DrawLayer()
        caLayer = caDrawLayer
        self.fillColor = fillColor
        self.lineColor = lineColor
        self.drawClosure = drawClosure
        caDrawLayer.backgroundColor = fillColor?.cg
        caDrawLayer.borderColor = lineColor?.cg
        caDrawLayer.borderWidth = lineColor == nil ? 0 : lineWidth
        caDrawLayer.drawClosure = { [unowned self] ctx in self.drawClosure?(ctx, self) }
    }
    var drawClosure: ((CGContext, View) -> ())? {
        didSet {
            (caLayer as! C0DrawLayer).drawClosure = { [unowned self] ctx in
                self.drawClosure?(ctx, self)
            }
        }
    }
    func draw() {
        caLayer.setNeedsDisplay()
    }
    func draw(_ rect: Rect) {
        caLayer.setNeedsDisplay(rect)
    }
    func draw(in ctx: CGContext) {
        caLayer.draw(in: ctx)
    }
    func render(in ctx: CGContext) {
        (caLayer as! C0DrawLayer).safetyRender(in: ctx)
    }
    
    private(set) weak var parent: View?
    private var _children = [View]()
    var children: [View] {
        get {
            return _children
        }
        set {
            let oldChildren = _children
            oldChildren.forEach { child in
                if !newValue.contains(where: { $0 === child }) {
                    child.removeFromParent()
                }
            }
            caLayer.sublayers = newValue.compactMap { $0.caLayer }
            _children = newValue
            newValue.forEach { child in
                child.parent = self
                child.allChildrenAndSelf { $0.contentsScale = contentsScale }
            }
        }
    }
    func append(child: View) {
        child.removeFromParent()
        caLayer.addSublayer(child.caLayer)
        _children.append(child)
        child.parent = self
        child.allChildrenAndSelf { $0.contentsScale = contentsScale }
    }
    func insert(child: View, at index: Int) {
        child.removeFromParent()
        caLayer.insertSublayer(child.caLayer, at: UInt32(index))
        _children.insert(child, at: index)
        child.parent = self
        child.allChildrenAndSelf { $0.contentsScale = contentsScale }
    }
    func removeFromParent() {
        guard let parent = parent else { return }
        caLayer.removeFromSuperlayer()
        if let index = parent._children.index(where: { $0 === self }) {
            parent._children.remove(at: index)
        }
        self.parent = nil
    }
    
    func allChildrenAndSelf(_ closure: (View) -> Void) {
        func allChildrenRecursion(_ child: View, _ closure: (View) -> Void) {
            child._children.forEach { allChildrenRecursion($0, closure) }
            closure(child)
        }
        allChildrenRecursion(self, closure)
    }
    func selfAndAllParents(closure: (View, inout Bool) -> Void) {
        var stop = false
        closure(self, &stop)
        guard !stop else { return }
        parent?.selfAndAllParents(closure: closure)
    }
    var root: View {
        return parent?.root ?? self
    }
    
    var defaultBounds: Rect {
        return Rect()
    }
    private var isUseDidSetBounds = true, isUseDidSetFrame = true
    var bounds = Rect() {
        didSet {
            guard isUseDidSetBounds && bounds != oldValue else { return }
            if frame.size != bounds.size {
                isUseDidSetFrame = false
                frame.size = bounds.size
                isUseDidSetFrame = true
            }
            caLayer.bounds = bounds
            updateLayout()
        }
    }
    var frame = Rect() {
        didSet {
            guard isUseDidSetFrame && frame != oldValue else { return }
            if bounds.size != frame.size {
                isUseDidSetBounds = false
                bounds.size = frame.size
                isUseDidSetBounds = true
            }
            caLayer.frame = frame
            changed(frame)
            updateLayout()
        }
    }
    var position: Point {
        get {
            return caLayer.position
        }
        set {
            caLayer.position = newValue
            changed(frame)
            updateLayout()
        }
    }
    
    func updateLayout() {}
    
    var changedFrame: ((Rect) -> ())?
    func changed(_ frame: Rect) {
        guard !isLocked else { return }
        changedFrame?(frame)
        if let parent = parent {
            parent.changed(convert(frame, to: parent))
        }
    }
    
    var isHidden: Bool {
        get {
            return caLayer.isHidden
        }
        set {
            caLayer.isHidden = newValue
            changed(frame)
        }
    }
    var effect = Effect() {
        didSet {
            guard effect != oldValue else { return }
            
            if effect.opacity != oldValue.opacity {
                caLayer.opacity = Float(effect.opacity)
            }
            if effect.blurRadius != oldValue.blurRadius {
                if effect.blurRadius > 0 {
                    if let filter = CIFilter(name: "CIGaussianBlur") {
                        filter.setValue(Float(effect.blurRadius), forKey: kCIInputRadiusKey)
                        caLayer.filters = [filter]
                    }
                } else if caLayer.filters != nil {
                    caLayer.filters = nil
                }
            }
            if effect.blendType != oldValue.blendType {
                switch effect.blendType {
                case .normal: caLayer.compositingFilter = nil
                case .addition: caLayer.compositingFilter = CIFilter(name: " CIAdditionCompositing")
                case .subtract: caLayer.compositingFilter = CIFilter(name: "CISubtractBlendMode")
                }
            }
        }
    }
    
    var radius: Real {
        get {
            return min(bounds.width, bounds.height) / 2
        }
        set {
            frame = Rect(x: position.x - newValue, y: position.y - newValue,
                         width: newValue * 2, height: newValue * 2)
            cornerRadius = newValue
        }
    }
    var cornerRadius: Real {
        get {
            return caLayer.cornerRadius
        }
        set {
            caLayer.cornerRadius = newValue
        }
    }
    var isClipped: Bool {
        get {
            return caLayer.masksToBounds
        }
        set {
            caLayer.masksToBounds = newValue
        }
    }
    
    var image: Image? {
        get {
            guard let contents = caLayer.contents else {
                return nil
            }
            return Image(contents as! CGImage)
        }
        set {
            caLayer.contents = newValue?.cg
            if newValue != nil {
                caLayer.minificationFilter = kCAFilterTrilinear
                caLayer.magnificationFilter = kCAFilterTrilinear
            } else {
                caLayer.minificationFilter = kCAFilterLinear
                caLayer.magnificationFilter = kCAFilterLinear
            }
        }
    }
    
    var fillColor: Color? {
        didSet {
            guard fillColor != oldValue else { return }
            set(fillColor: fillColor?.cg)
        }
    }
    private func set(fillColor: CGColor?) {
        if let caShapeLayer = caLayer as? CAShapeLayer {
            caShapeLayer.fillColor = fillColor
        } else {
            caLayer.backgroundColor = fillColor
        }
    }
    var contentsScale: Real {
        get {
            return caLayer.contentsScale
        }
        set {
            guard newValue != caLayer.contentsScale else { return }
            caLayer.contentsScale = newValue
        }
    }
    
    var lineColor: Color? = .getSetBorder {
        didSet {
            guard lineColor != oldValue else { return }
            set(lineWidth: lineColor != nil ? lineWidth : 0)
            set(lineColor: lineColor?.cg)
        }
    }
    var lineWidth = 0.5.cg {
        didSet {
            set(lineWidth: lineColor != nil ? lineWidth : 0)
        }
    }
    private func set(lineColor: CGColor?) {
        if let caShapeLayer = caLayer as? CAShapeLayer {
            caShapeLayer.strokeColor = lineColor
        } else {
            caLayer.borderColor = lineColor
        }
    }
    private func set(lineWidth: Real) {
        if let caShapeLayer = caLayer as? CAShapeLayer {
            caShapeLayer.lineWidth = lineWidth
        } else {
            caLayer.borderWidth = lineWidth
        }
    }
    
    var isLocked = false
    
    func containsPath(_ p: Point) -> Bool {
        if let path = path {
            return path.contains(p)
        } else {
            return bounds.contains(p)
        }
    }
    func contains(_ p: Point) -> Bool {
        return !isLocked && !isHidden && containsPath(p)
    }
    func at(_ p: Point) -> View? {
        guard !(isLocked && _children.isEmpty) else {
            return nil
        }
        guard containsPath(p) && !isHidden else {
            return nil
        }
        for child in _children.reversed() {
            let inPoint = child.convert(p, from: self)
            if let view = child.at(inPoint) {
                return view
            }
        }
        return isLocked ? nil : self
    }
    func at<T>(_ p: Point, _ type: T.Type) -> T? {
        return at(p)?.withSelfAndAllParents(with: type)
    }
    func withSelfAndAllParents<T>(with type: T.Type) -> T? {
        var t: T?
        selfAndAllParents { (view, stop) in
            if !view.isLocked, let at = view as? T {
                t = at
                stop = true
            }
        }
        return t
    }
    
    func convertFromRoot(_ point: Point) -> Point {
        return point - convertToRoot(Point(), stop: nil).point
    }
    func convert(_ point: Point, from view: View) -> Point {
        guard self !== view else {
            return point
        }
        let result = view.convertToRoot(point, stop: self)
        return !result.isRoot ?
            result.point : result.point - convertToRoot(Point(), stop: nil).point
    }
    func convertToRoot(_ point: Point) -> Point {
        return convertToRoot(point, stop: nil).point
    }
    func convert(_ point: Point, to view: View) -> Point {
        guard self !== view else {
            return point
        }
        let result = convertToRoot(point, stop: view)
        return !result.isRoot ?
            result.point : result.point - view.convertToRoot(Point(), stop: nil).point
    }
    private func convertToRoot(_ point: Point,
                               stop view: View?) -> (point: Point, isRoot: Bool) {
        if let parent = parent {
            let parentPoint = point - bounds.origin + frame.origin
            return parent === view ?
                (parentPoint, false) : parent.convertToRoot(parentPoint, stop: view)
        } else {
            return (point, true)
        }
    }
    
    func convertFromRoot(_ rect: Rect) -> Rect {
        return Rect(origin: convertFromRoot(rect.origin), size: rect.size)
    }
    func convert(_ rect: Rect, from view: View) -> Rect {
        return Rect(origin: convert(rect.origin, from: view), size: rect.size)
    }
    func convertToRoot(_ rect: Rect) -> Rect {
        return Rect(origin: convertToRoot(rect.origin), size: rect.size)
    }
    func convert(_ rect: Rect, to view: View) -> Rect {
        return Rect(origin: convert(rect.origin, to: view), size: rect.size)
    }
    
    var isIndicated = false {
        didSet { updateLineColorWithIsIndicated() }
    }
    var noIndicatedLineColor: Color? = .getSetBorder {
        didSet { updateLineColorWithIsIndicated() }
    }
    var indicatedLineColor: Color? = .indicated {
        didSet { updateLineColorWithIsIndicated() }
    }
    private func updateLineColorWithIsIndicated() {
        lineColor = isIndicated ? indicatedLineColor : noIndicatedLineColor
    }
    
    var isSubIndicated = false
    weak var subIndicatedParent: View?
    func allSubIndicatedParentsAndSelf(closure: (View) -> Void) {
        closure(self)
        (subIndicatedParent ?? parent)?.allSubIndicatedParentsAndSelf(closure: closure)
    }
}
extension View: Equatable {
    static func ==(lhs: View, rhs: View) -> Bool {
        return lhs === rhs
    }
}

private final class C0DrawLayer: CALayer {
    init(backgroundColor: Color? = .background, borderColor: Color? = .getSetBorder) {
        super.init()
        self.needsDisplayOnBoundsChange = true
        self.drawsAsynchronously = true
        self.anchorPoint = Point()
        self.isOpaque = backgroundColor != nil
        self.borderWidth = borderColor == nil ? 0 : 0.5
        self.backgroundColor = backgroundColor?.cg
        self.borderColor = borderColor?.cg
    }
    override init(layer: Any) {
        super.init(layer: layer)
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func action(forKey event: String) -> CAAction? {
        return nil
    }
    override var backgroundColor: CGColor? {
        didSet {
            self.isOpaque = backgroundColor != nil
            setNeedsDisplay()
        }
    }
    override var contentsScale: Real {
        didSet {
            setNeedsDisplay()
        }
    }
    var drawClosure: ((CGContext) -> ())?
    override func draw(in ctx: CGContext) {
        if let backgroundColor = backgroundColor {
            ctx.setFillColor(backgroundColor)
            ctx.fill(ctx.boundingBoxOfClipPath)
        }
        drawClosure?(ctx)
    }
    func safetySetNeedsDisplay(_ closure: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        closure()
        setNeedsDisplay()
        CATransaction.commit()
    }
}

extension CALayer {
    static let disabledAnimationActions = ["backgroundColor": NSNull(),
                                           "content": NSNull(),
                                           "sublayers": NSNull(),
                                           "frame": NSNull(),
                                           "bounds": NSNull(),
                                           "position": NSNull(),
                                           "hidden": NSNull(),
                                           "opacity": NSNull(),
                                           "borderColor": NSNull(),
                                           "borderWidth": NSNull()]
    static var disabledAnimation: CALayer {
        let layer = CALayer()
        layer.actions = disabledAnimationActions
        return layer
    }
    static func interface(backgroundColor: Color? = nil,
                          borderColor: Color? = .getSetBorder) -> CALayer {
        let layer = CALayer()
        layer.isOpaque = true
        layer.actions = disabledAnimationActions
        layer.borderWidth = borderColor == nil ? 0.0 : 0.5
        layer.backgroundColor = backgroundColor?.cg
        layer.borderColor = borderColor?.cg
        return layer
    }
    func safetyRender(in ctx: CGContext) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        setNeedsDisplay()
        render(in: ctx)
        CATransaction.commit()
    }
}
extension CATransaction {
    static func disableAnimation(_ closure: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        closure()
        CATransaction.commit()
    }
}

extension CGAffineTransform {
    static func centering(from fromFrame: Rect,
                          to toFrame: Rect) -> (scale: Real, affine: CGAffineTransform) {
        guard !fromFrame.isEmpty && !toFrame.isEmpty else {
            return (1, CGAffineTransform.identity)
        }
        var affine = CGAffineTransform.identity
        let fromRatio = fromFrame.width / fromFrame.height
        let toRatio = toFrame.width / toFrame.height
        if fromRatio > toRatio {
            let xScale = toFrame.width / fromFrame.size.width
            let y = toFrame.origin.y + (toFrame.height - fromFrame.height * xScale) / 2
            affine = affine.translatedBy(x: toFrame.origin.x, y: y)
            affine = affine.scaledBy(x: xScale, y: xScale)
            return (xScale, affine.translatedBy(x: -fromFrame.origin.x, y: -fromFrame.origin.y))
        } else {
            let yScale = toFrame.height / fromFrame.size.height
            let x = toFrame.origin.x + (toFrame.width - fromFrame.width * yScale) / 2
            affine = affine.translatedBy(x: x, y: toFrame.origin.y)
            affine = affine.scaledBy(x: yScale, y: yScale)
            return (yScale, affine.translatedBy(x: -fromFrame.origin.x, y: -fromFrame.origin.y))
        }
    }
    func flippedHorizontal(by width: Real) -> CGAffineTransform {
        return translatedBy(x: width, y: 0).scaledBy(x: -1, y: 1)
    }
}
extension CGPath {
    static func checkerboard(with size: Size, in frame: Rect) -> CGPath {
        let path = CGMutablePath()
        path.addRects([Rect].checkerboard(with: size, in: frame))
        return path
    }
}
extension CGContext {
    static func bitmap(with size: Size,
                       _ cs: CGColorSpace? = CGColorSpace(name: CGColorSpace.sRGB)) -> CGContext? {
        guard let colorSpace = cs else {
            return nil
        }
        return CGContext(data: nil, width: Int(size.width), height: Int(size.height),
                         bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
                         bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)
    }
}
extension CGContext {
    func drawBlurWith(color fillColor: Color, width: Real, strength: Real,
                      isLuster: Bool, path: CGPath, scale: Real, rotation: Real) {
        let nFillColor: Color
        if fillColor.alpha < 1 {
            saveGState()
            setAlpha(Real(fillColor.alpha))
            nFillColor = fillColor.with(alpha: 1)
        } else {
            nFillColor = fillColor
        }
        let pathBounds = path.boundingBoxOfPath.insetBy(dx: -width, dy: -width)
        let lineColor = strength == 1 ? nFillColor : nFillColor.multiply(alpha: strength)
        beginTransparencyLayer(in: boundingBoxOfClipPath.intersection(pathBounds),
                               auxiliaryInfo: nil)
        if isLuster {
            setShadow(offset: Size(), blur: width * scale, color: lineColor.cg)
        } else {
            let shadowY = hypot(pathBounds.size.width, pathBounds.size.height)
            translateBy(x: 0, y: shadowY)
            let shadowOffset = Size(width: shadowY * scale * sin(rotation),
                                    height: -shadowY * scale * cos(rotation))
            setShadow(offset: shadowOffset, blur: width * scale / 2, color: lineColor.cg)
            setLineWidth(width)
            setLineJoin(.round)
            setStrokeColor(lineColor.cg)
            addPath(path)
            strokePath()
            translateBy(x: 0, y: -shadowY)
        }
        setFillColor(nFillColor.cg)
        addPath(path)
        fillPath()
        endTransparencyLayer()
        if fillColor.alpha < 1 {
            restoreGState()
        }
    }
    func drawBlur(withBlurRadius blurRadius: Real, to ctx: CGContext) {
        guard let image = makeImage() else { return }
        let ciImage = CIImage(cgImage: image)
        let cictx = CIContext(cgContext: ctx, options: nil)
        let filter = CIFilter(name: "CIGaussianBlur")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        filter?.setValue(Float(blurRadius), forKey: kCIInputRadiusKey)
        if let outputImage = filter?.outputImage {
            cictx.draw(outputImage,
                       in: ctx.boundingBoxOfClipPath,
                       from: Rect(origin: Point(), size: image.size))
        }
    }
}

extension C0View {
    func backingLayer(with view: View) -> CALayer {
        return view.caLayer
    }
}

enum SizeType {
    case small, regular
}

protocol ConcreteViewable {
    func concreteViewWith<T: BinderProtocol>(binder: T, keyPath: ReferenceWritableKeyPath<T, Self>,
                                             frame: Rect, _ sizeType: SizeType) -> View
}
protocol AbstractViewable {
    func abstractViewWith<T: BinderProtocol>(binder: T, keyPath: ReferenceWritableKeyPath<T, Self>,
                                             frame: Rect, _ sizeType: SizeType) -> View
}
protocol ThumbnailViewable {
    func thumbnailView(withFrame frame: Rect, _ sizeType: SizeType) -> View
}
protocol DisplayableText {
    var displayText: Text { get }
}
extension ThumbnailViewable where Self: DisplayableText {
    func thumbnailView(withFrame frame: Rect, _ sizeType: SizeType) -> View {
        return displayText.thumbnailView(withFrame: frame, sizeType)
    }
}
