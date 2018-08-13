//
//  Created by Artem Sidorenko on 9/14/15.
//  Copyright © 2015 Yalantis. All rights reserved.
//
//  Licensed under the MIT license: http://opensource.org/licenses/MIT
//  Latest version can be found at https://github.com/Yalantis/StarWars.iOS
//

import UIKit
import GLKit

open class StarWarsGLAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    
    open var duration: TimeInterval = 2
    open var spriteWidth: CGFloat = 8
    
    fileprivate var sprites: [Sprite] = []
    fileprivate var glContext: EAGLContext!
    fileprivate var effect: GLKBaseEffect!
    fileprivate var glView: GLKView!
    fileprivate var displayLink: CADisplayLink!
    fileprivate var lastUpdateTime: TimeInterval?
    fileprivate var startTransitionTime: TimeInterval!
    fileprivate var transitionContext: UIViewControllerContextTransitioning!
    fileprivate var render: SpriteRender!
    
    open func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return duration
    }
    
    open func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let containerView = transitionContext.containerView
        let fromView = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.from)!.view
        let toView = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.to)!.view
        
        containerView.addSubview(toView!)
        containerView.sendSubview(toBack: toView!)
        
        func randomFloatBetween(_ smallNumber: CGFloat, and bigNumber: CGFloat) -> Float {
            let diff = bigNumber - smallNumber
            return Float((CGFloat(arc4random()) / 100.0).truncatingRemainder(dividingBy: diff) + smallNumber)
        }
        
        self.glContext = EAGLContext(api: .openGLES2)
        EAGLContext.setCurrent(glContext)
        
        glView = GLKView(frame: (fromView?.frame)!, context: glContext)
        glView.enableSetNeedsDisplay = true
        glView.delegate = self
        glView.isOpaque = false
        containerView.addSubview(glView)

        let texture = ViewTexture()
        texture.setupOpenGL()
        texture.render(view: fromView!)
        
        effect = GLKBaseEffect()
        let projectionMatrix = GLKMatrix4MakeOrtho(0, Float(texture.width), 0, Float(texture.height), -1, 1)
        effect.transform.projectionMatrix = projectionMatrix
        
        render = SpriteRender(texture: texture, effect: effect)
        
        let size = CGSize(width: CGFloat(texture.width), height: CGFloat(texture.height))
        
        let scale = UIScreen.main.scale
        let width = spriteWidth * scale
        let height = width
        
        for x in stride(from: CGFloat(0), through: size.width, by: width) {
            for y in stride(from: CGFloat(0), through: size.height, by: height) {
                let region = CGRect(x: x, y: y, width: width, height: height)
                var sprite = Sprite()
                sprite.slice(region, textureSize: size)
                sprite.moveVelocity = Vector2(x: randomFloatBetween(-100, and: 100), y: randomFloatBetween(-CGFloat(texture.height)*1.3/CGFloat(duration), and: -CGFloat(texture.height)/CGFloat(duration)))

                sprites.append(sprite)
            }
        }
        fromView?.removeFromSuperview()
        self.transitionContext = transitionContext
        
        displayLink = CADisplayLink(target: self, selector: #selector(StarWarsGLAnimator.displayLinkTick(_:)))
        displayLink.isPaused = false
        displayLink.add(to: RunLoop.main, forMode: RunLoopMode.commonModes)
        
        self.startTransitionTime = Date.timeIntervalSinceReferenceDate        
    }
    
    open func animationEnded(_ transitionCompleted: Bool) {
        displayLink.invalidate()
        displayLink = nil
    }
    
    @objc func displayLinkTick(_ displayLink: CADisplayLink) {
        if let lastUpdateTime = lastUpdateTime {
            let timeSinceLastUpdate = Date.timeIntervalSinceReferenceDate - lastUpdateTime
            self.lastUpdateTime = Date.timeIntervalSinceReferenceDate
            for index in 0..<sprites.count {
                sprites[index].update(timeSinceLastUpdate)
            }
        } else {
            lastUpdateTime = Date.timeIntervalSinceReferenceDate
        }
        glView.setNeedsDisplay()
        if Date.timeIntervalSinceReferenceDate - startTransitionTime > duration {
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
    }
}

extension StarWarsGLAnimator: GLKViewDelegate {
    
    public func glkView(_ view: GLKView, drawIn rect: CGRect) {
        glClearColor(0, 0, 0, 0)
        glClear(UInt32(GL_COLOR_BUFFER_BIT))
        glBlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE_MINUS_SRC_ALPHA))
        glEnable(GLenum(GL_BLEND))
        
        render.render(self.sprites)
    }
}

struct TexturedVertex {
    var geometryVertex = Vector2()
    var textureVertex = Vector2()
}

struct TexturedQuad {
    var bl = TexturedVertex()
    var br = TexturedVertex() { didSet { _br = br } }
    var tl = TexturedVertex() { didSet { _tl = tl } }
    var tr = TexturedVertex()

    // openGL optimization. it uses triangles to draw.
    // so we duplicate 2 vertex, so it have 6 vertex to draw two triangles
    fileprivate var _br = TexturedVertex()
    fileprivate var _tl = TexturedVertex()
}

struct Sprite {
    var quad = TexturedQuad()
    var moveVelocity = Vector2()

    mutating func slice(_ rect: CGRect, textureSize: CGSize) {
        quad.bl.geometryVertex = Vector2(x: 0, y: 0)
        quad.br.geometryVertex = Vector2(x: rect.size.width, y: 0)
        quad.tl.geometryVertex = Vector2(x: 0, y: rect.size.height)
        quad.tr.geometryVertex = Vector2(x: rect.size.width, y: rect.size.height)

        quad.bl.textureVertex = Vector2(x: rect.origin.x / textureSize.width, y: rect.origin.y / textureSize.height)
        quad.br.textureVertex = Vector2(x: (rect.origin.x + rect.size.width) / textureSize.width, y: rect.origin.y / textureSize.height)
        quad.tl.textureVertex = Vector2(x: rect.origin.x / textureSize.width, y: (rect.origin.y + rect.size.height) / textureSize.height)
        quad.tr.textureVertex = Vector2(x: (rect.origin.x + rect.size.width) / textureSize.width, y: (rect.origin.y + rect.size.height) / textureSize.height)

        position += Vector2(rect.origin)
    }

    var position = Vector2() {
        didSet {
            let diff = position - oldValue
            quad.bl.geometryVertex += diff
            quad.br.geometryVertex += diff
            quad.tl.geometryVertex += diff
            quad.tr.geometryVertex += diff
        }
    }

    mutating func update(_ tick: TimeInterval) {
        position += moveVelocity * Float32(tick)
    }

}

class SpriteRender {

    fileprivate let texture: ViewTexture
    fileprivate let effect: GLKBaseEffect

    init(texture: ViewTexture, effect: GLKBaseEffect) {
        self.texture = texture
        self.effect = effect
    }

    func render(_ sprites: [Sprite]) {
        effect.texture2d0.name = self.texture.name
        effect.texture2d0.enabled = 1

        effect.prepareToDraw()

        var vertex = sprites.map { $0.quad }

        glEnableVertexAttribArray(GLuint(GLKVertexAttrib.position.rawValue))
        glEnableVertexAttribArray(GLuint(GLKVertexAttrib.texCoord0.rawValue))

        withUnsafePointer(to: &vertex[0].bl.geometryVertex) { offset in
            glVertexAttribPointer(GLuint(GLKVertexAttrib.position.rawValue), 2, GLenum(GL_FLOAT), GLboolean(UInt8(GL_FALSE)), GLsizei(MemoryLayout<TexturedVertex>.size), offset)
        }
        withUnsafePointer(to: &vertex[0].bl.textureVertex) { offset in
            glVertexAttribPointer(GLuint(GLKVertexAttrib.texCoord0.rawValue), 2, GLenum(GL_FLOAT), GLboolean(UInt8(GL_FALSE)), GLsizei(MemoryLayout<TexturedVertex>.size), offset)
        }

        glDrawArrays(GLenum(GL_TRIANGLES), 0, GLsizei(vertex.count * 6))
    }
}

class ViewTexture {
    var name: GLuint = 0
    var width: GLsizei = 0
    var height: GLsizei = 0

    func setupOpenGL() {
        glGenTextures(1, &name)
        glBindTexture(GLenum(GL_TEXTURE_2D), name)

        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GLint(GL_LINEAR))
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GLint(GL_LINEAR))

        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GLint(GL_CLAMP_TO_EDGE))
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GLint(GL_CLAMP_TO_EDGE))
        glBindTexture(GLenum(GL_TEXTURE_2D), 0);
    }

    deinit {
        if name != 0 {
            glDeleteTextures(1, &name)
        }
    }

    func render(view: UIView) {
        let scale = UIScreen.main.scale
        width = GLsizei(view.layer.bounds.size.width * scale)
        height = GLsizei(view.layer.bounds.size.height * scale)

        var texturePixelBuffer = [GLubyte](repeating: 0, count: Int(height * width * 4))
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        withUnsafeMutablePointer(to: &texturePixelBuffer[0]) { texturePixelBuffer in
            let context = CGContext(data: texturePixelBuffer,
                                    width: Int(width), height: Int(height), bitsPerComponent: 8, bytesPerRow: Int(width * 4), space: colorSpace,
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)!
            context.scaleBy(x: scale, y: scale)

            UIGraphicsPushContext(context)
            view.drawHierarchy(in: view.layer.bounds, afterScreenUpdates: false)
            UIGraphicsPopContext()

            glBindTexture(GLenum(GL_TEXTURE_2D), name);

            glTexImage2D(GLenum(GL_TEXTURE_2D), 0, GLint(GL_RGBA), width, height, 0, GLenum(GL_RGBA), GLenum(GL_UNSIGNED_BYTE), texturePixelBuffer)
            glBindTexture(GLenum(GL_TEXTURE_2D), 0);
        }
    }
}

struct Vector2 {

    var x : Float32 = 0.0
    var y : Float32 = 0.0

    init() {

        x = 0.0
        y = 0.0
    }

    init(value: Float32) {

        x = value
        y = value
    }

    init(x: Float32 ,y: Float32) {

        self.x = x
        self.y = y
    }

    init(x: CGFloat, y: CGFloat) {
        self.init(x: Float32(x), y: Float32(y))
    }

    init(x: Int, y: Int) {
        self.init(x: Float32(x), y: Float32(y))
    }

    init(other: Vector2) {

        x = other.x
        y = other.y
    }

    init(_ other: CGPoint) {
        x = Float32(other.x)
        y = Float32(other.y)
    }
}

extension Vector2: CustomStringConvertible {

    var description: String { return "[\(x),\(y)]" }
}

extension Vector2 : Equatable {

    func isFinite() -> Bool {

        return x.isFinite && y.isFinite
    }

    func distance(_ other: Vector2) -> Float32 {

        let result = self - other;
        return sqrt( result.dot(result) )
    }

    mutating func normalize() {

        let m = magnitude()

        if m > 0 {

            let il:Float32 = 1.0 / m

            x *= il
            y *= il
        }
    }

    func magnitude() -> Float32 {

        return sqrtf( x*x + y*y )
    }

    func dot( _ v: Vector2 ) -> Float32 {

        return x * v.x + y * v.y
    }

    mutating func lerp( _ a: Vector2, b: Vector2, coef : Float32) {

        let result = a + ( b - a) * coef

        x = result.x
        y = result.y
    }
}

func ==(lhs: Vector2, rhs: Vector2) -> Bool {

    return (lhs.x == rhs.x) && (lhs.y == rhs.y)
}

func * (left: Vector2, right : Float32) -> Vector2 {

    return Vector2(x:left.x * right, y:left.y * right)
}

func * (left: Vector2, right : Vector2) -> Vector2 {

    return Vector2(x:left.x * right.x, y:left.y * right.y)
}

func / (left: Vector2, right : Float32) -> Vector2 {

    return Vector2(x:left.x / right, y:left.y / right)
}

func / (left: Vector2, right : Vector2) -> Vector2 {

    return Vector2(x:left.x / right.x, y:left.y / right.y)
}

func + (left: Vector2, right: Vector2) -> Vector2 {

    return Vector2(x:left.x + right.x, y:left.y + right.y)
}

func - (left: Vector2, right: Vector2) -> Vector2 {

    return Vector2(x:left.x - right.x, y:left.y - right.y)
}

func + (left: Vector2, right: Float32) -> Vector2 {

    return Vector2(x:left.x + right, y:left.y + right)
}

func - (left: Vector2, right: Float32) -> Vector2 {

    return Vector2(x:left.x - right, y:left.y - right)
}

func += (left: inout Vector2, right: Vector2) {

    left = left + right
}

func -= (left: inout Vector2, right: Vector2) {

    left = left - right
}

func *= (left: inout Vector2, right: Vector2) {

    left = left * right
}

func /= (left: inout Vector2, right: Vector2) {

    left = left / right
}

