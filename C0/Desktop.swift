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

struct Desktop {
    var version = Version()
    var copiedObjects = Selection<Object>()
    var transform = Transform()
    var objects = Selection<Layout<Object>>()
    var isHiddenActionList = false
    let actionList = ActionList()
}
extension Desktop: Codable {
    private enum CodingKeys: String, CodingKey {
        case version, copiedObjects, transform, objects, isHiddenActionList
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        version = try values.decode(Version.self, forKey: .version)
        copiedObjects = try values.decode(Selection<Object>.self, forKey: .copiedObjects)
        transform = try values.decode(Transform.self, forKey: .transform)
        objects = try values.decode(Selection<Layout<Object>>.self, forKey: .objects)
        isHiddenActionList = try values.decode(Bool.self, forKey: .isHiddenActionList)
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(copiedObjects, forKey: .copiedObjects)
        try container.encode(transform, forKey: .transform)
        try container.encode(objects, forKey: .objects)
        try container.encode(isHiddenActionList, forKey: .isHiddenActionList)
    }
}
extension Desktop: Referenceable {
    static let name = Text(english: "Desktop", japanese: "デスクトップ")
}
extension Desktop {
    static let isHiddenActionListOption = BoolOption(defaultModel: false, cationModel: nil,
                                                     name: ActionList.name,
                                                     info: .hidden)
    static let copiedObjectsInferenceName = Text(english: "Copied", japanese: "コピー済み")
}
extension Desktop: AbstractViewable {
    func abstractViewWith<T>(binder: T, keyPath: ReferenceWritableKeyPath<T, Desktop>,
                             type: AbstractType) -> ModelView where T: BinderProtocol {
        switch type {
        case .normal:
            return DesktopView(binder: binder, keyPath: keyPath)
        case .mini:
            return MiniView(binder: binder, keyPath: keyPath)
        }
    }
}
extension Desktop: ObjectViewable {}

final class DesktopBinder: BinderProtocol {
    var rootModel: Desktop {
        didSet { diffDesktopDataModel.isWrite = true }
    }
    
    init(rootModel: Desktop) {
        self.rootModel = rootModel
        
        diffDesktopDataModel = DataModel(key: diffDesktopDataModelKey)
        objectsDataModel = DataModel(key: objectsDataModelKey, directoryWith: [])
        dataModel = DataModel(key: dataModelKey,
                              directoryWith: [diffDesktopDataModel, objectsDataModel])
        
        diffDesktopDataModel.dataClosure = { [unowned self] in self.rootModel.jsonData }
    }
    
    let dataModelKey = "desktop"
    var dataModel: DataModel {
        didSet {
            if let objectsDataModel = dataModel.children[objectsDataModelKey] {
                self.objectsDataModel = objectsDataModel
            } else {
                dataModel.insert(objectsDataModel)
            }
            
            if let dDesktopDataModel = dataModel.children[diffDesktopDataModelKey] {
                self.diffDesktopDataModel = dDesktopDataModel
            } else {
                dataModel.insert(diffDesktopDataModel)
            }
        }
    }
    
    let diffDesktopDataModelKey = "diffDesktop"
    var diffDesktopDataModel: DataModel {
        didSet {
            if let desktop = diffDesktopDataModel.readObject(Desktop.self) {
                diffDesktopDataModel.stopIsWriteClosure { self.rootModel = desktop }
            }
            diffDesktopDataModel.dataClosure = { [unowned self] in self.rootModel.jsonData }
        }
    }
    
    let objectsDataModelKey = "objects"
    var objectsDataModel: DataModel
}

final class DesktopView<T: BinderProtocol>: ModelView, BindableReceiver {
    typealias Model = Desktop
    typealias Binder = T
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((DesktopView<Binder>, BasicNotification) -> ())]()

    var defaultModel: Model {
        return Model()
    }

    let versionView: VersionView<Binder>
    let copiedObjectsNameView = TextFormView(text: Desktop.copiedObjectsInferenceName + ":")
    let copiedObjectsView: SelectionView<Object, Binder>
    let transformView: BasicTransformView<Binder>
    let objectsView: SelectionView<Layout<Object>, Binder>
    let isHiddenActionListView: BoolView<Binder>
    var actionListView: ActionListFormView?

    var versionWidth = 150.0.cg
    var topViewsHeight = Layouter.basicHeight {
        didSet { updateLayout() }
    }
//    let transformFormView: View

    init(binder: Binder, keyPath: BinderKeyPath) {
        self.binder = binder
        self.keyPath = keyPath

        versionView = VersionView(binder: binder,
                                  keyPath: keyPath.appending(path: \Model.version))
        copiedObjectsView = SelectionView(binder: binder,
                                          keyPath: keyPath.appending(path: \Model.copiedObjects),
                                          abstractType: .mini)
        copiedObjectsView.valuesView.xyOrientation = .horizontal(.leftToRight)
        transformView = BasicTransformView(binder: binder,
                                           keyPath: keyPath.appending(path: \Model.transform),
                                           option: TransformOption())
//        transformFormView = View(isLocked: false)
        objectsView = SelectionView(binder: binder,
                                    keyPath: keyPath.appending(path: \Model.objects))
//        transformFormView.append(child: objectsView)

        isHiddenActionListView
            = BoolView(binder: binder,
                       keyPath: keyPath.appending(path: \Model.isHiddenActionList),
                       option: Model.isHiddenActionListOption)

        super.init(isLocked: false)
        isHiddenActionListView.notifications.append({ [unowned self] _, _ in
            self.updateHiddenActionList()
            self.updateLayout()
        })
        transformView.notifications.append({ [unowned self] _, _ in
            self.updateTransform()
        })
        fillColor = .background
        updateHiddenActionList()
    }

    override var contentsScale: Real {
        didSet {
            if contentsScale != oldValue {
                allChildrenAndSelf { $0.contentsScale = contentsScale }
            }
        }
    }

    var minSize: Size {
        let w = versionView.minSize.width
            + isHiddenActionListView.minSize.width + copiedObjectsNameView.minSize.width
        return Size(width: w, height: Layouter.basicHeight) + Layouter.basicPadding * 2
    }
    override func updateLayout() {
        let padding = Layouter.basicPadding
        let ihamvw = isHiddenActionListView.minSize.width
        let tw = transformView.minSize.width
        let headerY = bounds.height - topViewsHeight - padding
        versionView.frame = Rect(x: padding, y: headerY,
                                 width: versionWidth, height: topViewsHeight)
        let conms = copiedObjectsNameView.minSize
        copiedObjectsNameView.frame = Rect(origin: Point(x: versionView.frame.maxX + padding,
                                                         y: headerY + padding),
                                           size: conms)
        let conw = copiedObjectsNameView.frame.width
        let d = bounds.width - versionWidth - ihamvw
        let cw = max(d - conw - tw - padding * 3,
                     0)
        copiedObjectsView.frame = Rect(x: copiedObjectsNameView.frame.maxX, y: headerY,
                                       width: cw, height: topViewsHeight)

        transformView.frame = Rect(x: copiedObjectsView.frame.maxX, y: headerY,
                                   width: tw, height: topViewsHeight)

        isHiddenActionListView.frame = Rect(x: transformView.frame.maxX, y: headerY,
                                            width: ihamvw, height: topViewsHeight)

        if model.isHiddenActionList {
            objectsView.frame = Rect(x: padding,
                                     y: padding,
                                     width: bounds.width - padding * 2,
                                     height: bounds.height - topViewsHeight - padding * 2)
        } else if let actionListView = actionListView {
            let actionWidth = actionListView.width
            let ow = max(bounds.width - actionWidth - padding * 2, 0)
            let h = bounds.height - padding * 2 - topViewsHeight
            objectsView.frame = Rect(x: padding,
                                     y: padding,
                                     width: ow,
                                     height: bounds.height - topViewsHeight - padding * 2)

            actionListView.frame = Rect(x: padding + ow,
                                        y: padding,
                                        width: actionWidth,
                                        height: h)
        }
        updateTransform()
    }
    func updateHiddenActionList() {
        if model.isHiddenActionList {
            children = [versionView, copiedObjectsNameView, copiedObjectsView,
                        isHiddenActionListView, objectsView, transformView]
        } else {
            let actionListView = ActionListFormView()
            self.actionListView = actionListView
            children = [versionView, copiedObjectsNameView, copiedObjectsView,
                        isHiddenActionListView, actionListView, objectsView, transformView]
        }
    }
    func updateWithModel() {
        isHiddenActionListView.updateWithModel()
        copiedObjectsView.updateWithModel()
        objectsView.updateWithModel()
        versionView.updateWithModel()
        transformView.updateWithModel()
    }

//    var objectViewWidth = 80.0.cg
//    private func updateCopiedObjectViews() {
//        copiedObjectsView.updateWithModel()
//        let padding = Layouter.smallPadding
//        let bounds = Rect(x: 0,
//                          y: 0,
//                          width: objectViewWidth,
//                          height: copiedObjectsView.bounds.height - padding * 2)
//        copiedObjectsView.updateWithModel()
//        copiedObjectsView.children.forEach { $0.bounds = bounds }
//        updateCopiedObjectViewPositions()
//    }
//    private func updateCopiedObjectViewPositions() {
//        let padding = Layouter.smallPadding
//        _ = Layouter.leftAlignment(copiedObjectsView.children.map { .view($0) },
//                                   minX: padding, y: padding)
//    }

    var zoomingTransform: Transform {
        get { return model.transform }
        set {
            binder[keyPath: keyPath].transform = newValue
            updateTransform()
            transformView.updateWithModel()
        }
    }
    func convertZoomingLocalFromZoomingView(_ p: Point) -> Point {
//        let fromView = objectsView.valuesView
//        let objectsPosition = Point(x: (fromView.bounds.width / 2).rounded(),
//                                    y: (fromView.bounds.height / 2).rounded())
        return zoomingLocalView.convert(p, from: zoomingView)// - objectsPosition
    }
    func convertZoomingLocalToZoomingView(_ p: Point) -> Point {
//        let toView = ZoomingView
//        let objectsPosition = Point(x: (toView.bounds.width / 2).rounded(),
//                                    y: (toView.bounds.height / 2).rounded())
        return zoomingLocalView.convert(p, to: zoomingView)// + objectsPosition
    }
    func updateTransform() {
        var transform = zoomingTransform
        let objectsPosition = Point(x: (objectsView.bounds.width / 2).rounded(),
                                    y: (objectsView.bounds.height / 2).rounded())
        transform.translation += objectsPosition
        zoomingLocalView.transform = transform
    }
    var zoomingView: View {
        return objectsView.valuesView
    }
    var zoomingLocalView: View {
        return objectsView.valuesView.rootView
    }
}
extension DesktopView: Zoomable {
    func captureTransform(to version: Version) {
        transformView.push(model.transform, to: version)
    }
}
extension DesktopView: Undoable {
    var version: Version {
        return versionView.model
    }
}
extension DesktopView: CopiedObjectsViewer {
    var copiedObjects: [Object] {
        get { return copiedObjectsView.valuesView.model }
        set { copiedObjectsView.valuesView.model = newValue }
    }
    func push(_ copiedObjects: [Object], to version: Version) {
        copiedObjectsView.valuesView.push(copiedObjects, to: version)
    }
}
