import SceneKit
import AppKit
import SwiftUI

/// The offline 3D world: sky, ocean, island, clouds, stars, rings, balloons.
/// Kid-proof: no crashing — plane bounces gently with a "boing".
final class FlightScene: SCNScene, SCNSceneRendererDelegate {
    var planeNode: SCNNode!
    var cameraNode: SCNNode!
    var plane: KidPlane = KidPlane.all[1]

    // Controls (set from FlyView tracking area)
    var mouseSteer = CGVector(dx: 0, dy: 0) // -1…1
    var boostHeld = false
    var sensitivity: Float = 1.0
    var invertY = false

    // Flight state
    private var velocity: CGFloat = 26
    private var yaw: CGFloat = 0
    private var pitch: CGFloat = 0
    private var starNodes: [SCNNode] = []
    private var ringNodes: [SCNNode] = []
    private var cloudNodes: [SCNNode] = []
    private var time: TimeInterval = 0

    var onStar: (() -> Void)?
    var onRing: (() -> Void)?
    var onStats: ((Int, Int, Bool, CGFloat, CGFloat, CGFloat) -> Void)? // speed, alt, boost, headingDeg, pitchDeg, bankDeg

    convenience init(plane: KidPlane) {
        self.init()
        self.plane = plane
        self.velocity = CGFloat(plane.topSpeed)
        buildWorld()
    }

    // MARK: - World
    private func buildWorld() {
        background.contents = NSColor(calibratedRed: 0.52, green: 0.8, blue: 0.98, alpha: 1)
        fogStartDistance = 120
        fogEndDistance = 700
        fogColor = NSColor(calibratedWhite: 1, alpha: 0.6)

        let sun = SCNNode()
        sun.light = SCNLight()
        sun.light?.type = .directional
        sun.light?.intensity = 1100
        sun.eulerAngles = SCNVector3(-0.6, 0.4, 0)
        rootNode.addChildNode(sun)
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 500
        rootNode.addChildNode(ambient)

        let sunBall = SCNNode(geometry: SCNSphere(radius: 18))
        sunBall.position = SCNVector3(250, 220, -450)
        sunBall.geometry?.firstMaterial?.emission.contents = NSColor.systemYellow
        sunBall.geometry?.firstMaterial?.diffuse.contents = NSColor.systemYellow
        rootNode.addChildNode(sunBall)

        let ocean = SCNNode(geometry: SCNPlane(width: 2000, height: 2000))
        ocean.geometry?.firstMaterial?.diffuse.contents = NSColor(calibratedRed: 0.2, green: 0.55, blue: 0.85, alpha: 1)
        ocean.geometry?.firstMaterial?.roughness.contents = NSNumber(value: 0.3)
        ocean.eulerAngles = SCNVector3(-CGFloat.pi / 2, 0, 0)
        ocean.position = SCNVector3(0, -2, 0)
        rootNode.addChildNode(ocean)

        let sand = SCNNode(geometry: SCNCylinder(radius: 55, height: 4))
        sand.position = SCNVector3(0, 0, 0)
        sand.geometry?.firstMaterial?.diffuse.contents = NSColor(calibratedRed: 0.95, green: 0.85, blue: 0.6, alpha: 1)
        rootNode.addChildNode(sand)
        let grass = SCNNode(geometry: SCNCylinder(radius: 42, height: 5))
        grass.position = SCNVector3(0, 1, 0)
        grass.geometry?.firstMaterial?.diffuse.contents = NSColor(calibratedRed: 0.35, green: 0.75, blue: 0.4, alpha: 1)
        rootNode.addChildNode(grass)
        for i in 0..<6 {
            let a = CGFloat(i) / 6 * CGFloat.pi * 2
            let tx = cos(a) * 28, tz = sin(a) * 28
            let trunk = SCNNode(geometry: SCNCylinder(radius: 0.7, height: 9))
            trunk.position = SCNVector3(tx, 7, tz)
            trunk.geometry?.firstMaterial?.diffuse.contents = NSColor.brown
            rootNode.addChildNode(trunk)
            for j in 0..<5 {
                let leaf = SCNNode(geometry: SCNSphere(radius: 1.8))
                leaf.scale = SCNVector3(1.6, 0.35, 0.8)
                let la = CGFloat(j) / 5 * CGFloat.pi * 2
                leaf.position = SCNVector3(tx + cos(la) * 2.2, 12, tz + sin(la) * 2.2)
                leaf.geometry?.firstMaterial?.diffuse.contents = NSColor(calibratedRed: 0.2, green: 0.65, blue: 0.3, alpha: 1)
                rootNode.addChildNode(leaf)
            }
        }
        let runway = SCNNode(geometry: SCNBox(width: 8, height: 0.3, length: 60, chamferRadius: 0))
        runway.position = SCNVector3(0, 3.6, 0)
        runway.geometry?.firstMaterial?.diffuse.contents = NSColor.darkGray
        rootNode.addChildNode(runway)

        for (x, z) in [(-220, -160), (240, -120), (-180, 220), (200, 240), (0, -320)] {
            let isl = SCNNode(geometry: SCNCylinder(radius: 30, height: 3))
            isl.position = SCNVector3(CGFloat(x), 0, CGFloat(z))
            isl.geometry?.firstMaterial?.diffuse.contents = NSColor(calibratedRed: 0.4, green: 0.75, blue: 0.45, alpha: 1)
            rootNode.addChildNode(isl)
        }

        for _ in 0..<42 {
            let cloud = makeCloud()
            cloud.position = SCNVector3(CGFloat.random(in: -350...350), CGFloat.random(in: 25...110), CGFloat.random(in: -350...350))
            rootNode.addChildNode(cloud)
            cloudNodes.append(cloud)
        }
        for _ in 0..<18 {
            let star = makeStar()
            star.position = SCNVector3(CGFloat.random(in: -250...250), CGFloat.random(in: 12...90), CGFloat.random(in: -250...250))
            rootNode.addChildNode(star)
            starNodes.append(star)
        }
        for _ in 0..<9 {
            let ring = makeRing()
            ring.position = SCNVector3(CGFloat.random(in: -220...220), CGFloat.random(in: 18...80), CGFloat.random(in: -220...220))
            rootNode.addChildNode(ring)
            ringNodes.append(ring)
        }
        for _ in 0..<12 {
            let b = makeBalloon()
            b.position = SCNVector3(CGFloat.random(in: -250...250), CGFloat.random(in: 15...70), CGFloat.random(in: -250...250))
            rootNode.addChildNode(b)
        }

        let rainbow = SCNNode(geometry: SCNTorus(ringRadius: 90, pipeRadius: 6))
        rainbow.position = SCNVector3(-120, 0, -260)
        rainbow.geometry?.firstMaterial?.diffuse.contents = NSColor.systemPink.withAlphaComponent(0.7)
        rainbow.geometry?.firstMaterial?.emission.contents = NSColor.systemPink
        rootNode.addChildNode(rainbow)

        planeNode = PlaneFactory.makePlaneNode(for: plane)
        planeNode.position = SCNVector3(0, 25, 60)
        rootNode.addChildNode(planeNode)

        cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 60
        rootNode.addChildNode(cameraNode)
        updateCamera(snap: true)
    }

    private func makeCloud() -> SCNNode {
        let c = SCNNode()
        for _ in 0..<4 {
            let s = SCNNode(geometry: SCNSphere(radius: CGFloat.random(in: 2.5...5)))
            s.position = SCNVector3(CGFloat.random(in: -4...4), CGFloat.random(in: -1...1), CGFloat.random(in: -2...2))
            s.geometry?.firstMaterial?.diffuse.contents = NSColor.white.withAlphaComponent(0.95)
            s.geometry?.firstMaterial?.transparency = 0.95
            c.addChildNode(s)
        }
        return c
    }

    private func makeStar() -> SCNNode {
        let n = SCNNode(geometry: SCNSphere(radius: 1.4))
        n.name = "star"
        n.geometry?.firstMaterial?.diffuse.contents = NSColor.systemYellow
        n.geometry?.firstMaterial?.emission.contents = NSColor.systemYellow
        let spike1 = SCNNode(geometry: SCNBox(width: 3.4, height: 0.5, length: 0.5, chamferRadius: 0.1))
        spike1.geometry?.firstMaterial?.emission.contents = NSColor.systemYellow
        spike1.geometry?.firstMaterial?.diffuse.contents = NSColor.systemYellow
        let spike2 = spike1.clone()
        spike2.eulerAngles = SCNVector3(0, 0, CGFloat.pi / 2)
        n.addChildNode(spike1); n.addChildNode(spike2)
        return n
    }

    private func makeRing() -> SCNNode {
        let n = SCNNode(geometry: SCNTorus(ringRadius: 7, pipeRadius: 1.1))
        n.name = "ring"
        n.geometry?.firstMaterial?.diffuse.contents = NSColor.systemOrange
        n.geometry?.firstMaterial?.emission.contents = NSColor.systemOrange
        return n
    }

    private func makeBalloon() -> SCNNode {
        let n = SCNNode()
        let colors: [NSColor] = [.systemRed, .systemBlue, .systemGreen, .systemPurple, .systemPink]
        let ball = SCNNode(geometry: SCNSphere(radius: 2.2))
        ball.scale = SCNVector3(1, 1.25, 1)
        ball.geometry?.firstMaterial?.diffuse.contents = colors.randomElement()!
        n.addChildNode(ball)
        let string = SCNNode(geometry: SCNCylinder(radius: 0.05, height: 4))
        string.position = SCNVector3(0, -4, 0)
        string.geometry?.firstMaterial?.diffuse.contents = NSColor.gray
        n.addChildNode(string)
        let up = SCNAction.moveBy(x: 0, y: 3, z: 0, duration: 2.5)
        n.runAction(.repeatForever(.sequence([up, up.reversed()])))
        return n
    }

    // MARK: - Per-frame update (mouse steers plane)
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime t: TimeInterval) {
        let dt: CGFloat = 1.0 / 60.0
        time = t

        let boosting = boostHeld
        let baseSpeed = CGFloat(plane.topSpeed)
        let targetSpeed: CGFloat = boosting ? baseSpeed * 1.9 : baseSpeed
        velocity += (targetSpeed - velocity) * min(1, dt * 1.5)

        let steerX = CGFloat(mouseSteer.dx) * CGFloat(sensitivity) * CGFloat(plane.turnSpeed)
        var steerY = CGFloat(-mouseSteer.dy) * CGFloat(sensitivity)
        if invertY { steerY = -steerY }

        yaw -= steerX * dt * 1.6
        pitch += steerY * dt * 1.2
        pitch = max(-0.7, min(0.7, pitch))
        pitch *= (1 - dt * 0.6)

        let dx = sin(yaw) * cos(pitch)
        let dy = sin(pitch)
        let dz = -cos(yaw) * cos(pitch)
        var pos = planeNode.position
        let step = velocity * dt
        pos.x += dx * step
        pos.y += dy * step
        pos.z += dz * step

        if abs(pos.x) > 380 || abs(pos.z) > 380 {
            yaw += dt * 1.8
        }
        if pos.y < 4 {
            pos.y = 4
            pitch = abs(pitch) * 0.7 + 0.25
            DispatchQueue.main.async { SoundManager.shared.boing() }
        }
        if pos.y > 150 { pos.y = 150; pitch = -0.15 }

        planeNode.position = pos
        let bank = -steerX * 0.9
        planeNode.eulerAngles = SCNVector3(-pitch * 0.6, yaw + CGFloat.pi, bank)

        PlaneFactory.spinPropeller(planeNode, delta: dt * (boosting ? 2.2 : 1))
        PlaneFactory.setBoost(planeNode, on: boosting)

        for s in starNodes where !s.isHidden {
            s.rotation = SCNVector4(0, 1, 0, Float(fmod(t * 2, Double.pi * 2)))
            if s.position.distance(to: pos) < 6 {
                s.isHidden = true
                DispatchQueue.main.async { self.onStar?() }
                DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                    s.position = SCNVector3(CGFloat.random(in: -250...250), CGFloat.random(in: 12...90), CGFloat.random(in: -250...250))
                    s.isHidden = false
                }
            }
        }
        for r in ringNodes {
            r.rotation = SCNVector4(0, 1, 0, Float(fmod(t * 0.6, Double.pi * 2)))
            if r.position.distance(to: pos) < 8 {
                DispatchQueue.main.async { self.onRing?() }
                // push ring away so it doesn't double-trigger
                r.position = SCNVector3(CGFloat.random(in: -220...220), CGFloat.random(in: 18...80), CGFloat.random(in: -220...220))
            }
        }
        for c in cloudNodes {
            c.position.x += dt * 1.2
            if c.position.x > 380 { c.position.x = -380 }
        }

        updateCamera(snap: false)
        let knots = Int(velocity * 1.9)
        let alt = Int(max(0, pos.y * 3))
        var hdg = -yaw * 180 / CGFloat.pi
        hdg = hdg.truncatingRemainder(dividingBy: 360)
        if hdg < 0 { hdg += 360 }
        let bankNow = -CGFloat(mouseSteer.dx) * CGFloat(sensitivity) * CGFloat(plane.turnSpeed) * 0.9
        let pitchNow = pitch
        DispatchQueue.main.async {
            self.onStats?(knots, alt, boosting, hdg, pitchNow * 180 / CGFloat.pi, bankNow * 180 / CGFloat.pi)
        }
    }

    private func updateCamera(snap: Bool) {
        let back: CGFloat = 13, up: CGFloat = 4.5
        let cx = planeNode.position.x + sin(yaw) * back
        let cz = planeNode.position.z + cos(yaw) * back
        let cy = planeNode.position.y + up
        let target = SCNVector3(cx, cy, cz)
        if snap { cameraNode.position = target }
        else { cameraNode.position = cameraNode.position.lerp(to: target, t: 0.12) }
        let look = SCNVector3(planeNode.position.x - sin(yaw) * 20,
                              planeNode.position.y + 1,
                              planeNode.position.z - cos(yaw) * 20)
        cameraNode.look(at: look)
    }
}

private extension SCNVector3 {
    func distance(to other: SCNVector3) -> CGFloat {
        let dx = x - other.x, dy = y - other.y, dz = z - other.z
        return sqrt(dx*dx + dy*dy + dz*dz)
    }
    func lerp(to other: SCNVector3, t: CGFloat) -> SCNVector3 {
        SCNVector3(x + (other.x - x) * t, y + (other.y - y) * t, z + (other.z - z) * t)
    }
}
