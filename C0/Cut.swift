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

final class CutTrack: NSObject, Track, NSCoding {
    private(set) var animation: Animation
    
    let differentialDataModelKey = "differentialCutTrack"
    var differentialDataModel: DataModel {
        didSet {
            var nodeDic = [String: Node]()
            cutItem.keyCuts.forEach { cut in
                cut.rootNode.allChildren { (node) in
                    nodeDic[node.key.uuidString] = node
                }
            }
            differentialDataModel.children.forEach { (key, dataModel) in
                nodeDic[key]?.differentialDataModel = dataModel
            }
        }
    }
    
    func insert(_ cut: Cut, at index: Int) {
        cutItem.keyCuts.insert(cut, at: index)
        let cutTime = index == animation.keyframes.count ? animation.duration : time(at: index)
        let keyframe = Keyframe(time: cutTime, easing: Easing(),
                                interpolation: .step, loop: .none, label: .main)
        animation.keyframes.insert(keyframe, at: index)
        updateCutTimeAndDuration()
        cut.rootNode.allChildren { differentialDataModel.insert($0.differentialDataModel) }
    }
    func removeCut(at index: Int) {
        let cut = cutItem.keyCuts[index]
        cutItem.keyCuts.remove(at: index)
        animation.keyframes.remove(at: index)
        updateCutTimeAndDuration()
        cut.rootNode.allChildren { differentialDataModel.remove($0.differentialDataModel) }
    }
    
    let cutItem: CutItem
    
    var time: Beat {
        didSet {
            updateInterpolation()
        }
    }
    func updateInterpolation() {
        animation.update(withTime: time, to: self)
    }
    
    func step(_ f0: Int) {
        cutItem.step(f0)
    }
    func linear(_ f0: Int, _ f1: Int, t: CGFloat) {
        cutItem.linear(f0, f1, t: t)
    }
    func firstMonospline(_ f1: Int, _ f2: Int, _ f3: Int, with ms: Monospline) {
        cutItem.firstMonospline(f1, f2, f3, with: ms)
    }
    func monospline(_ f0: Int, _ f1: Int, _ f2: Int, _ f3: Int, with ms: Monospline) {
        cutItem.monospline(f0, f1, f2, f3, with: ms)
    }
    func lastMonospline(_ f0: Int, _ f1: Int, _ f2: Int, with ms: Monospline) {
        cutItem.lastMonospline(f0, f1, f2, with: ms)
    }
    
    init(animation: Animation = Animation(), time: Beat = 0, cutItem: CutItem = CutItem()) {
        differentialDataModel = DataModel(key: differentialDataModelKey, directoryWith: [])
        
        guard animation.keyframes.count == cutItem.keyCuts.count else {
            fatalError()
        }
        self.animation = animation
        self.time = time
        self.cutItem = cutItem
        super.init()
        cutItem.keyCuts.forEach { cut in
            cut.rootNode.allChildren { node in
                differentialDataModel.insert(node.differentialDataModel)
            }
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case animation, time, cutItem
    }
    init?(coder: NSCoder) {
        differentialDataModel = DataModel(key: differentialDataModelKey, directoryWith: [])
        
        animation = coder.decodeDecodable(
            Animation.self, forKey: CodingKeys.animation.rawValue) ?? Animation()
        time = coder.decodeDecodable(Beat.self, forKey: CodingKeys.time.rawValue) ?? 0
        cutItem = coder.decodeObject(forKey: CodingKeys.cutItem.rawValue) as? CutItem ?? CutItem()
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encodeEncodable(animation, forKey: CodingKeys.animation.rawValue)
        coder.encodeEncodable(time, forKey: CodingKeys.time.rawValue)
        coder.encode(cutItem, forKey: CodingKeys.cutItem.rawValue)
    }
    
    func index(atTime time: Beat) -> Int {
        return animation.loopFrames[animation.loopedKeyframeIndex(withTime: time).loopFrameIndex].index
    }
    func time(at index: Int) -> Beat {
        return animation.loopFrames[index].time
    }
    
    func updateCutTimeAndDuration() {
        animation.duration = cutItem.keyCuts.enumerated().reduce(Beat(0)) {
            animation.keyframes[$1.offset].time = $0
            return $0 + $1.element.duration
        }
    }
    
    func cutIndex(withTime time: Beat) -> (index: Int, interTime: Beat, isOver: Bool) {
        guard cutItem.keyCuts.count > 1 else {
            return (0, time, animation.duration <= time)
        }
        let lfi = animation.loopedKeyframeIndex(withTime: time)
        return (lfi.keyframeIndex, lfi.interTime, animation.duration <= time)
    }
    func movingCutIndex(withTime time: Beat) -> Int {
        guard cutItem.keyCuts.count > 1 else {
            return 0
        }
        for i in 1 ..< cutItem.keyCuts.count {
            if time <= animation.keyframes[i].time {
                return i - 1
            }
        }
        return cutItem.keyCuts.count - 1
    }
}
extension CutTrack: Referenceable {
    static let name = Localization(english: "Cut Track", japanese: "カットトラック")
}
extension CutTrack: ClassDeepCopiable {
    func copied(from deepCopier: DeepCopier) -> CutTrack {
        return CutTrack(animation: animation, time: time, cutItem: deepCopier.copied(cutItem))
    }
}

final class CutItem: NSObject, TrackItem, NSCoding {
    fileprivate(set) var keyCuts: [Cut]
    var cut: Cut
    
    func step(_ f0: Int) {
        cut = keyCuts[f0]
    }
    func linear(_ f0: Int, _ f1: Int, t: CGFloat) {
        cut = keyCuts[f0]
    }
    func firstMonospline(_ f1: Int, _ f2: Int, _ f3: Int, with ms: Monospline) {
        cut = keyCuts[f1]
    }
    func monospline(_ f0: Int, _ f1: Int, _ f2: Int, _ f3: Int, with ms: Monospline) {
        cut = keyCuts[f1]
    }
    func lastMonospline(_ f0: Int, _ f1: Int, _ f2: Int, with ms: Monospline) {
        cut = keyCuts[f1]
    }
    
    init(keyCuts: [Cut] = [], cut: Cut = Cut()) {
        if keyCuts.isEmpty {
            self.keyCuts = [cut]
        } else {
            self.keyCuts = keyCuts
        }
        self.cut = cut
        super.init()
    }
    
    private enum CodingKeys: String, CodingKey {
        case keyCuts, cut
    }
    init?(coder: NSCoder) {
        keyCuts = coder.decodeObject(forKey: CodingKeys.keyCuts.rawValue) as? [Cut] ?? []
        cut = coder.decodeObject(forKey: CodingKeys.cut.rawValue) as? Cut ?? Cut()
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encode(keyCuts, forKey: CodingKeys.keyCuts.rawValue)
        coder.encode(cut, forKey: CodingKeys.cut.rawValue)
    }
}
extension CutItem: ClassDeepCopiable {
    func copied(from deepCopier: DeepCopier) -> CutItem {
        return CutItem(keyCuts: keyCuts.map { deepCopier.copied($0) }, cut: deepCopier.copied(cut))
    }
}

/**
 Issue: 変更通知
 */
final class Cut: NSObject, NSCoding {
    enum ViewType: Int8 {
        case
        preview, edit,
        editPoint, editVertex, editMoveZ,
        editWarp, editTransform, editSelected, editDeselected,
        editMaterial, changingMaterial
    }
    
    var rootNode: Node
    var editNode: Node {
        didSet {
            if editNode != oldValue {
                oldValue.isEdited = false
                editNode.isEdited = true
            }
        }
    }
    
    let subtitleTrack: SubtitleTrack
    
    var currentTime: Beat {
        didSet {
            updateWithCurrentTime()
        }
    }
    func updateWithCurrentTime() {
        rootNode.time = currentTime
        subtitleTrack.time = currentTime
    }
    var duration: Beat {
        didSet {
            subtitleTrack.replace(duration: duration)
        }
    }
    
    init(rootNode: Node = Node(tracks: [NodeTrack(animation: Animation(duration: 0))]),
         editNode: Node = Node(name: "0"),
         subtitleTrack: SubtitleTrack = SubtitleTrack(),
         currentTime: Beat = 0) {
        
        editNode.editTrack.name = "0"
        if rootNode.children.isEmpty {
            let node = Node(name: "0")
            node.editTrack.name = "0"
            node.children.append(editNode)
            rootNode.children.append(node)
        }
        self.rootNode = rootNode
        self.editNode = editNode
        self.subtitleTrack = subtitleTrack
        self.currentTime = currentTime
        self.duration = rootNode.maxDuration
        subtitleTrack.replace(duration: duration)
        rootNode.time = currentTime
        rootNode.isEdited = true
        editNode.isEdited = true
        super.init()
    }
    
    init(rootNode: Node, editNode: Node, subtitleTrack: SubtitleTrack,
         currentTime: Beat, duration: Beat) {
        self.rootNode = rootNode
        self.editNode = editNode
        self.subtitleTrack = subtitleTrack
        self.currentTime = currentTime
        self.duration = rootNode.maxDuration
        super.init()
    }
    
    private enum CodingKeys: String, CodingKey {
        case rootNode, editNode, subtitleTrack, time, duration
    }
    init?(coder: NSCoder) {
        rootNode = coder.decodeObject(forKey: CodingKeys.rootNode.rawValue) as? Node ?? Node()
        editNode = coder.decodeObject(forKey: CodingKeys.editNode.rawValue) as? Node ?? Node()
        rootNode.isEdited = true
        editNode.isEdited = true
        subtitleTrack = coder.decodeObject(
            forKey: CodingKeys.subtitleTrack.rawValue) as? SubtitleTrack ?? SubtitleTrack()
        currentTime = coder.decodeDecodable(Beat.self, forKey: CodingKeys.time.rawValue) ?? 0
        duration = coder.decodeDecodable(Beat.self, forKey: CodingKeys.duration.rawValue) ?? 0
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encode(rootNode, forKey: CodingKeys.rootNode.rawValue)
        coder.encode(editNode, forKey: CodingKeys.editNode.rawValue)
        coder.encode(subtitleTrack, forKey: CodingKeys.subtitleTrack.rawValue)
        coder.encodeEncodable(currentTime, forKey: CodingKeys.time.rawValue)
        coder.encodeEncodable(duration, forKey: CodingKeys.duration.rawValue)
    }
    
    func read() {
        rootNode.allChildren { $0.read() }
    }
    
    var imageBounds: CGRect {
        return rootNode.imageBounds
    }
    var allCells: [Cell] {
        return rootNode.allCells
    }
    var maxDuration: Beat {
        return rootNode.maxDuration
    }
    
    func draw(scene: Scene, viewType: Cut.ViewType, in ctx: CGContext) {
        if viewType == .preview {
            ctx.saveGState()
            rootNode.draw(scene: scene, viewType: viewType,
                          scale: 1, rotation: 0,
                          viewScale: 1, viewRotation: 0,
                          in: ctx)
            if !scene.isHiddenSubtitles {
                subtitleTrack.drawSubtitle.draw(bounds: scene.frame, in: ctx)
            }
            ctx.restoreGState()
        } else {
            ctx.saveGState()
            ctx.concatenate(scene.viewTransform.affineTransform)
            rootNode.draw(scene: scene, viewType: viewType,
                          scale: 1, rotation: 0,
                          viewScale: scene.scale, viewRotation: scene.viewTransform.rotation,
                          in: ctx)
            ctx.restoreGState()
        }
    }
    
    func drawCautionBorder(scene: Scene, bounds: CGRect, in ctx: CGContext) {
        func drawBorderWith(bounds: CGRect, width: CGFloat, color: Color, in ctx: CGContext) {
            ctx.setFillColor(color.cgColor)
            ctx.fill([CGRect(x: bounds.minX, y: bounds.minY,
                             width: width, height: bounds.height),
                      CGRect(x: bounds.minX + width, y: bounds.minY,
                             width: bounds.width - width * 2, height: width),
                      CGRect(x: bounds.minX + width, y: bounds.maxY - width,
                             width: bounds.width - width * 2, height: width),
                      CGRect(x: bounds.maxX - width, y: bounds.minY,
                             width: width, height: bounds.height)])
        }
        if scene.viewTransform.rotation > .pi / 2 || scene.viewTransform.rotation < -.pi / 2 {
            let borderWidth = 2.0.cf
            drawBorderWith(bounds: bounds, width: borderWidth * 2, color: .warning, in: ctx)
            let textLine = TextFrame(string: "\(Int(scene.viewTransform.rotation * 180 / (.pi)))°",
                font: .bold, color: .warning)
            let sb = textLine.typographicBounds.insetBy(dx: -10, dy: -2).integral
            textLine.draw(in: CGRect(x: bounds.minX + (bounds.width - sb.width) / 2,
                                     y: bounds.minY + bounds.height - sb.height - borderWidth,
                                     width: sb.width, height: sb.height), baseFont: .bold,
                          in: ctx)
        }
    }
    
    struct NodeAndTrack: Equatable {
        let node: Node, trackIndex: Int
        var track: NodeTrack {
            return node.tracks[trackIndex]
        }
    }
    func nodeAndTrackIndex(with nodeAndTrack: NodeAndTrack) -> Int {
        var index = 0, stop = false
        func maxNodeAndTrackIndexRecursion(_ node: Node) {
            for child in node.children {
                maxNodeAndTrackIndexRecursion(child)
                if stop {
                    return
                }
            }
            if node == nodeAndTrack.node {
                index += nodeAndTrack.trackIndex
                stop = true
                return
            }
            if !stop {
                index += node.tracks.count
            }
        }
        for child in rootNode.children {
            maxNodeAndTrackIndexRecursion(child)
            if stop {
                break
            }
        }
        return index
    }
    func nodeAndTrack(atNodeAndTrackIndex nodeAndTrackIndex: Int) -> NodeAndTrack {
        var index = 0, stop = false
        var nodeAndTrack = NodeAndTrack(node: rootNode, trackIndex: 0)
        func maxNodeAndTrackIndexRecursion(_ node: Node) {
            for child in node.children {
                maxNodeAndTrackIndexRecursion(child)
                if stop {
                    return
                }
            }
            let newIndex = index + node.tracks.count
            if index <= nodeAndTrackIndex && newIndex > nodeAndTrackIndex {
                nodeAndTrack = NodeAndTrack(node: node, trackIndex: nodeAndTrackIndex - index)
                stop = true
                return
            }
            index = newIndex
            
        }
        for child in rootNode.children {
            maxNodeAndTrackIndexRecursion(child)
            if stop {
                break
            }
        }
        return nodeAndTrack
    }
    var editNodeAndTrack: NodeAndTrack {
        get {
            let node = editNode
            return NodeAndTrack(node: node, trackIndex: node.editTrackIndex)
        }
        set {
            editNode = newValue.node
            if newValue.trackIndex < newValue.node.tracks.count {
                newValue.node.editTrackIndex = newValue.trackIndex
            }
        }
    }
    var editNodeAndTrackIndex: Int {
        return nodeAndTrackIndex(with: editNodeAndTrack)
    }
    var maxNodeAndTrackIndex: Int {
        func maxNodeAndTrackIndexRecursion(_ node: Node) -> Int {
            let count = node.children.reduce(0) { $0 + maxNodeAndTrackIndexRecursion($1) }
            return count + node.tracks.count
        }
        return maxNodeAndTrackIndexRecursion(rootNode) - 2
    }
    
    func node(atTreeNodeIndex ti: Int) -> Node {
        var i = 0, node: Node?
        rootNode.allChildren { (aNode, stop) in
            if i == ti {
                node = aNode
                stop = true
            } else {
                i += 1
            }
        }
        return node!
    }
    var editTreeNodeIndex: Int {
        get {
            var i = 0
            rootNode.allChildren { (node, stop) in
                if node == editNode {
                    stop = true
                } else {
                    i += 1
                }
            }
            return i
        }
        set {
            var i = 0
            rootNode.allChildren { (node, stop) in
                if i == newValue {
                    editNode = node
                    stop = true
                } else {
                    i += 1
                }
            }
        }
    }
    var maxTreeNodeIndex: Int {
        return rootNode.treeNodeCount - 1
    }
}
extension Cut: Referenceable {
    static let name = Localization(english: "Cut", japanese: "カット")
}
extension Cut: ClassDeepCopiable {
    func copied(from deepCopier: DeepCopier) -> Cut {
        return Cut(rootNode: deepCopier.copied(rootNode), editNode: deepCopier.copied(editNode),
                   subtitleTrack: deepCopier.copied(subtitleTrack),
                   currentTime: currentTime, duration: duration)
    }
}
extension Cut: ObjectViewExpression {
    func thumbnail(withBounds bounds: CGRect, _ sizeType: SizeType) -> View {
        return duration.thumbnail(withBounds: bounds, sizeType)
    }
}

final class CutView: View, Assignable, Scrollable {
    let cut: Cut
    
    let classNameView = TextView(text: Cut.name, font: .smallBold)
    let clipView = View(isForm: true)
    
    private(set) var editAnimationView: AnimationView {
        didSet {
            oldValue.sizeType = .small
            editAnimationView.sizeType = .regular
            updateChildren()
        }
    }
    private(set) var animationViews: [AnimationView]
    
    let subtitleAnimationView: AnimationView
    var subtitleTextViews = [TextView]()
    
    func animationView(with nodeAndTrack: Cut.NodeAndTrack) -> AnimationView {
        let index = cut.nodeAndTrackIndex(with: nodeAndTrack)
        return animationViews[index]
    }
    func animationViews(with node: Node) -> [AnimationView] {
        var animationViews = [AnimationView]()
        tracks(from: node) { (_, _, i) in
            animationViews.append(self.animationViews[i])
        }
        return animationViews
    }
    func tracks(closure: (Node, NodeTrack, Int) -> ()) {
        CutView.tracks(with: cut, closure: closure)
    }
    func tracks(from node: Node, closure: (Node, NodeTrack, Int) -> ()) {
        CutView.tracks(from: node, with: cut, closure: closure)
    }
    static func tracks(with node: Node, closure: (Node, NodeTrack, Int) -> ()) {
        var i = 0
        node.allChildrenAndSelf { aNode in
            aNode.tracks.forEach { track in
                closure(aNode, track, i)
                i += 1
            }
        }
    }
    static func tracks(with cut: Cut, closure: (Node, NodeTrack, Int) -> ()) {
        var i = 0
        cut.rootNode.allChildren { node in
            node.tracks.forEach { track in
                closure(node, track, i)
                i += 1
            }
        }
    }
    static func tracks(from node: Node, with cut: Cut, closure: (Node, NodeTrack, Int) -> ()) {
        tracks(with: cut) { (aNode, track, i) in
            aNode.selfAndAllParents { (n) -> (Bool) in
                if node == n {
                    closure(aNode, track, i)
                    return true
                } else {
                    return false
                }
            }
            
        }
    }
    static func animationView(with track: Track, beginBaseTime: Beat,
                              baseTimeInterval: Beat, sizeType: SizeType) -> AnimationView {
        return AnimationView(track.animation,
                             beginBaseTime: beginBaseTime,
                             baseTimeInterval: baseTimeInterval,
                             sizeType: sizeType)
    }
    func newAnimationView(with track: NodeTrack, node: Node, sizeType: SizeType) -> AnimationView {
        let animationView = CutView.animationView(with: track, beginBaseTime: beginBaseTime,
                                                  baseTimeInterval: baseTimeInterval,
                                                  sizeType: sizeType)
        animationView.frame.size.width = frame.width
        bind(in: animationView, from: node, from: track)
        return animationView
    }
    func newAnimationViews(with node: Node) -> [AnimationView] {
        var animationViews = [AnimationView]()
        CutView.tracks(with: node) { (node, track, index) in
            let animationView = CutView.animationView(with: track, beginBaseTime: beginBaseTime,
                                                      baseTimeInterval: baseTimeInterval,
                                                      sizeType: .regular)
            animationView.frame.size.width = frame.width
            bind(in: animationView, from: node, from: track)
            animationViews.append(animationView)
        }
        return animationViews
    }
    
    init(_ cut: Cut,
         beginBaseTime: Beat = 0,
         baseWidth: CGFloat, baseTimeInterval: Beat,
         knobHalfHeight: CGFloat, subKnobHalfHeight: CGFloat, maxLineWidth: CGFloat, height: CGFloat) {
        
        classNameView.fillColor = nil
        clipView.isClipped = true
        
        self.cut = cut
        self.beginBaseTime = beginBaseTime
        self.baseWidth = baseWidth
        self.baseTimeInterval = baseTimeInterval
        self.knobHalfHeight = knobHalfHeight
        self.subKnobHalfHeight = subKnobHalfHeight
        self.maxLineWidth = maxLineWidth
        
        let editNode = cut.editNode
        var animationViews = [AnimationView](), editAnimationView = AnimationView()
        CutView.tracks(with: cut) { (node, track, index) in
            let isEdit = node === editNode && track == editNode.editTrack
            let animationView = AnimationView(track.animation,
                                              baseTimeInterval: baseTimeInterval,
                                              sizeType: !isEdit ? .small : .regular)
            animationViews.append(animationView)
            if isEdit {
                editAnimationView = animationView
            }
        }
        self.animationViews = animationViews
        self.editAnimationView = editAnimationView
        
        subtitleAnimationView = CutView.animationView(with: cut.subtitleTrack,
                                                    beginBaseTime: beginBaseTime,
                                                    baseTimeInterval: baseTimeInterval,
                                                    sizeType: .small)
        
        super.init()
        clipView.children = animationViews
        children = [clipView, classNameView]
        frame.size.height = height
        updateLayout()
        updateWithDuration()
        
        let subtitleItem = cut.subtitleTrack.subtitleItem
        subtitleTextViews = subtitleItem.keySubtitles.enumerated().map { (i, subtitle) in
            let textView = TextView(isForm: false)
            textView.isReadOnly = false
            textView.string = subtitle.string
            textView.noIndicatedLineColor = .getSetBorder
            textView.indicatedLineColor = .indicated
            textView.fillColor = nil
            textView.binding = {
                cut.subtitleTrack.replace(Subtitle(string: $0.text, isConnectedWithPrevious: false),
                                          at: i)
            }
            return textView
        }
        subtitleAnimationView.setKeyframeClosure = { [unowned self] ab in
            guard ab.phase == .ended else {
                return
            }
            switch ab.setType {
            case .insert:
                let subtitle = Subtitle()
                let textView = TextView(isForm: false)
                textView.isReadOnly = false
                textView.noIndicatedLineColor = .getSetBorder
                textView.indicatedLineColor = .indicated
                textView.fillColor = nil
                textView.string = subtitle.string
                textView.binding = {
                    cut.subtitleTrack.replace(Subtitle(string: $0.text,
                                                       isConnectedWithPrevious: false),
                                              at: ab.index)
                }
                cut.subtitleTrack.insert(ab.keyframe,
                                         SubtitleTrack.KeyframeValues(subtitle: subtitle),
                                         at: ab.index)
                self.subtitleTextViews.insert(textView, at: ab.index)
                self.subtitleKeyframeBinding?(SubtitleKeyframeBinding(cutView: self,
                                                                      keyframe: ab.keyframe,
                                                                      subtitle: subtitle,
                                                                      index: ab.index,
                                                                      setType: ab.setType,
                                                                      animation: ab.animation,
                                                                      oldAnimation: ab.oldAnimation,
                                                                      phase: ab.phase))
            case .remove:
                let subtitle = cut.subtitleTrack.subtitleItem.keySubtitles[ab.index]
                cut.subtitleTrack.removeKeyframe(at: ab.index)
                self.subtitleTextViews.remove(at: ab.index)
                self.subtitleKeyframeBinding?(SubtitleKeyframeBinding(cutView: self,
                                                                      keyframe: ab.keyframe,
                                                                      subtitle: subtitle,
                                                                      index: ab.index,
                                                                      setType: ab.setType,
                                                                      animation: ab.animation,
                                                                      oldAnimation: ab.oldAnimation,
                                                                      phase: ab.phase))
            case .replace:
                break
            }
        }
        subtitleAnimationView.slideClosure = {
            cut.subtitleTrack.replace($0.animation.keyframes)
        }
        
        animationViews.enumerated().forEach { (i, animationView) in
            let nodeAndTrack = cut.nodeAndTrack(atNodeAndTrackIndex: i)
            bind(in: animationView, from: nodeAndTrack.node, from: nodeAndTrack.track)
        }
    }
    
    struct SubtitleBinding {
        let cutView: CutView
        let subtitle: Subtitle, oldSubtitle: Subtitle, phase: Phase
    }
    var subtitleBinding: ((SubtitleBinding) -> ())?
    struct SubtitleKeyframeBinding {
        let cutView: CutView
        let keyframe: Keyframe, subtitle: Subtitle, index: Int, setType: AnimationView.SetKeyframeType
        let animation: Animation, oldAnimation: Animation, phase: Phase
    }
    var subtitleKeyframeBinding: ((SubtitleKeyframeBinding) -> ())?
    
    func bind(in animationView: AnimationView, from node: Node, from track: NodeTrack) {
        animationView.splitKeyframeLabelClosure = { (keyframe, _) in
            track.isEmptyGeometryWithCells(at: keyframe.time) ? .main : .sub
        }
        animationView.lineColorClosure = { _ in
            track.transformItem != nil ? .camera : .content
        }
        animationView.smallLineColorClosure = {
            track.transformItem != nil ? .camera : .content
        }
        animationView.knobColorClosure = {
            track.drawingItem.keyDrawings[$0].draftLines.isEmpty ? .knob : .timelineDraft
        }
    }
    
    var beginBaseTime: Beat {
        didSet {
            tracks { animationViews[$2].beginBaseTime = beginBaseTime }
        }
    }
    
    var baseTimeInterval = Beat(1, 16) {
        didSet {
            animationViews.forEach { $0.baseTimeInterval = baseTimeInterval }
            updateWithDuration()
        }
    }
    
    var isEdit = false {
        didSet {
            animationViews.forEach { $0.isEdit = isEdit }
        }
    }
    
    var baseWidth: CGFloat {
        didSet {
            animationViews.forEach { $0.baseWidth = baseWidth }
            updateChildren()
            updateWithDuration()
        }
    }
    let knobHalfHeight: CGFloat, subKnobHalfHeight: CGFloat
    let maxLineWidth: CGFloat
    
    func x(withTime time: Beat) -> CGFloat {
        return DoubleBeat(time / baseTimeInterval).cf * baseWidth
    }
    
    override var locale: Locale {
        didSet {
            updateLayout()
        }
    }
    
    override var bounds: CGRect {
        didSet {
            updateLayout()
        }
    }
    
    func updateLayout() {
        let sp = Layout.smallPadding
        clipView.frame = CGRect(x: 0, y: 0, width: frame.width, height: classNameView.frame.minY - sp)
        updateWithNamePosition()
        updateChildren()
    }
    var nameX = Layout.smallPadding {
        didSet {
            updateWithNamePosition()
        }
    }
    func updateWithNamePosition() {
        let padding = Layout.smallPadding
        classNameView.frame.origin = CGPoint(x: nameX,
                                             y: bounds.height - classNameView.frame.height - padding)
    }
    func updateChildren() {
        guard let index = animationViews.index(of: editAnimationView) else {
            return
        }
        let midY = clipView.frame.height / 2
        var y = midY - editAnimationView.frame.height / 2
        editAnimationView.frame.origin = CGPoint(x: 0, y: y)
        for i in (0 ..< index).reversed() {
            let animationView = animationViews[i]
            y -= animationView.frame.height
            animationView.frame.origin = CGPoint(x: 0, y: y)
        }
        y = midY + editAnimationView.frame.height / 2
        for i in (index + 1 ..< animationViews.count) {
            let animationView = animationViews[i]
            animationView.frame.origin = CGPoint(x: 0, y: y)
            y += animationView.frame.height
        }
    }
    func updateWithDuration() {
        frame.size.width = x(withTime: cut.duration)
        animationViews.forEach { $0.frame.size.width = frame.width }
        subtitleAnimationView.frame.size.width = frame.width
    }
    func updateIfChangedEditTrack() {
        editAnimationView.animation = cut.editNode.editTrack.animation
        updateChildren()
    }
    func updateWithTime() {
        tracks { animationViews[$2].updateKeyframeIndex(with: $1.animation) }
    }
    
    var editNodeAndTrack: Cut.NodeAndTrack {
        get {
            return cut.editNodeAndTrack
        }
        set {
            cut.editNodeAndTrack = newValue
            editAnimationView = animationViews[cut.editNodeAndTrackIndex]
        }
    }
    
    func insert(_ node: Node, at index: Int, _ animationViews: [AnimationView], parent: Node) {
        parent.children.insert(node, at: index)
        let nodeAndTrackIndex = cut.nodeAndTrackIndex(with: Cut.NodeAndTrack(node: node,
                                                                             trackIndex: 0))
        self.animationViews.insert(contentsOf: animationViews, at: nodeAndTrackIndex)
        var children = self.clipView.children
        children.insert(contentsOf: animationViews, at: nodeAndTrackIndex)
        self.children = children
        updateChildren()
    }
    func remove(at index: Int, _ animationViews: [AnimationView], parent: Node) {
        let node = parent.children[index]
        let animationIndex = cut.nodeAndTrackIndex(with: Cut.NodeAndTrack(node: node, trackIndex: 0))
        let maxAnimationIndex = animationIndex + animationViews.count
        parent.children.remove(at: index)
        self.animationViews.removeSubrange(animationIndex..<maxAnimationIndex)
        var children = self.clipView.children
        children.removeSubrange(animationIndex..<maxAnimationIndex)
        self.children = children
        updateChildren()
    }
    func insert(_ track: NodeTrack, _ animationView: AnimationView,
                in nodeAndTrack: Cut.NodeAndTrack) {
        let i = cut.nodeAndTrackIndex(with: nodeAndTrack)
        nodeAndTrack.node.tracks.insert(track, at: nodeAndTrack.trackIndex)
        animationViews.insert(animationView, at: i)
        append(child: animationView)
        updateChildren()
    }
    func removeTrack(at nodeAndTrack: Cut.NodeAndTrack) {
        let i = cut.nodeAndTrackIndex(with: nodeAndTrack)
        nodeAndTrack.node.tracks.remove(at: nodeAndTrack.trackIndex)
        animationViews[i].removeFromParent()
        animationViews.remove(at: i)
        updateChildren()
    }
    func set(editTrackIndex: Int, in node: Node) {
        editNodeAndTrack = Cut.NodeAndTrack(node: node, trackIndex: editTrackIndex)
    }
    func moveNode(from oldIndex: Int, fromParemt oldParent: Node,
                  to index: Int, toParent parent: Node) {
        let node = oldParent.children[oldIndex]
        let moveAnimationViews = self.animationViews(with: node)
        let oldNodeAndTrack = Cut.NodeAndTrack(node: node, trackIndex: 0)
        let oldMaxAnimationIndex = cut.nodeAndTrackIndex(with: oldNodeAndTrack)
        let oldAnimationIndex = oldMaxAnimationIndex - (moveAnimationViews.count - 1)
        
        var animationViews = self.animationViews
        
        oldParent.children.remove(at: oldIndex)
        animationViews.removeSubrange(oldAnimationIndex...oldMaxAnimationIndex)
        
        parent.children.insert(node, at: index)
        
        let nodeAndTrack = Cut.NodeAndTrack(node: node, trackIndex: 0)
        let newMaxAnimationIndex = cut.nodeAndTrackIndex(with: nodeAndTrack)
        let newAnimationIndex = newMaxAnimationIndex - (moveAnimationViews.count - 1)
        animationViews.insert(contentsOf: moveAnimationViews, at: newAnimationIndex)
        self.animationViews = animationViews
        editAnimationView = animationViews[cut.editNodeAndTrackIndex]
    }
    func moveTrack(from oldIndex: Int, to index: Int, in node: Node) {
        let editTrack = node.tracks[oldIndex]
        var tracks = node.tracks
        tracks.remove(at: oldIndex)
        tracks.insert(editTrack, at: index)
        node.tracks = tracks
        
        let oldAnimationIndex = cut.nodeAndTrackIndex(with: Cut.NodeAndTrack(node: node,
                                                                             trackIndex: oldIndex))
        let newAnimationIndex = cut.nodeAndTrackIndex(with: Cut.NodeAndTrack(node: node,
                                                                             trackIndex: index))
        let editAnimationView = self.animationViews[oldAnimationIndex]
        var animationViews = self.animationViews
        animationViews.remove(at: oldAnimationIndex)
        animationViews.insert(editAnimationView, at: newAnimationIndex)
        self.animationViews = animationViews
        self.editAnimationView = animationViews[cut.editNodeAndTrackIndex]
    }
    
    var disabledRegisterUndo = true
    
    var isUseUpdateChildren = true
    
    var removeTrackClosure: ((CutView, Int, Node) -> ())?
    func removeTrack() {
        let node = cut.editNode
        if node.tracks.count > 1 {
            removeTrackClosure?(self, node.editTrackIndex, node)
        }
    }
    
    var deleteClosure: ((CutView) -> ())?
    func delete(for p: CGPoint) {
        deleteClosure?(self)
    }
    func copiedViewables(at p: CGPoint) -> [Viewable] {
        return [cut.copied]
    }
    var pasteClosure: ((CutView, [Any]) -> ())?
    func paste(_ objects: [Any], for p: CGPoint) {
        pasteClosure?(self, objects)
    }
    
    private var isScrollTrack = false
    func scroll(for p: CGPoint, time: Second, scrollDeltaPoint: CGPoint,
                phase: Phase, momentumPhase: Phase?) {
        if phase  == .began {
            isScrollTrack = abs(scrollDeltaPoint.x) < abs(scrollDeltaPoint.y)
        }
        guard isScrollTrack else {
            return
        }
        scrollTrack(for: p, time: time, scrollDeltaPoint: scrollDeltaPoint,
                    phase: phase, momentumPhase: momentumPhase)
    }
    
    struct ScrollBinding {
        let cutView: CutView
        let nodeAndTrack: Cut.NodeAndTrack, oldNodeAndTrack: Cut.NodeAndTrack
        let phase: Phase
    }
    var scrollClosure: ((ScrollBinding) -> ())?
    
    private struct ScrollObject {
        var oldP = CGPoint(), deltaScrollY = 0.0.cf
        var nodeAndTrackIndex = 0, oldNodeAndTrackIndex = 0
        var oldNodeAndTrack: Cut.NodeAndTrack?
    }
    private var scrollObject = ScrollObject()
    func scrollTrack(for p: CGPoint, time: Second, scrollDeltaPoint: CGPoint,
                     phase: Phase, momentumPhase: Phase?) {
        guard momentumPhase == nil else {
            return
        }
        switch phase {
        case .began:
            scrollObject = ScrollObject()
            scrollObject.oldP = p
            scrollObject.deltaScrollY = 0
            let editNodeAndTrack = self.editNodeAndTrack
            scrollObject.oldNodeAndTrack = editNodeAndTrack
            scrollObject.oldNodeAndTrackIndex = cut.nodeAndTrackIndex(with: editNodeAndTrack)
            scrollClosure?(ScrollBinding(cutView: self,
                                         nodeAndTrack: editNodeAndTrack,
                                         oldNodeAndTrack: editNodeAndTrack,
                                         phase: .began))
        case .changed:
            guard let oldEditNodeAndTrack = scrollObject.oldNodeAndTrack else {
                return
            }
            scrollObject.deltaScrollY += scrollDeltaPoint.y
            let maxIndex = cut.maxNodeAndTrackIndex
            let i = (scrollObject.oldNodeAndTrackIndex - Int(scrollObject.deltaScrollY / 10))
                .clip(min: 0, max: maxIndex)
            if i != scrollObject.nodeAndTrackIndex {
                isUseUpdateChildren = false
                scrollObject.nodeAndTrackIndex = i
                editNodeAndTrack = cut.nodeAndTrack(atNodeAndTrackIndex: i)
                scrollClosure?(ScrollBinding(cutView: self,
                                             nodeAndTrack: editNodeAndTrack,
                                             oldNodeAndTrack: oldEditNodeAndTrack,
                                             phase: .changed))
                isUseUpdateChildren = true
            }
        case .ended:
            guard let oldEditNodeAndTrack = scrollObject.oldNodeAndTrack else {
                return
            }
            scrollObject.deltaScrollY += scrollDeltaPoint.y
            let maxIndex = cut.maxNodeAndTrackIndex
            let i = (scrollObject.oldNodeAndTrackIndex - Int(scrollObject.deltaScrollY / 10))
                .clip(min: 0, max: maxIndex)
            isUseUpdateChildren = false
            editNodeAndTrack = cut.nodeAndTrack(atNodeAndTrackIndex: i)
            scrollClosure?(ScrollBinding(cutView: self,
                                         nodeAndTrack: editNodeAndTrack,
                                         oldNodeAndTrack: oldEditNodeAndTrack,
                                         phase: .ended))
            isUseUpdateChildren = true
            if i != scrollObject.oldNodeAndTrackIndex {
                registeringUndoManager?.registerUndo(withTarget: self) { [old = editNodeAndTrack] in
                    $0.set(oldEditNodeAndTrack, old: old)
                }
            }
            scrollObject.oldNodeAndTrack = nil
        }
    }
    private func set(_ editNodeAndTrack: Cut.NodeAndTrack, old oldEditNodeAndTrack: Cut.NodeAndTrack) {
        registeringUndoManager?.registerUndo(withTarget: self) {
            $0.set(oldEditNodeAndTrack, old: editNodeAndTrack)
        }
        scrollClosure?(ScrollBinding(cutView: self,
                                     nodeAndTrack: oldEditNodeAndTrack,
                                     oldNodeAndTrack: oldEditNodeAndTrack,
                                     phase: .began))
        isUseUpdateChildren = false
        self.editNodeAndTrack = editNodeAndTrack
        scrollClosure?(ScrollBinding(cutView: self,
                                     nodeAndTrack: oldEditNodeAndTrack,
                                     oldNodeAndTrack: editNodeAndTrack,
                                     phase: .ended))
        isUseUpdateChildren = true
    }
    
    func reference(at p: CGPoint) -> Reference {
        return Cut.reference
    }
}
