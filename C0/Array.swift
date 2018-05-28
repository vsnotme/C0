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

import struct Foundation.Locale

typealias AbstractElement = AbstractViewable & Codable & Referenceable

struct ArrayIndex<T>: Codable, Hashable {
    var index = 0
}

extension Array {
    subscript(arrayIndex: ArrayIndex<Element>) -> Element {
        get { return self[arrayIndex.index] }
        set { self[arrayIndex.index] = newValue }
    }
}
extension Array: Referenceable where Element: Referenceable {
    static var name: Text {
        return "[" + Element.name + "]"
    }
}

enum ArrayNotification<Model> {
    case insert(Int, Model)
    case remove(Int)
    case move(Int, Model)
}

final class ObjectsView<T: AbstractElement, U: BinderProtocol>: View, BindableReceiver {
    typealias ModelElement = T
    typealias Model = [ModelElement]
    typealias Binder = U
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((ObjectsView<ModelElement, Binder>, BasicNotification) -> ())]()
    
    var defaultModel = Model()
    
    var sizeType: SizeType {
        didSet { updateLayout() }
    }
    var abstractType: AbstractType {
        didSet { updateChildren() }
    }
    
    var modelViews: [View]
    
    init(binder: Binder, keyPath: BinderKeyPath,
         frame: Rect = Rect(), sizeType: SizeType = .regular,
         abstractType: AbstractType = .normal) {
        
        self.binder = binder
        self.keyPath = keyPath
        
        self.sizeType = sizeType
        self.abstractType = abstractType
        
        modelViews = ObjectsView.modelViewsWith(model: binder[keyPath: keyPath],
                                                binder: binder, keyPath: keyPath,
                                                sizeType: sizeType, type: abstractType)
        
        super.init()
        isClipped = true
        updateChildren()
        self.frame = frame
    }
    
    var layoutClosure: ((Model, [View]) -> ())?
    override func updateLayout() {
        layoutClosure?(model, modelViews)
    }
    func updateChildren() {
        modelViews = ObjectsView.modelViewsWith(model: model,
                                                binder: binder, keyPath: keyPath,
                                                sizeType: sizeType, type: abstractType)
        self.children = modelViews
    }
    static func modelViewsWith(model: Model, binder: Binder, keyPath: BinderKeyPath,
                               sizeType: SizeType, type: AbstractType) -> [View] {
        return model.enumerated().map { (i, element) in
            return element.abstractViewWith(binder: binder,
                                            keyPath: keyPath.appending(path: \Model[i]),
                                            frame: Rect(), sizeType, type: type)
        }
    }
    func updateWithModel() {
        updateChildren()
    }
    
    func append(_ element: ModelElement, _ version: Version) {
        var model = self.model
        model.append(element)
        push(model, to: version)
    }
    func insert(_ element: ModelElement, at index: Int, _ version: Version) {
        var model = self.model
        model.insert(element, at: index)
        push(model, to: version)
    }
    func remove(at index: Int, _ version: Version) {
        var model = self.model
        model.remove(at: index)
        push(model, to: version)
    }
}
extension ObjectsView: Assignable {
    func reset(for p: Point, _ version: Version) {
        push(defaultModel, to: version)
    }
    func copiedObjects(at p: Point) -> [Object] {
        return [Object(model)]
    }
    func paste(_ objects: [Any], for p: Point, _ version: Version) {
        for object in objects {
            if let model = object as? Model {
                push(model, to: version)
                return
            }
        }
    }
}

typealias ArrayCountElement = Equatable & Codable & Referenceable

final class ArrayCountView<T: ArrayCountElement, U: BinderProtocol>: View, BindableReceiver {
    typealias ModelElement = T
    typealias Model = [ModelElement]
    typealias Binder = U
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((ArrayCountView<ModelElement, Binder>, BasicNotification) -> ())]()
    
    let countView: IntGetterView<Binder>
    
    var sizeType: SizeType {
        didSet { updateLayout() }
    }
    var width = 40.0.cg {
        didSet { updateLayout() }
    }
    let classNameView: TextFormView
    let countNameView: TextFormView
    
    init(binder: Binder, keyPath: BinderKeyPath,
         frame: Rect = Rect(), sizeType: SizeType = .regular) {
        
        self.binder = binder
        self.keyPath = keyPath
        
        self.sizeType = sizeType
        classNameView = TextFormView(text: Model.name, font: Font.bold(with: sizeType))
        countNameView = TextFormView(text: Text(english: "Count:", japanese: "個数:"),
                                     font: Font.default(with: sizeType))
        countView = IntGetterView(binder: binder, keyPath: keyPath.appending(path: \Model.count),
                                  option: IntGetterOption(unit: ""), sizeType: sizeType)
        
        super.init()
        isClipped = true
        children = [classNameView, countNameView, countView]
        self.frame = frame
    }
    
    override var defaultBounds: Rect {
        let padding = Layout.padding(with: sizeType), h = Layout.height(with: sizeType)
        let w = classNameView.frame.width + countNameView.frame.width + width + padding * 3
        return Rect(x: 0, y: 0, width: w, height: h)
    }
    override func updateLayout() {
        let padding = Layout.padding(with: sizeType), h = Layout.height(with: sizeType)
        classNameView.frame.origin = Point(x: padding,
                                           y: bounds.height - classNameView.frame.height - padding)
        countNameView.frame.origin = Point(x: classNameView.frame.maxX + padding,
                                           y: padding)
        countView.frame = Rect(x: countNameView.frame.maxX, y: padding,
                               width: width, height: h - padding * 2)
        updateWithModel()
    }
    func updateWithModel() {
        countView.updateWithModel()
    }
}
extension ArrayCountView: Localizable {
    func update(with locale: Locale) {
        updateLayout()
    }
}
extension ArrayCountView: Copiable {
    func copiedObjects(at p: Point) -> [Object] {
        return [Object(model)]
    }
}
