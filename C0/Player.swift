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
import AVFoundation

protocol PlayerDelegate: class {
    func endPlay(_ player: Player)
}
final class Player: LayerRespondable {
    static let name = Localization(english: "Player", japanese: "プレイヤー")
    
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: [])
        }
    }
    
    weak var delegate: PlayerDelegate?
    
    let layer = CALayer.interfaceLayer(), drawLayer = DrawLayer()
    var playCutItem: CutItem? {
        didSet {
            if let playCutItem = playCutItem {
                self.cut = playCutItem.cut.deepCopy
            }
        }
    }
    var cut = Cut()
    var time: Beat {
        get {
            return cut.time
        } set {
            cut.time = newValue
        }
    }
    var scene = Scene() {
        didSet {
            updateChildren()
        }
    }
    func updateChildren() {
        CATransaction.disableAnimation {
            let paddingWidth = (bounds.width - scene.frame.size.width) / 2
            let paddingHeight = (bounds.height - scene.frame.size.height) / 2
            drawLayer.frame = CGRect(origin: CGPoint(x: paddingWidth, y: paddingHeight), size: scene.frame.size)
            screenTransform = CGAffineTransform(translationX: drawLayer.bounds.midX, y: drawLayer.bounds.midY)
        }
    }
    func draw(in ctx: CGContext) {
        ctx.concatenate(screenTransform)
        cut.rootNode.draw(
            scene: scene, viewType: .preview,
            scale: 1, rotation: 0, viewScale: scene.scale, viewRotation: scene.viewTransform.rotation,
            in: ctx
        )
    }
    
    init() {
        layer.backgroundColor = Color.playBorder.cgColor
        drawLayer.borderWidth = 0
        drawLayer.drawBlock = { [unowned self] ctx in
            self.draw(in: ctx)
        }
        layer.addSublayer(drawLayer)
    }
    
    var screenTransform = CGAffineTransform.identity
    var frame: CGRect {
        get {
            return layer.frame
        } set {
            layer.frame = newValue
            updateChildren()
        }
    }
    
    var editCutItem = CutItem()
    var audioPlayer: AVAudioPlayer?
    
    var contentsScale: CGFloat {
        get {
            return layer.contentsScale
        } set {
            layer.contentsScale = newValue
            drawLayer.contentsScale = newValue
            allChildren { ($0 as? LayerRespondable)?.layer.contentsScale = newValue }
        }
    }
    
    private var playDrawCount = 0, playCutIndex = 0, playSecond = 0, playFrameRate = FPS(0), delayTolerance = 0.5
    var didSetTimeHandler: ((Beat) -> (Void))? = nil
    var didSetCutIndexHandler: ((Int) -> (Void))? = nil
    var didSetPlayFrameRateHandler: ((Int) -> (Void))? = nil
    
    private var timer = LockTimer(), oldPlayCutItem: CutItem?, oldPlayTime = Beat(0), oldTimestamp = 0.0
    var isPlaying = false {
        didSet {
            if isPlaying {
                playCutItem = editCutItem
                oldPlayCutItem = editCutItem
                time = editCutItem.cut.time
                oldPlayTime = editCutItem.cut.time
                oldTimestamp = CFAbsoluteTimeGetCurrent()
                let t = currentPlayTime
                playSecond = t.integralPart
                playCutIndex = scene.editCutItemIndex
                playFrameRate = scene.frameRate
                playDrawCount = 0
                if let url = scene.soundItem.url {
                    do {
                        try audioPlayer = AVAudioPlayer(contentsOf: url)
                    } catch {
                    }
                }
                audioPlayer?.currentTime = scene.secondTime(withBeatTime: t)
                audioPlayer?.play()
                timer.begin(interval: 1 / Second(scene.frameRate), tolerance: 0.1 / Second(scene.frameRate)) { [unowned self] in
                    self.updatePlayTime()
                }
                drawLayer.setNeedsDisplay()
            } else {
                timer.stop()
                playCutItem = nil
                audioPlayer?.stop()
                audioPlayer = nil
                drawLayer.contents = nil
            }
        }
    }
    var isPause = false {
        didSet {
            if isPause {
                timer.stop()
                audioPlayer?.pause()
            } else {
                timer.begin(interval: 1 / Second(scene.frameRate), tolerance: 0.1 / Second(scene.frameRate)) { [unowned self] in
                    self.updatePlayTime()
                }
                audioPlayer?.play()
            }
        }
    }
    var beatFrameTime: Beat {
        return scene.beatTime(withFrameTime: 1)
    }
    private func updatePlayTime() {
        if let playCutItem = playCutItem {
            var updated = false
            if let audioPlayer = audioPlayer, !scene.soundItem.isHidden {
                let t = scene.beatTime(withSecondTime: audioPlayer.currentTime)
                let pt = currentPlayTime + beatFrameTime
                if abs(pt - t) > beatFrameTime {
                    let viewIndex = scene.cutItemIndex(withTime: t)
                    if viewIndex.isOver {
                        self.playCutItem = scene.cutItems[0]
                        self.time = 0
                        audioPlayer.currentTime = 0
                    } else {
                        let cutItem = scene.cutItems[viewIndex.index]
                        if cutItem != playCutItem {
                            self.playCutItem = cutItem
                        }
                        time = viewIndex.interTime
                    }
                    updated = true
                }
            }
            if !updated {
                let nextTime = time + beatFrameTime
                if nextTime < playCutItem.cut.timeLength {
                    time = nextTime
                } else if scene.cutItems.count == 1 {
                    time = 0
                } else {
                    let cutIndex = scene.cutItems.index(of: playCutItem) ?? 0
                    let nextCutIndex = cutIndex + 1 <= scene.cutItems.count - 1 ? cutIndex + 1 : 0
                    let nextCutItem = scene.cutItems[nextCutIndex]
                    self.playCutItem = nextCutItem
                    time = 0
                    if nextCutIndex == 0 {
                        audioPlayer?.currentTime = 0
                    }
                }
                drawLayer.setNeedsDisplay()
            }
            
            updateBinding()
        }
    }
    func updateBinding() {
        let t = currentPlayTime
        didSetTimeHandler?(t)
        //            let s = t.integralPart
        //            if s != playSecond {
        //                playSecond = s
        //                timeLabel.text.string = minuteSecondString(withSecond: playSecond, frameRate: scene.frameRate)
        //            }
        
        if let playCutItem = playCutItem, let cutItemIndex = scene.cutItems.index(of: playCutItem), playCutIndex != cutItemIndex {
            playCutIndex = cutItemIndex
            didSetCutIndexHandler?(cutItemIndex)
            //                cutLabel.text.string = "No.\(playCutIndex)"
        }
        
        playDrawCount += 1
        let newTimestamp = CFAbsoluteTimeGetCurrent()
        let deltaTime = newTimestamp - oldTimestamp
        if deltaTime >= 1 {
            let newPlayFrameRate = min(scene.frameRate, Int(round(Double(playDrawCount) / deltaTime)))
            if newPlayFrameRate != playFrameRate {
                playFrameRate = newPlayFrameRate
                didSetPlayFrameRateHandler?(playFrameRate)
                //                    frameRateLabel.text.string = "\(playFrameRate) fps"
                //                    frameRateLabel.text.textFrame.color = playFrameRate != scene.frameRate ? .warning : .locked
            }
            oldTimestamp = newTimestamp
            playDrawCount = 0
        }
    }
    
    var currentPlayTime: Beat {
        get {
            var t = Beat(0)
            for entity in scene.cutItems {
                if playCutItem != entity {
                    t += entity.cut.timeLength
                } else {
                    t += time
                    break
                }
            }
            return t
        }
        set {
            let viewIndex = scene.cutItemIndex(withTime: newValue)
            let cutItem = scene.cutItems[viewIndex.index]
            if cutItem != playCutItem {
                self.playCutItem = cutItem
            }
            time = viewIndex.interTime
            
            audioPlayer?.currentTime = scene.secondTime(withBeatTime: newValue)
            
            drawLayer.setNeedsDisplay()
            
            updateBinding()
        }
    }
    
    func play(with event: KeyInputEvent) {
        play()
    }
    func play() {
        if isPlaying {
            isPlaying = false
            isPlaying = true
        } else {
            isPlaying = true
        }
    }
//    func cut(with event: KeyInputEvent) -> CopyObject {
//        stop()
//        return CopyObject()
//    }
    
    func zoom(with event: PinchEvent) {
    }
    func rotate(with event: RotateEvent) {
    }
    func stop() {
        if isPlaying {
            isPlaying = false
        }
        delegate?.endPlay(self)
    }
    
    func drag(with event: DragEvent) {
    }
    func scroll(with event: ScrollEvent) {
    }
}

final class PlayerEditor: LayerRespondable, SliderDelegate {
    static let name = Localization(english: "Player Editor", japanese: "プレイヤーエディタ")
    
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: [])
        }
    }
    
    var contentsScale: CGFloat {
        get {
            return layer.contentsScale
        } set {
            layer.contentsScale = newValue
            timeLabel.contentsScale = newValue
            cutLabel.contentsScale = newValue
            frameRateLabel.contentsScale = newValue
        }
    }
    
    private let timeLabelWidth = 40.0.cf, sliderWidth = 300.0.cf
    let playLabel = Label(
        text: Localization(english: "Indication Play", japanese: "指し示して再生"), color: .locked
    )
    let slider = Slider(
        min: 0, max: 1,
        description: Localization(english: "Play Time", japanese: "再生時間")
    )
    let timeLabel = Label(text: Localization("0:00"), color: .locked)
    let cutLabel = Label(text: Localization("No.0"), color: .locked)
    let frameRateLabel = Label(text: Localization("0 fps"), color: .locked)
    
    let layer = CALayer.interfaceLayer()
    init() {
        self.children = [playLabel]
        update(withChildren: children, oldChildren: [])
        
        slider.delegate = self
    }
    
    var frame: CGRect {
        get {
            return layer.frame
        } set {
            layer.frame = newValue
            updateChildren()
        }
    }
    func updateChildren() {
        CATransaction.disableAnimation {
            let padding = Layout.basicPadding, height = Layout.basicHeight
            let sliderY = round((frame.height - height) / 2)
            let labelHeight = Layout.basicHeight - padding * 2
            let labelY = round((frame.height - labelHeight) / 2)
            playLabel.frame.origin = CGPoint(x: Layout.basicPadding, y: labelY)
            var x = round((frame.width - slider.frame.width) / 2)
            slider.frame = CGRect(
                x: x, y: sliderY,
                width: sliderWidth, height: height
            )
            
            let shapeLayer = CAShapeLayer()
            shapeLayer.path = CGPath(rect: CGRect(x: slider.viewPadding, y: slider.bounds.midY - 1, width: slider.frame.width - slider.viewPadding * 2, height: 2), transform: nil)
            shapeLayer.fillColor = Color.content.cgColor
            slider.layer.sublayers = [shapeLayer, slider.knobLayer]
            
            x += sliderWidth + padding
            timeLabel.frame.origin = CGPoint(x: x, y: labelY)
            x += timeLabelWidth
            cutLabel.frame.origin = CGPoint(x: x, y: labelY)
            x += timeLabelWidth
            frameRateLabel.frame.origin = CGPoint(x: x, y: labelY)
        }
    }
    
    var isSubIndication = false {
        didSet {
            isPlayingBinding?(isSubIndication)
            isPlaying = isSubIndication
        }
    }
    var isPlayingBinding: ((Bool) -> (Void))? = nil
    var isPlaying = false {
        didSet {
            if isPlaying {
                children = [playLabel, slider, timeLabel, cutLabel, frameRateLabel]
            } else {
                children = [playLabel]
            }
            updateChildren()
        }
    }
    
    var time = Second(0.0) {
        didSet {
            slider.value = CGFloat(time)
            second = Int(time)
        }
    }
    var maxTime = Second(1.0) {
        didSet {
            slider.maxValue = Double(maxTime).cf
        }
    }
    private(set) var second = 0 {
        didSet {
            guard second != oldValue else {
                return
            }
            timeLabel.text.string = minuteSecondString(withSecond: second, frameRate: frameRate)
//            timeLabel.text.string = "\(minuteSecondString(withSecond: second, frameRate: frameRate))    No.\(cutIndex)  \(playFrameRate) (\(frameRate)) fps"

        }
    }
    func minuteSecondString(withSecond s: Int, frameRate: FPS) -> String {
        if s >= 60 {
            let minute = s / 60
            let second = s - minute * 60
            return String(format: "%d:%02d", minute, second)
        } else {
            return String(format: "0:%02d", s)
        }
    }
    var cutIndex = 0 {
        didSet {
            cutLabel.text.string = "No.\(cutIndex)"
        }
    }
    var playFrameRate = 1 {
        didSet {
            frameRateLabel.text.string = "\(playFrameRate) fps"
            frameRateLabel.text.textFrame.color = playFrameRate < frameRate ? .warning : .locked
        }
    }
    var frameRate = 1 {
        didSet {
            playFrameRate = frameRate
            frameRateLabel.text.string = "\(playFrameRate) fps"
            frameRateLabel.text.textFrame.color = playFrameRate < frameRate ? .warning : .locked
        }
    }
    
    var timeBinding: ((Second, Action.SendType) -> (Void))? = nil
    func changeValue(_ slider: Slider, value: CGFloat, oldValue: CGFloat, type: Action.SendType) {
        time = Second(value)
        timeBinding?(time, type)
    }
}
