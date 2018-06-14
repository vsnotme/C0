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

import CoreGraphics

struct CellGroup: Codable, TreeNode, Equatable, Namable {
    var name: String
    
    var children: [CellGroup]
    
    var isHidden: Bool
    
    var effect: Effect, transform: Transform
    var drawing: Drawing
    var rootCell: Cell
    var selectedCellIndexes: [Cell.Index]
    
    init(name: String = "",
         children: [CellGroup] = [CellGroup](),
         isHidden: Bool = false,
         effect: Effect = Effect(),
         transform: Transform = Transform(),
         drawing: Drawing = Drawing(),
         rootCell: Cell = Cell(),
         selectedCellIndexes: [Cell.Index] = []) {
        
        self.name = name
        self.children = children
        self.isHidden = isHidden
        self.effect = effect
        self.transform = transform
        self.drawing = drawing
        self.rootCell = rootCell
        self.selectedCellIndexes = selectedCellIndexes
    }
}
extension CellGroup {
    var imageBounds: Rect {
        return rootCell.allImageBounds.union(drawing.imageBounds)
    }
    var allImageBounds: Rect {
        return children.reduce(into: imageBounds) { $0.formUnion($1.imageBounds) }
    }
    
    func worldAffineTransform(at index: TreeIndex<CellGroup>) -> AffineTransform {
        return nodes(at: index).reduce(transform.affineTransform) {
            $1.transform.affineTransform.concatenating($0)
        }
    }
    func worldScale(at index: CellGroup.Index) -> Real {
        return nodes(at: index).reduce(into: transform.scale.x) { $0 *= $1.transform.scale.x }
    }
    
    var selectedCellIndexesWithNotEmpty: [Cell.Index] {
        return selectedCellIndexes.filter { !rootCell[$0].isEmpty }
    }
    func selectedCellIndexesWithNotEmpty(at p: Point) -> [Cell.Index] {
        for cellIndex in selectedCellIndexes {
            if rootCell[cellIndex].contains(p) {
                return selectedCellIndexesWithNotEmpty
            }
        }
        return []
    }
    
    enum Indication {
        struct DrawingItem {
            var lineIndexes: [Int]
        }
        struct LineItem {
            var pointIndexes: [Int]
            //isPressure
        }
        
        case drawing(DrawingItem)
        case line(LineItem)
    }
    func indication(at p: Point, reciprocalScale: Real) -> Indication? {
        fatalError()
    }
    
    struct CellItem {
        var cell: Cell, cellIndex: Cell.Index
    }
    enum DrawingOrCell {
        case drawing(Drawing), cell(CellItem)
    }
    struct LinePoint {
        var line: Line, lineIndex: Int, pointIndex: Int
        var isFirst: Bool {
            return pointIndex == 0
        }
        var isLast: Bool {
            return  pointIndex == line.controls.count - 1
        }
    }
    struct LineCap {
        enum Orientation {
            case first, last
        }
        
        var line: Line, lineIndex: Int, orientation: Orientation
        
        init(line: Line, lineIndex: Int, orientation: Orientation) {
            self.line = line
            self.lineIndex = lineIndex
            self.orientation = orientation
        }
        init?(line: Line, lineIndex i: Int, at p: Point) {
            if p == line.firstPoint {
                self = LineCap(line: line, lineIndex: i, orientation: .first)
            } else if p == line.lastPoint {
                self = LineCap(line: line, lineIndex: i, orientation: .last)
            } else {
                return nil
            }
        }
        
        var pointIndex: Int {
            return orientation == .first ? 0 : line.controls.count - 1
        }
        var linePoint: LinePoint {
            return LinePoint(line: line, lineIndex: lineIndex, pointIndex: pointIndex)
        }
        var point: Point {
            return orientation == .first ? line.firstPoint : line.lastPoint
        }
        var reversedPoint: Point {
            return orientation == .first ? line.lastPoint : line.firstPoint
        }
    }
    struct LineItem {
        var linePoint: LinePoint, drawingOrCell: DrawingOrCell
    }
    struct LineCapItem {
        var lineCap: LineCap, drawingOrCell: DrawingOrCell
        
        var lineItem: LineItem {
            return LineItem(linePoint: lineCap.linePoint, drawingOrCell: drawingOrCell)
        }
    }
    struct LineCapsItem {
        struct DrawingCap {
            var drawing: Drawing, drawingLineCaps: [LineCap]
        }
        struct CellCap {
            var cellItem: CellItem, cellLineCaps: [LineCap]
        }
        var drawingCap: DrawingCap?, cellCaps: [CellCap]
        
        func bezierSortedLineCapItem(at p: Point) -> LineCapItem? {
            var minDrawing: Drawing?, minCellItem: CellItem?
            var minLineCap: LineCap?, minD² = Real.infinity
            func minNearest(with caps: [LineCap]) -> Bool {
                var isMin = false
                for cap in caps {
                    let d² = (cap.orientation == .first ?
                        cap.line.bezier(at: 0) :
                        cap.line.bezier(at: cap.line.controls.count - 3)).minDistance²(at: p)
                    if d² < minD² {
                        minLineCap = cap
                        minD² = d²
                        isMin = true
                    }
                }
                return isMin
            }
            
            if let drawingCap = drawingCap {
                if minNearest(with: drawingCap.drawingLineCaps) {
                    minDrawing = drawingCap.drawing
                }
            }
            for cellCap in cellCaps {
                if minNearest(with: cellCap.cellLineCaps) {
                    minDrawing = nil
                    minCellItem = cellCap.cellItem
                }
            }
            
            if let lineCap = minLineCap {
                if let drawing = minDrawing {
                    return LineCapItem(lineCap: lineCap, drawingOrCell: .drawing(drawing))
                } else if let cellItem = minCellItem {
                    return LineCapItem(lineCap: lineCap, drawingOrCell: .cell(cellItem))
                }
            }
            return nil
        }
    }
    struct Nearest {
        enum Result {
            struct LineCapResult {
                var bezierSortedLineCapItem: LineCapItem, lineCapsItem: LineCapsItem
            }
            
            case lineItem(LineItem), lineCapResult(LineCapResult)
        }
        
        var result: Result, minDistance²: Real, point: Point
    }
    func nearest(at point: Point, isVertex: Bool) -> Nearest? {
        var minD² = Real.infinity, minLinePoint: LinePoint?, minPoint = Point()
        func nearestLinePoint(from lines: [Line]) -> Bool {
            var isNearest = false
            for (j, line) in lines.enumerated() {
                for (i, mp) in line.mainPointSequence.enumerated() {
                    guard !(isVertex && i != 0 && i != line.controls.count - 1) else { continue }
                    let d² = hypot²(point.x - mp.x, point.y - mp.y)
                    if d² < minD² {
                        minD² = d²
                        minLinePoint = LinePoint(line: line, lineIndex: j, pointIndex: i)
                        minPoint = mp
                        isNearest = true
                    }
                }
            }
            return isNearest
        }
        
        var minDrawing: Drawing?, minCellItem: CellItem?
        if nearestLinePoint(from: drawing.lines) {
            minDrawing = drawing
        }
        for (i, cell) in rootCell.treeIndexEnumerated() {
            if nearestLinePoint(from: cell.geometry.lines) {
                minDrawing = nil
                minCellItem = CellItem(cell: cell, cellIndex: i)
            }
        }
        
        guard let linePoint = minLinePoint else { return nil }
        if linePoint.isFirst || linePoint.isLast {
            func lineCaps(with lines: [Line]) -> [LineCap] {
                return lines.enumerated().compactMap { (i, line) in
                    LineCap(line: line, lineIndex: i, at: minPoint)
                }
            }
            let drawingCap = LineCapsItem.DrawingCap(drawing: drawing,
                                                     drawingLineCaps: lineCaps(with: drawing.lines))
            let cellCaps: [LineCapsItem.CellCap] = rootCell.treeIndexEnumerated().compactMap {
                (i, cell) in
                
                let caps = lineCaps(with: cell.geometry.lines)
                return caps.isEmpty ?
                    nil : LineCapsItem.CellCap(cellItem: CellItem(cell: cell, cellIndex: i),
                                               cellLineCaps: caps)
            }
            let lineCapsItem = LineCapsItem(drawingCap: drawingCap, cellCaps: cellCaps)
            let bslci = lineCapsItem.bezierSortedLineCapItem(at: minPoint)!
            let result = Nearest.Result.LineCapResult(bezierSortedLineCapItem: bslci,
                                                      lineCapsItem: lineCapsItem)
            return Nearest(result: .lineCapResult(result), minDistance²: minD², point: minPoint)
        } else {
            if let drawing = minDrawing {
                let lineItem = LineItem(linePoint: linePoint, drawingOrCell: .drawing(drawing))
                return Nearest(result: .lineItem(lineItem), minDistance²: minD², point: minPoint)
            } else if let cellItem = minCellItem {
                let lineItem = LineItem(linePoint: linePoint, drawingOrCell: .cell(cellItem))
                return Nearest(result: .lineItem(lineItem), minDistance²: minD², point: minPoint)
            } else {
                fatalError()
            }
        }
    }
    
    func nearestLineItem(at p: Point) -> LineItem? {
        guard let nearest = self.nearest(at: p, isVertex: false) else {
            return nil
        }
        switch nearest.result {
        case .lineItem(let result): return result
        case .lineCapResult(let result): return result.bezierSortedLineCapItem.lineItem
        }
    }
    
    func snappedPoint(_ point: Point, with lci: LineCapItem,
                      snapDistance: Real, grid: Real?) -> Point {
        let p: Point
        if let grid = grid {
            p = Point(x: point.x.interval(scale: grid), y: point.y.interval(scale: grid))
        } else {
            p = point
        }
        
        var minD = Real.infinity, minP = p
        func updateMin(with ap: Point) {
            let d0 = p.distance(ap)
            if d0 < snapDistance && d0 < minD {
                minD = d0
                minP = ap
            }
        }
        func update(cellIndex: Cell.Index?) {
            for (i, line) in drawing.lines.enumerated() {
                if i == lci.lineCap.lineIndex {
                    updateMin(with: lci.lineCap.reversedPoint)
                } else {
                    updateMin(with: line.firstPoint)
                    updateMin(with: line.lastPoint)
                }
            }
            for (aCellIndex, cell) in rootCell.treeIndexEnumerated() {
                for (i, line) in cell.geometry.lines.enumerated() {
                    if aCellIndex == cellIndex && i == lci.lineCap.lineIndex {
                        updateMin(with: lci.lineCap.reversedPoint)
                    } else {
                        updateMin(with: line.firstPoint)
                        updateMin(with: line.lastPoint)
                    }
                }
            }
        }
        switch lci.drawingOrCell {
        case .drawing: update(cellIndex: nil)
        case .cell(let cellItem): update(cellIndex: cellItem.cellIndex)
        }
        return minP
    }
    
    func snappedPoint(_ sp: Point, editLine: Line, editingMaxPointIndex empi: Int,
                      snapDistance: Real) -> Point {
        let p: Point, isFirst = empi == 1 || empi == editLine.controls.count - 1
        if isFirst {
            p = editLine.firstPoint
        } else if empi == editLine.controls.count - 2 || empi == 0 {
            p = editLine.lastPoint
        } else {
            fatalError()
        }
        var snapLines = [(ap: Point, bp: Point)](), lastSnapLines = [(ap: Point, bp: Point)]()
        func snap(with lines: [Line]) {
            for line in lines {
                if editLine.controls.count == 3 {
                    if line != editLine {
                        if line.firstPoint == editLine.firstPoint {
                            snapLines.append((line.controls[1].point, editLine.firstPoint))
                        } else if line.lastPoint == editLine.firstPoint {
                            snapLines.append((line.controls[line.controls.count - 2].point,
                                              editLine.firstPoint))
                        }
                        if line.firstPoint == editLine.lastPoint {
                            lastSnapLines.append((line.controls[1].point, editLine.lastPoint))
                        } else if line.lastPoint == editLine.lastPoint {
                            lastSnapLines.append((line.controls[line.controls.count - 2].point,
                                                  editLine.lastPoint))
                        }
                    }
                } else {
                    if line.firstPoint == p && !(line == editLine && isFirst) {
                        snapLines.append((line.controls[1].point, p))
                    } else if line.lastPoint == p && !(line == editLine && !isFirst) {
                        snapLines.append((line.controls[line.controls.count - 2].point, p))
                    }
                }
            }
        }
        snap(with: drawing.lines)
        for cell in rootCell {
            snap(with: cell.geometry.lines)
        }
        
        var minD = Real.infinity, minIntersectionPoint: Point?, minPoint = sp
        if !snapLines.isEmpty && !lastSnapLines.isEmpty {
            for sl in snapLines {
                for lsl in lastSnapLines {
                    if let ip = Point.intersectionLine(sl.ap, sl.bp, lsl.ap, lsl.bp) {
                        let d = ip.distance(sp)
                        if d < snapDistance && d < minD {
                            minD = d
                            minIntersectionPoint = ip
                        }
                    }
                }
            }
        }
        if let minPoint = minIntersectionPoint {
            return minPoint
        } else {
            let ss = snapLines + lastSnapLines
            for sl in ss {
                let np = sp.nearestWithLine(ap: sl.ap, bp: sl.bp)
                let d = np.distance(sp)
                if d < snapDistance && d < minD {
                    minD = d
                    minPoint = np
                }
            }
            return minPoint
        }
    }
}
extension CellGroup {
//    func view(scale: Real, rotation: Real,
//              viewScale: Real, viewRotation: Real,
//              bounds: Rect) -> View {
//        let inScale = scale * transform.scale.x, inRotation = rotation + transform.rotation
//        let inViewScale = viewScale * transform.scale.x
//        let inViewRotation = viewRotation + transform.rotation
//        let reciprocalScale = 1 / inScale, reciprocalAllScale = 1 / inViewScale
//
//        ctx.concatenate(transform.affineTransform)
//
//        if viewType == .preview && !xSineWave.isEmpty {
//            let waveY = ySineWave.yWith(t: sineWaveT)
//            ctx.translateBy(x: waveY, y: 0)
//        }
//
//        let view = View()
//        view.isHidden = isHidden
//        view.bounds = bounds
//        view.effect = effect
//        view.children = drawing.viewWith() + children.enumerated().map { (i, cellGroup) in view(at: <#T##TreeIndex<CellGroup>#>, bounds: bounds) }
//    }
//
//    func editorView() -> VIew {
//
//        if !wat.isIdentity {
//            ctx.setStrokeColor(Color.locked.cg)
//            ctx.move(to: Point(x: -10, y: 0))
//            ctx.addLine(to: Point(x: 10, y: 0))
//            ctx.move(to: Point(x: 0, y: -10))
//            ctx.addLine(to: Point(x: 0, y: 10))
//            ctx.strokePath()
//        }
//
//
//    }
//
//    func drawTransform(_ cameraFrame: Rect, in ctx: CGContext) {
//        func drawCameraBorder(bounds: Rect, inColor: Color, outColor: Color) {
//            ctx.setStrokeColor(inColor.cg)
//            ctx.stroke(bounds.insetBy(dx: -0.5, dy: -0.5))
//            ctx.setStrokeColor(outColor.cg)
//            ctx.stroke(bounds.insetBy(dx: -1.5, dy: -1.5))
//        }
//        ctx.setLineWidth(1)
//        if !xSineWave.isEmpty {
//            let amplitude = xSineWave.amplitude
//            drawCameraBorder(bounds: cameraFrame.insetBy(dx: -amplitude, dy: 0),
//                             inColor: Color.cameraBorder, outColor: Color.cutSubBorder)
//        }
//        let track = editTrack
//        func drawPreviousNextCamera(t: Transform, color: Color) {
//            let affine = transform.affineTransform.inverted() * t.affineTransform
//            ctx.saveGState()
//            ctx.concatenate(affine)
//            drawCameraBorder(bounds: cameraFrame, inColor: color, outColor: Color.cutSubBorder)
//            ctx.restoreGState()
//            func strokeBounds() {
//                ctx.move(to: Point(x: cameraFrame.minX, y: cameraFrame.minY))
//                ctx.addLine(to: Point(x: cameraFrame.minX, y: cameraFrame.minY) * affine)
//                ctx.move(to: Point(x: cameraFrame.minX, y: cameraFrame.maxY))
//                ctx.addLine(to: Point(x: cameraFrame.minX, y: cameraFrame.maxY) * affine)
//                ctx.move(to: Point(x: cameraFrame.maxX, y: cameraFrame.minY))
//                ctx.addLine(to: Point(x: cameraFrame.maxX, y: cameraFrame.minY) * affine)
//                ctx.move(to: Point(x: cameraFrame.maxX, y: cameraFrame.maxY))
//                ctx.addLine(to: Point(x: cameraFrame.maxX, y: cameraFrame.maxY) * affine)
//            }
//            ctx.setStrokeColor(color.cg)
//            strokeBounds()
//            ctx.strokePath()
//            ctx.setStrokeColor(Color.cutSubBorder.cg)
//            strokeBounds()
//            ctx.strokePath()
//        }
//        let lki = track.animation.indexInfo(withTime: time)
//        if lki.keyframeInternalTime == 0 && lki.keyframeIndex > 0 {
//            if let t = track.transformItem?.keyTransforms[lki.keyframeIndex - 1], transform != t {
//                drawPreviousNextCamera(t: t, color: .red)
//            }
//        }
//        if let t = track.transformItem?.keyTransforms[lki.keyframeIndex], transform != t {
//            drawPreviousNextCamera(t: t, color: .red)
//        }
//        if lki.keyframeIndex < track.animation.keyframes.count - 1 {
//            if let t = track.transformItem?.keyTransforms[lki.keyframeIndex + 1], transform != t {
//                drawPreviousNextCamera(t: t, color: .green)
//            }
//        }
//        drawCameraBorder(bounds: cameraFrame, inColor: Color.locked, outColor: Color.cutSubBorder)
//    }
//
//    private static let editPointRadius = 0.5.cg, lineEditPointRadius = 1.5.cg
//    private static let pointEditPointRadius = 3.0.cg
//    func drawEditPoints(with editPoint: EditPoint?, isEditVertex: Bool,
//                        reciprocalAllScale: Real, in ctx: CGContext) {
//        if let ep = editPoint, ep.isSnap {
//            let p: Point?, np: Point?
//            if ep.nearestPointIndex == 1 {
//                p = ep.nearestLine.firstPoint
//                np = ep.nearestLine.controls.count == 2 ?
//                    nil : ep.nearestLine.controls[2].point
//            } else if ep.nearestPointIndex == ep.nearestLine.controls.count - 2 {
//                p = ep.nearestLine.lastPoint
//                np = ep.nearestLine.controls.count == 2 ?
//                    nil :
//                    ep.nearestLine.controls[ep.nearestLine.controls.count - 3].point
//            } else {
//                p = nil
//                np = nil
//            }
//            if let p = p {
//                func drawSnap(with point: Point, capPoint: Point) {
//                    if let ps = Point.boundsPointWithLine(ap: point, bp: capPoint,
//                                                          bounds: ctx.boundingBoxOfClipPath) {
//                        ctx.move(to: ps.p0)
//                        ctx.addLine(to: ps.p1)
//                        ctx.setLineWidth(1 * reciprocalAllScale)
//                        ctx.setStrokeColor(Color.selected.cg)
//                        ctx.strokePath()
//                    }
//                    if let np = np, ep.nearestLine.controls.count > 2 {
//                        let p1 = ep.nearestPointIndex == 1 ?
//                            ep.nearestLine.controls[1].point :
//                            ep.nearestLine.controls[ep.nearestLine.controls.count - 2].point
//                        ctx.move(to: p1.mid(np))
//                        ctx.addLine(to: p1)
//                        ctx.addLine(to: capPoint)
//                        ctx.setLineWidth(0.5 * reciprocalAllScale)
//                        ctx.setStrokeColor(Color.selected.cg)
//                        ctx.strokePath()
//                        p1.draw(radius: 2 * reciprocalAllScale, lineWidth: reciprocalAllScale,
//                                inColor: Color.selected, outColor: Color.controlPointIn, in: ctx)
//                    }
//                }
//                func drawSnap(with lines: [Line]) {
//                    for line in lines {
//                        if line != ep.nearestLine {
//                            if ep.nearestLine.controls.count == 3 {
//                                if line.firstPoint == ep.nearestLine.firstPoint {
//                                    drawSnap(with: line.controls[1].point,
//                                             capPoint: ep.nearestLine.firstPoint)
//                                } else if line.lastPoint == ep.nearestLine.firstPoint {
//                                    drawSnap(with: line.controls[line.controls.count - 2].point,
//                                             capPoint: ep.nearestLine.firstPoint)
//                                }
//                                if line.firstPoint == ep.nearestLine.lastPoint {
//                                    drawSnap(with: line.controls[1].point,
//                                             capPoint: ep.nearestLine.lastPoint)
//                                } else if line.lastPoint == ep.nearestLine.lastPoint {
//                                    drawSnap(with: line.controls[line.controls.count - 2].point,
//                                             capPoint: ep.nearestLine.lastPoint)
//                                }
//                            } else {
//                                if line.firstPoint == p {
//                                    drawSnap(with: line.controls[1].point, capPoint: p)
//                                } else if line.lastPoint == p {
//                                    drawSnap(with: line.controls[line.controls.count - 2].point,
//                                             capPoint: p)
//                                }
//                            }
//                        } else if line.firstPoint == line.lastPoint {
//                            if ep.nearestPointIndex == line.controls.count - 2 {
//                                drawSnap(with: line.controls[1].point, capPoint: p)
//                            } else if ep.nearestPointIndex == 1 && p == line.firstPoint {
//                                drawSnap(with: line.controls[line.controls.count - 2].point,
//                                         capPoint: p)
//                            }
//                        }
//                    }
//                }
//                drawSnap(with: editTrack.drawing.lines)
//                for cell in editTrack.cells {
//                    drawSnap(with: cell.geometry.lines)
//                }
//            }
//        }
//        editPoint?.draw(withReciprocalAllScale: reciprocalAllScale,
//                        lineColor: .selected,
//                        in: ctx)
//
//        var capPointDic = [Point: Bool]()
//        func updateCapPointDic(with lines: [Line]) {
//            for line in lines {
//                let fp = line.firstPoint, lp = line.lastPoint
//                if capPointDic[fp] != nil {
//                    capPointDic[fp] = true
//                } else {
//                    capPointDic[fp] = false
//                }
//                if capPointDic[lp] != nil {
//                    capPointDic[lp] = true
//                } else {
//                    capPointDic[lp] = false
//                }
//            }
//        }
//        if !editTrack.geometryItems.isEmpty {
//            for cell in editTrack.cells {
//                if !cell.isLocked {
//                    if !isEditVertex {
//                        Line.drawEditPointsWith(lines: cell.geometry.lines,
//                                                reciprocalScale: reciprocalAllScale, in: ctx)
//                    }
//                    updateCapPointDic(with: cell.geometry.lines)
//                }
//            }
//        }
//        if !isEditVertex {
//            Line.drawEditPointsWith(lines: editTrack.drawing.lines,
//                                    reciprocalScale: reciprocalAllScale, in: ctx)
//        }
//        updateCapPointDic(with: editTrack.drawing.lines)
//
//        let r = CellGroup.lineEditPointRadius * reciprocalAllScale, lw = 0.5 * reciprocalAllScale
//        for v in capPointDic {
//            v.key.draw(radius: r, lineWidth: lw,
//                       inColor: v.value ? .controlPointJointIn : .controlPointCapIn,
//                       outColor: .controlPointOut, in: ctx)
//        }
//    }
}
extension CellGroup: Referenceable {
    static let name = Text(english: "CellGroup", japanese: "ノード")
}
extension CellGroup: ThumbnailViewable {
    func thumbnailView(withFrame frame: Rect) -> View {
        return name.thumbnailView(withFrame: frame)
    }
}
extension CellGroup: AbstractViewable {
    func abstractViewWith<T : BinderProtocol>(binder: T,
                                              keyPath: ReferenceWritableKeyPath<T, CellGroup>,
                                              type: AbstractType) -> ModelView {
        switch type {
        case .normal:
            return CellGroupView(binder: binder, keyPath: keyPath)
        case .mini:
            return MiniView(binder: binder, keyPath: keyPath)
        }
    }
}
extension CellGroup: ObjectViewable {}

struct CellGroupChildren: KeyframeValue {
    var children = [CellGroup]()
    var editingTreeIndex = TreeIndex<CellGroup>()
    
    static func linear(_ f0: CellGroupChildren, _ f1: CellGroupChildren,
                       t: Real) -> CellGroupChildren {
        return f0
    }
    static func firstMonospline(_ f1: CellGroupChildren,
                                _ f2: CellGroupChildren, _ f3: CellGroupChildren,
                                with ms: Monospline) -> CellGroupChildren {
        return f1
    }
    static func monospline(_ f0: CellGroupChildren, _ f1: CellGroupChildren,
                           _ f2: CellGroupChildren, _ f3: CellGroupChildren,
                           with ms: Monospline) -> CellGroupChildren {
        return f1
    }
    static func lastMonospline(_ f0: CellGroupChildren,
                               _ f1: CellGroupChildren, _ f2: CellGroupChildren,
                               with ms: Monospline) -> CellGroupChildren {
        return f1
    }
}
extension CellGroupChildren: Referenceable {
    static let name = Text(english: "Cell Group Children",
                           japanese: "セルグループチルドレン")
}
extension CellGroupChildren: ThumbnailViewable {
    func thumbnailView(withFrame frame: Rect) -> View {
        return children.count.thumbnailView(withFrame: frame)
    }
}
extension CellGroupChildren: AbstractViewable {
    func abstractViewWith<T>(binder: T, keyPath: ReferenceWritableKeyPath<T, CellGroupChildren>,
                             type: AbstractType) -> ModelView where T : BinderProtocol {
        switch type {
        case .normal: return CellGroupChildrenView(binder: binder, keyPath: keyPath)
        case .mini: return MiniView(binder: binder, keyPath: keyPath)
        }
    }
}

struct CellGroupChildrenTrack: Track, Codable {
    var animation = Animation<CellGroupChildren>()
    var animatable: Animatable {
        return animation
    }
}
extension CellGroupChildrenTrack: Referenceable {
    static let name = Text(english: "Cell Group Children Track", japanese: "セルグループ配列トラック")
}

final class CellGroupView<T: BinderProtocol>: ModelView, BindableReceiver {
    typealias Model = CellGroup
    typealias Binder = T
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((CellGroupView<Binder>, BasicNotification) -> ())]()
    
    var defaultModel = Model()
    
    private let classNameView: TextFormView
    private let isHiddenView: BoolView<Binder>
    
    init(binder: Binder, keyPath: BinderKeyPath) {
        self.binder = binder
        self.keyPath = keyPath
        
        classNameView = TextFormView(text: CellGroup.name, font: .bold)
        isHiddenView = BoolView(binder: binder, keyPath: keyPath.appending(path: \Model.isHidden),
                                option: BoolOption(defaultModel: false, cationModel: true,
                                                   name: "", info: .hidden))
        
        super.init(isLocked: false)
        children = [classNameView, isHiddenView]
    }
    
    var minSize: Size {
        let padding = Layouter.basicPadding, h = Layouter.basicHeight
        let tlw = classNameView.minSize.width + isHiddenView.minSize.width + padding * 3
        return Size(width: tlw, height: h + padding * 2)
    }
    override func updateLayout() {
        let padding = Layouter.basicPadding
        let classNameSize = classNameView.minSize
        let classNameOrigin = Point(x: padding,
                                    y: bounds.height - classNameSize.height - padding)
        classNameView.frame = Rect(origin: classNameOrigin, size: classNameSize)
        isHiddenView.frame = Rect(x: classNameView.frame.maxX + padding, y: padding,
                                  width: bounds.width - classNameView.frame.width - padding * 3,
                                  height: Layouter.basicHeight)
    }
}

final class CellGroupChildrenView<T: BinderProtocol>: ModelView, BindableGetterReceiver {
    typealias Model = CellGroupChildren
    typealias Binder = T
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((CellGroupView<Binder>, BasicNotification) -> ())]()
    
    private let classNameView: TextFormView
    
    init(binder: Binder, keyPath: BinderKeyPath) {
        self.binder = binder
        self.keyPath = keyPath
        
        classNameView = TextFormView(text: CellGroupChildren.name, font: .bold)
        
        super.init(isLocked: false)
        children = [classNameView]
    }
    
    var minSize: Size {
        return classNameView.minSize + Layouter.basicPadding * 2
    }
    override func updateLayout() {
        let padding = Layouter.basicPadding
        let classNameSize = classNameView.minSize
        let classNameOrigin = Point(x: padding,
                                    y: bounds.height - classNameSize.height - padding)
        classNameView.frame = Rect(origin: classNameOrigin, size: classNameSize)
    }
}
