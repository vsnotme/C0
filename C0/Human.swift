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
import QuartzCore

protocol HumanDelegate: class {
    func didChangeEditText(_ human: Human, oldEditText: Text?)
    func didChangeCursor(_ human: Human, cursor: Cursor, oldCursor: Cursor)
}
final class Human: Respondable {
    static let name = Localization(english: "Human", japanese: "人間")
    
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: oldValue)
        }
    }
    
    weak var delegate: HumanDelegate?
    
    final class Preference: NSObject, ClassCopyData {
        static let name = Localization(english: "Preference", japanese: "環境設定")
        
        var isHiddenAction = false
        
        var deepCopy: Preference {
            return Preference(isHiddenAction: isHiddenAction)
        }
        
        init(isHiddenAction: Bool = false) {
            self.isHiddenAction = isHiddenAction
        }
        
        static let isHiddenActionKey = "1"
        init?(coder: NSCoder) {
            isHiddenAction = coder.decodeBool(forKey: Preference.isHiddenActionKey)
            super.init()
        }
        func encode(with coder: NSCoder) {
            coder.encode(isHiddenAction, forKey: Preference.isHiddenActionKey)
        }
    }
    var preference = Preference() {
        didSet {
            actionEditor.isHiddenButton.selectionIndex = preference.isHiddenAction ? 1 : 0
            actionEditor.isHiddenActions = preference.isHiddenAction
            updateChildren()
        }
    }
    
    var worldDataModel: DataModel
    var preferenceDataModel = DataModel(key: preferenceDataModelKey)
    
    let vision = GroupResponder()
    let copyObjectEditor = CopyObjectEditor(), actionEditor = ActionEditor()
    let world = GroupResponder()
    let referenceEditor = ReferenceEditor()
    var editText: Text? {
        if let editText = indicationResponder as? Text {
            return editText.isLocked ? nil : editText
        } else {
            return nil
        }
    }
    var editQuasimode = EditQuasimode.none
    
    let sceneEditor = SceneEditor()
    
    init() {
        if let sceneEditorDataModel = sceneEditor.dataModel {
            worldDataModel = DataModel(key: Human.worldDataModelKey, directoryWithChildren: [sceneEditorDataModel])
        } else {
            worldDataModel = DataModel(key: Human.worldDataModelKey, directoryWithChildren: [])
        }
        self.dataModel = DataModel(key: Human.dataModelKey, directoryWithChildren: [preferenceDataModel, worldDataModel])
        
        self.indicationResponder = vision
        world.children = [sceneEditor]
        vision.children = [copyObjectEditor, actionEditor, world]
        
        self.actionEditor.isHiddenActionBinding = { [unowned self] in
            self.preference.isHiddenAction = $0
            self.updateChildren()
            self.preferenceDataModel.isWrite = true
        }
        preferenceDataModel.dataHandler = { [unowned self] in return self.preference.data }
    }
    static let dataModelKey = "human", worldDataModelKey = "world", preferenceDataModelKey = "preference"
    var dataModel: DataModel? {
        didSet {
            if let worldDataModel = dataModel?.children[Human.worldDataModelKey] {
                self.worldDataModel = worldDataModel
            }
            if let preferenceDataModel = dataModel?.children[Human.preferenceDataModelKey] {
                self.preferenceDataModel = preferenceDataModel
                if let preference: Preference = preferenceDataModel.readObject() {
                    self.preference = preference
                }
                preferenceDataModel.dataHandler = { [unowned self] in return self.preference.data }
            }
            if let sceneEditorDataModel = worldDataModel.children[SceneEditor.sceneEditorKey] {
                sceneEditor.dataModel = sceneEditorDataModel
            } else if let sceneEditorDataModel = sceneEditor.dataModel {
                worldDataModel.insert(sceneEditorDataModel)
            }
        }
    }
    
    var locale = Locale.current {
        didSet {
            if locale.languageCode != oldValue.languageCode {
                vision.allChildren { ($0 as? Localizable)?.locale = locale }
            }
        }
    }
    var sight: CGFloat = GlobalVariable.shared.backingScaleFactor {
        didSet {
            if sight != oldValue {
                vision.allChildren { ($0 as? LayerRespondable)?.contentsScale = sight }
            }
        }
    }
    var actionWidth = ActionEditor.defaultWidth, copyEditorHeight = Layout.basicHeight + Layout.basicPadding * 2
    var fieldOfVision = CGSize() {
        didSet {
            CATransaction.disableAnimation {
                vision.frame.size = fieldOfVision
            }
            updateChildren()
        }
    }
    
    func updateChildren() {
        CATransaction.disableAnimation {
            if preference.isHiddenAction {
                actionEditor.frame = CGRect(
                    x: Layout.basicPadding,
                    y: fieldOfVision.height - actionEditor.frame.height - Layout.basicPadding,
                    width: actionWidth, height: actionEditor.frame.height
                )
                copyObjectEditor.frame = CGRect(
                    x: Layout.basicPadding + actionWidth,
                    y: fieldOfVision.height - copyEditorHeight - Layout.basicPadding,
                    width: fieldOfVision.width - actionWidth - Layout.basicPadding * 2, height: copyEditorHeight
                )
                world.frame = CGRect(
                    x: Layout.basicPadding,
                    y: Layout.basicPadding,
                    width: vision.frame.width - Layout.basicPadding * 2,
                    height: vision.frame.height - copyEditorHeight - Layout.basicPadding * 2
                )
            } else {
                actionEditor.frame = CGRect(
                    x: Layout.basicPadding,
                    y: fieldOfVision.height - actionEditor.frame.height - Layout.basicPadding,
                    width: actionWidth, height: actionEditor.frame.height
                )
                copyObjectEditor.frame = CGRect(
                    x: Layout.basicPadding + actionWidth,
                    y: fieldOfVision.height - copyEditorHeight - Layout.basicPadding,
                    width: fieldOfVision.width - actionWidth - Layout.basicPadding * 2, height: copyEditorHeight
                )
                world.frame = CGRect(
                    x: Layout.basicPadding + actionWidth,
                    y: Layout.basicPadding,
                    width: vision.frame.width - (Layout.basicPadding * 2 + actionWidth),
                    height: vision.frame.height - copyEditorHeight - Layout.basicPadding * 2
                )
            }
            sceneEditor.frame.origin = CGPoint(
                x: round((world.frame.width - sceneEditor.frame.width) / 2),
                y: round((world.frame.height - sceneEditor.frame.height) / 2)
            )
        }
    }
    
    //Delegate UndoManager update
    var indicationResponder: Respondable {
        didSet {
            if indicationResponder !== oldValue {
                var allParents = [Respondable]()
                indicationResponder.allParents { allParents.append($0) }
                oldValue.allParents { responder in
                    if let index = allParents.index(where: { $0 === responder }) {
                        allParents.remove(at: index)
                    } else {
                        responder.isSubIndication = false
                    }
                }
                allParents.forEach { $0.isSubIndication = true }
                oldValue.isIndication = false
                indicationResponder.isIndication = true
                if let editText = oldValue as? Text {
                    editText.unmarkText()
                    delegate?.didChangeEditText(self, oldEditText: editText)
                }
            }
        }
    }
    func setIndicationResponder(with p: CGPoint) {
        let hitResponder = vision.at(p) ?? vision
        if indicationResponder !== hitResponder {
            self.indicationResponder = hitResponder
        }
    }
    func indicationResponder(with event: Event) -> Respondable {
        return vision.at(event.location) ?? vision
    }
    func contains(_ p: CGPoint) -> Bool {
        return false
    }
    
    func sendMoveCursor(with event: MoveEvent) {
        let hitResponder = vision.at(event.location) ?? vision
        if indicationResponder !== hitResponder {
            let oldIndicationResponder = indicationResponder
            self.indicationResponder = hitResponder
            if indicationResponder.editQuasimode != editQuasimode {
                indicationResponder.set(editQuasimode, with: event)
            }
            if oldIndicationResponder.editQuasimode != .none {
                indicationResponder.set(EditQuasimode.none, with: event)
            }
        }
        self.cursor = indicationResponder.cursor
        indicationResponder.moveCursor(with: event)
    }
    
    var cursor = Cursor.arrow {
        didSet {
            delegate?.didChangeCursor(self, cursor: cursor, oldCursor: oldValue)
        }
    }
    
    private var oldQuasimodeAction = Action()
    private weak var oldQuasimodeResponder: Respondable?
    func sendEditQuasimode(with event: Event) {
        let quasimodeAction = actionEditor.actionManager.actionWith(.drag, event) ?? Action()
        if !isDown {
            if editQuasimode != quasimodeAction.editQuasimode {
                self.editQuasimode = quasimodeAction.editQuasimode
                indicationResponder.set(quasimodeAction.editQuasimode, with: event)
                self.cursor = indicationResponder.cursor
            }
        }
        self.oldQuasimodeAction = quasimodeAction
        self.oldQuasimodeResponder = indicationResponder
    }
    
    private var isKey = false, keyAction = Action(), keyEvent: KeyInputEvent?
    private weak var keyText: Text?
    func sendKeyInputIsEditText(with event: KeyInputEvent) -> Bool {
        switch event.sendType {
        case .begin:
            setIndicationResponder(with: event.location)
            guard !isDown else {
                self.keyEvent = event
                return false
            }
            self.isKey = true
            self.keyAction = actionEditor.actionManager.actionWith(.keyInput, event) ?? Action()
            if let editText = editText, keyAction.canTextKeyInput() {
                self.keyText = editText
                return true
            } else if keyAction != Action() {
                keyAction.keyInput?(self, indicationResponder, event)
                if let undoManager = indicationResponder.undoManager, undoManager.groupingLevel >= 1 {
                     indicationResponder.undoManager?.setActionName(
                        type(of: indicationResponder).name.currentString + "." + keyAction.name.currentString
                    )
                }
            }
            let newIndicationResponder = vision.at(event.location) ?? vision
            if self.indicationResponder !== newIndicationResponder {
                self.indicationResponder = newIndicationResponder
                self.cursor = indicationResponder.cursor
            }
        case .sending:
            break
        case .end:
            if keyText != nil, isKey {
                self.keyText = nil
                return false
            }
        }
        return false
    }
    
    func sendRightDrag(with event: DragEvent) {
        if event.sendType == .end {
            indicationResponder(with: event).showProperty(with: event)
//            let newIndicationResponder = vision.at(event.location) ?? vision
//            if self.indicationResponder !== newIndicationResponder {
//                self.indicationResponder = newIndicationResponder
//                self.cursor = indicationResponder.cursor
//            }
        }
    }
    
    private let defaultClickAction = Action(gesture: .click), defaultDragAction = Action(drag: { $1.drag(with: $2) })
    private var isDown = false, isDrag = false, dragAction = Action()
    private weak var dragResponder: Respondable?
    func sendDrag(with event: DragEvent) {
        switch event.sendType {
        case .begin:
            setIndicationResponder(with: event.location)
            self.isDown = true
            self.isDrag = false
            self.dragResponder = indicationResponder
            if let dragResponder = dragResponder {
                self.dragAction = actionEditor.actionManager.actionWith(.drag, event) ?? defaultDragAction
                dragAction.drag?(self, dragResponder, event)
            }
        case .sending:
            self.isDrag = true
            if isDown, let dragResponder = dragResponder {
                dragAction.drag?(self, dragResponder, event)
            }
        case .end:
            if isDown {
                if let dragResponder = dragResponder {
                    dragAction.drag?(self, dragResponder, event)
                }
                if !isDrag {
                    dragResponder?.click(with: event)
                }
                self.isDown = false
                
                if let keyEvent = keyEvent {
                    _ = sendKeyInputIsEditText(with: keyEvent.with(sendType: .begin))
                    self.keyEvent = nil
                } else {
                    let newIndicationResponder = vision.at(event.location) ?? vision
                    if self.indicationResponder !== newIndicationResponder {
                        self.indicationResponder = newIndicationResponder
                        self.cursor = indicationResponder.cursor
                    }
                }
                self.isDrag = false
                
                if dragAction != oldQuasimodeAction {
                    if let dragResponder = dragResponder {
                        if indicationResponder !== dragResponder {
                            dragResponder.set(EditQuasimode.none, with: event)
                        }
                    }
                    self.editQuasimode = oldQuasimodeAction.editQuasimode
                    indicationResponder.set(oldQuasimodeAction.editQuasimode, with: event)
                }
            }
        }
    }
    
    private weak var momentumScrollResponder: Respondable?
    func sendScroll(with event: ScrollEvent, momentum: Bool) {
        let indicationResponder = vision.at(event.location) ?? vision
        if !momentum {
            self.momentumScrollResponder = indicationResponder
        }
        if let momentumScrollResponder = momentumScrollResponder {
            momentumScrollResponder.scroll(with: event)
        }
        setIndicationResponder(with: event.location)
        self.cursor = indicationResponder.cursor
    }
    func sendZoom(with event: PinchEvent) {
        indicationResponder.zoom(with: event)
    }
    func sendRotate(with event: RotateEvent) {
        indicationResponder.rotate(with: event)
    }
    
    func sendLookup(with event: TapEvent) {
        let p = event.location.integral
        let rp = CGPoint(x: p.x - 5, y: p.y + 5)
        let responder = indicationResponder(with: event)
        let reference = responder.lookUp(with: event)
//        let newIndicationResponder = vision.at(event.location) ?? vision
//        if self.indicationResponder !== newIndicationResponder {
//            self.indicationResponder = newIndicationResponder
//            self.cursor = indicationResponder.cursor
//        }
        referenceEditor.undoManager = responder.undoManager
        referenceEditor.reference = reference
        CATransaction.disableAnimation {
            referenceEditor.frame.origin = CGPoint(x: rp.x, y: rp.y - referenceEditor.frame.height)
            if !vision.children.contains(where: { $0 === referenceEditor }) {
                vision.children.append(referenceEditor)
            }
        }
    }
    
    func sendReset(with event: DoubleTapEvent) {
        indicationResponder(with: event).reset(with: event)
        setIndicationResponder(with: event.location)
    }
    
    func copy(with event: KeyInputEvent) -> CopyObject {
        return copyObjectEditor.copyObject
    }
    func paste(_ copyObject: CopyObject, with event: KeyInputEvent) {
        setCopyObject(copyObject, oldCopyObject: copyObjectEditor.copyObject)
    }
    func setCopyObject(_ copyObject: CopyObject, oldCopyObject: CopyObject) {
        sceneEditor.undoManager?.registerUndo(withTarget: self) {
            $0.setCopyObject(oldCopyObject, oldCopyObject: copyObject)
        }
        copyObjectEditor.copyObject = copyObject
    }
}

protocol CopyData: Referenceable {
    static var identifier: String { get }
    var data: Data { get }
    static func with(_ data: Data) -> Self?
}
extension CopyData {
    static var identifier: String {
        return String(describing: type(of: self))
    }
}
struct CopyObject {
    var objects: [CopyData]
    init(objects: [CopyData] = []) {
        self.objects = objects
    }
}
final class ObjectEditor: LayerRespondable {
    static let name = Localization(english: "Object Editor", japanese: "オブジェクトエディタ")
    var instanceDescription: Localization {
        return object.valueDescription
    }
    
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: oldValue)
        }
    }
    
    let object: CopyData
    
    let thumbnailEditor: DrawEditor, label: Label
    let layer = CALayer.interfaceLayer()
    init(object: CopyData, origin: CGPoint, thumbnailWidth: CGFloat, height: CGFloat) {
        self.object = object
        let thumbnailHeight = height - Layout.basicPadding * 2
        let thumbnailSize = CGSize(width: thumbnailWidth, height: thumbnailHeight)
        self.label = Label(text: type(of: object).name, font: Font.small, color: Color.locked)
        let width = thumbnailSize.width + label.text.frame.width + Layout.basicPadding * 3
        layer.frame = CGRect(x: origin.x, y: origin.y, width: width, height: height)
        label.frame.origin = CGPoint(
            x: Layout.basicPadding, y: Layout.basicPadding
        )
        self.thumbnailEditor = DrawEditor(
            drawable: object as? Drawable,
            frame: CGRect(
                x: Layout.basicPadding + label.frame.maxX,
                y: Layout.basicPadding,
                width: thumbnailSize.width,
                height: thumbnailSize.height
            )
        )
        
        self.children = [thumbnailEditor, label]
        update(withChildren: children, oldChildren: [])
    }
    func updateFrameWith(origin: CGPoint, height: CGFloat) {
        let thumbnailHeight = height - Layout.basicPadding * 2
        let thumbnailSize = CGSize(width: thumbnailHeight, height: thumbnailHeight)
        let width = thumbnailSize.width + label.text.textFrame.typographicBounds.width + Layout.basicPadding * 2
        layer.frame = CGRect(x: origin.x, y: origin.y, width: width, height: height)
        thumbnailEditor.frame = CGRect(
            x: Layout.basicPadding,
            y: Layout.basicPadding,
            width: thumbnailSize.width,
            height: thumbnailSize.height
        )
        label.frame.origin = CGPoint(
            x: Layout.basicPadding + thumbnailEditor.frame.maxX, y: Layout.basicPadding
        )
    }
}
final class CopyObjectEditor: LayerRespondable {
    static let name = Localization(english: "Copy Object Editor", japanese: "コピーオブジェクトエディタ")
    
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: oldValue)
        }
    }
    
    var changeCount = 0
    
    var defaultBorderColor: CGColor? = Color.border.cgColor
    
    var objectEditors = [ObjectEditor]() {
        didSet {
            if objectEditors.isEmpty {
                self.children = [copyLabel, noneLabel]
            } else {
                self.children = [copyLabel] as [Respondable] + objectEditors as [Respondable]
            }
            Layout.leftAlignment(children, height: frame.height)
        }
    }
    let copyLabel = Label(
        text: Localization(english: "Copied Object:", japanese: "コピーオブジェクト:"),
        font: .small, color: .locked
    )
    let noneLabel = Label(
        text: Localization(english: "None", japanese: "なし"),
        font: .small, color: .locked
    )
        
    let layer = CALayer.interfaceLayer(borderColor: .border)
    init() {
        layer.masksToBounds = true
        self.children = [copyLabel, noneLabel]
        update(withChildren: children, oldChildren: [])
    }
    var copyObject = CopyObject() {
        didSet {
            changeCount += 1
            CATransaction.disableAnimation {
                var origin = CGPoint(x: Layout.basicPadding, y: Layout.basicPadding)
                objectEditors = copyObject.objects.map { object in
                    let objectEditor = ObjectEditor(
                        object: object, origin: origin,
                        thumbnailWidth: 30.0, height: frame.height - Layout.basicPadding * 2
                    )
                    origin.x += objectEditor.frame.width + Layout.basicPadding
                    return objectEditor
                }
            }
        }
    }
    
    func delete(with event: KeyInputEvent) {
        copyObject = CopyObject()
    }
}

protocol Drawable {
    func draw(with bounds: CGRect, in ctx: CGContext)
}
final class DrawEditor: LayerRespondable {
    static let name = Localization(english: "Draw Editor", japanese: "描画エディタ")
    
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: oldValue)
        }
    }
    
    var layer: CALayer {
        return drawLayer
    }
    let drawLayer: DrawLayer
    
    var drawable: Drawable? {
        didSet {
            drawLayer.drawBlock = { [unowned self] ctx in
                self.drawable?.draw(with: self.bounds, in: ctx)
            }
            drawLayer.setNeedsDisplay()
        }
    }
    
    init(drawable: Drawable? = nil, frame: CGRect = CGRect(), backgroundColor: Color = .background) {
        self.drawLayer = DrawLayer(backgroundColor: backgroundColor)
        if let drawable = drawable {
            self.drawable = drawable
            drawLayer.drawBlock = { [unowned self] ctx in
                self.drawable?.draw(with: self.bounds, in: ctx)
            }
            drawLayer.setNeedsDisplay()
        }
        layer.frame = frame
    }
}

protocol Referenceable {
    static var name: Localization { get }
    static var feature: Localization { get }
    var instanceDescription: Localization { get }
    var valueDescription: Localization { get }
}
extension Referenceable {
    static var feature: Localization {
        return Localization()
    }
    var instanceDescription: Localization {
        return Localization()
    }
    var valueDescription: Localization {
        return Localization()
    }
}
final class ReferenceEditor: LayerRespondable {
    static let name = Localization(english: "Reference Editor", japanese: "情報エディタ")
    static let feature = Localization(english: "Close: Move cursor to outside", japanese: "閉じる: カーソルを外に出す")
    
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: oldValue)
        }
    }
    
    var undoManager: UndoManager?
    let layer: CALayer
    let minWidth = 200.0.cf
    init(backgroundColor: Color = .background) {
        layer = CALayer.interfaceLayer(backgroundColor: backgroundColor, borderColor: .border)
    }
    
    var defaultBorderColor: CGColor? = Color.border.cgColor
    var isSubIndication = false {
        didSet {
            if !isSubIndication {
                removeFromParent()
            }
        }
    }
    
    var reference: Referenceable? {
        didSet {
            CATransaction.disableAnimation {
                if let reference = reference {
                    let cas = ReferenceEditor.childrenAndSize(with: reference, width: minWidth)
                    self.children = cas.children
                    frame = CGRect(
                        x: frame.origin.x, y: frame.origin.y - (cas.size.height - frame.height),
                        width: cas.size.width, height: cas.size.height
                    )
                } else {
                    children = []
                }
            }
        }
    }
    static func childrenAndSize(with reference: Referenceable, width: CGFloat) -> (children: [Respondable], size: CGSize) {
        let type =  type(of: reference).name, feature = type(of: reference).feature
        let instanceDescription = reference.instanceDescription
        let description: Localization
        if instanceDescription.isEmpty && feature.isEmpty {
            description = Localization(english: "No description", japanese: "説明なし")
        } else {
            description = !instanceDescription.isEmpty && !feature.isEmpty ?
                instanceDescription + Localization("\n\n") + feature : instanceDescription + feature
        }
        
        let typeLabel = Label(
            frame: CGRect(x: 0, y: 0, width: width, height: 0),
            text: type, font: .hedding0
        )
        let descriptionLabel = Label(
            frame: CGRect(x: 0, y: 0, width: width, height: 0),
            text: description, font: .small, color: .locked
        )
        let size = CGSize(
            width: max(typeLabel.frame.width, descriptionLabel.frame.width) + Layout.basicPadding * 2,
            height: typeLabel.frame.height + descriptionLabel.frame.height + Layout.basicPadding * 5
        )
        var y = size.height - typeLabel.frame.height - Layout.basicPadding * 2
        typeLabel.frame.origin = CGPoint(x: Layout.basicPadding, y: y)
        y -= descriptionLabel.frame.height + Layout.basicPadding
        descriptionLabel.frame.origin = CGPoint(x: Layout.basicPadding, y: y)
        return ([typeLabel, descriptionLabel], size)
    }
    
    func delete(with event: KeyInputEvent) {
        reference = nil
    }
    
    let scroller = Scroller()
    func scroll(with event: ScrollEvent) {
        scroller.scroll(with: event, responder: self)
    }
}
