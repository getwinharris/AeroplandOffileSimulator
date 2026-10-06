import SceneKit
import AppKit

/// Builds cute low-poly cartoon planes 100% in code.
/// No downloaded assets → fully offline + legally sellable on the Mac App Store.
///
/// Each plane: fuselage + nose + cockpit + wings + tail + propeller/spinner.
/// Colours come from KidPlane so the menu cards match the 3D model.
enum PlaneFactory {
    static func makePlaneNode(for plane: KidPlane) -> SCNNode {
        let root = SCNNode()
        root.name = "plane-\(plane.id)"

        let body = NSColor(hex: plane.bodyColor)
        let wing = NSColor(hex: plane.wingColor)

        // Fuselage — stretched sphere, cute and chubby
        let fuselage = SCNNode(geometry: SCNSphere(radius: 1.0))
        fuselage.scale = SCNVector3(1.0, 1.0, 2.6)
        fuselage.geometry?.firstMaterial?.diffuse.contents = body
        fuselage.geometry?.firstMaterial?.roughness.contents = NSNumber(value: 0.6)
        root.addChildNode(fuselage)

        // Nose cone
        let nose = SCNNode(geometry: SCNSphere(radius: 0.55))
        nose.position = SCNVector3(0, -0.1, 2.5)
        nose.geometry?.firstMaterial?.diffuse.contents = NSColor.white
        root.addChildNode(nose)

        // Cockpit bubble
        let cockpit = SCNNode(geometry: SCNSphere(radius: 0.62))
        cockpit.position = SCNVector3(0, 0.75, 0.6)
        cockpit.scale = SCNVector3(1, 0.8, 1.3)
        let glass = cockpit.geometry?.firstMaterial
        glass?.diffuse.contents = NSColor(calibratedRed: 0.65, green: 0.9, blue: 1.0, alpha: 1)
        glass?.roughness.contents = NSNumber(value: 0.15)
        glass?.metalness.contents = NSNumber(value: 0.1)
        root.addChildNode(cockpit)

        // Smiley eyes (kid delight) — two black spheres + white sparkle
        for x in [-0.22, 0.22] {
            let eye = SCNNode(geometry: SCNSphere(radius: 0.11))
            eye.position = SCNVector3(CGFloat(x), 0.1, 2.92)
            eye.geometry?.firstMaterial?.diffuse.contents = NSColor.black
            eye.geometry?.firstMaterial?.emission.contents = NSColor.black
            root.addChildNode(eye)
            let sparkle = SCNNode(geometry: SCNSphere(radius: 0.035))
            sparkle.position = SCNVector3(CGFloat(x) + 0.035, 0.14, 3.0)
            sparkle.geometry?.firstMaterial?.diffuse.contents = NSColor.white
            sparkle.geometry?.firstMaterial?.emission.contents = NSColor.white
            root.addChildNode(sparkle)
        }

        // Main wings — wide flat boxes with rounded look
        func wingNode(width: CGFloat, y: CGFloat, z: CGFloat) -> SCNNode {
            let g = SCNBox(width: width, height: 0.16, length: 1.5, chamferRadius: 0.08)
            g.firstMaterial?.diffuse.contents = wing
            let n = SCNNode(geometry: g)
            n.position = SCNVector3(0, y, z)
            return n
        }

        switch plane.style {
        case .biplane:
            root.addChildNode(wingNode(width: 6.4, y: 0.55, z: 0.3))
            root.addChildNode(wingNode(width: 6.4, y: -0.55, z: 0.3))
            // struts
            for x in [-2.4, 2.4] {
                let strut = SCNNode(geometry: SCNCylinder(radius: 0.07, height: 1.1))
                strut.position = SCNVector3(CGFloat(x), 0, 0.3)
                strut.geometry?.firstMaterial?.diffuse.contents = NSColor.darkGray
                root.addChildNode(strut)
            }
        case .glider:
            root.addChildNode(wingNode(width: 9.5, y: 0.35, z: 0.2))
        case .jumbo:
            root.addChildNode(wingNode(width: 8.0, y: -0.1, z: 0.2))
            // upper hump
            let hump = SCNNode(geometry: SCNSphere(radius: 0.7))
            hump.position = SCNVector3(0, 0.7, 1.4)
            hump.scale = SCNVector3(1, 0.7, 1.2)
            hump.geometry?.firstMaterial?.diffuse.contents = body
            root.addChildNode(hump)
        default:
            root.addChildNode(wingNode(width: 7.0, y: -0.05, z: 0.3))
        }

        // Tail fin + stabilisers
        let fin = SCNNode(geometry: SCNBox(width: 0.16, height: 1.6, length: 1.1, chamferRadius: 0.06))
        fin.position = SCNVector3(0, 0.85, -2.3)
        fin.geometry?.firstMaterial?.diffuse.contents = wing
        root.addChildNode(fin)

        let tailWing = SCNNode(geometry: SCNBox(width: 3.2, height: 0.14, length: 0.9, chamferRadius: 0.06))
        tailWing.position = SCNVector3(0, 0.25, -2.35)
        tailWing.geometry?.firstMaterial?.diffuse.contents = wing
        root.addChildNode(tailWing)

        // Propeller or jet exhaust
        if plane.style == .jet || plane.style == .rocket {
            let flame = SCNNode(geometry: SCNCone(topRadius: 0.1, bottomRadius: 0.45, height: 1.6))
            flame.position = SCNVector3(0, 0, -3.2)
            flame.rotation = SCNXAxisToAngle(x: 1, y: 0, z: 0, angle: Float(CGFloat.pi / 2))
            flame.geometry?.firstMaterial?.diffuse.contents = NSColor.orange
            flame.geometry?.firstMaterial?.emission.contents = NSColor.orange
            flame.name = "exhaust"
            root.addChildNode(flame)
        } else {
            let hub = SCNNode(geometry: SCNSphere(radius: 0.18))
            hub.position = SCNVector3(0, -0.1, 3.15)
            hub.geometry?.firstMaterial?.diffuse.contents = NSColor.darkGray
            root.addChildNode(hub)
            let prop = SCNNode(geometry: SCNBox(width: 0.22, height: 3.2, length: 0.1, chamferRadius: 0.05))
            prop.position = SCNVector3(0, -0.1, 3.25)
            prop.geometry?.firstMaterial?.diffuse.contents = NSColor.darkGray.withAlphaComponent(0.9)
            prop.name = "propeller"
            root.addChildNode(prop)
        }

        // Boost rainbow trail (hidden unless boosting)
        let trail = SCNNode(geometry: SCNCylinder(radius: 0.18, height: 6.0))
        trail.position = SCNVector3(0, 0, -5.5)
        trail.rotation = SCNXAxisToAngle(x: 1, y: 0, z: 0, angle: Float(CGFloat.pi / 2))
        trail.geometry?.firstMaterial?.diffuse.contents = NSColor.systemPink.withAlphaComponent(0.55)
        trail.geometry?.firstMaterial?.emission.contents = NSColor.systemPink
        trail.geometry?.firstMaterial?.transparency = 0.55
        trail.name = "trail"
        trail.isHidden = true
        root.addChildNode(trail)

        root.scale = SCNVector3(0.9, 0.9, 0.9)
        return root
    }

    static func setBoost(_ node: SCNNode, on: Bool) {
        node.childNode(withName: "trail", recursively: true)?.isHidden = !on
        if let exhaust = node.childNode(withName: "exhaust", recursively: true) {
            exhaust.geometry?.firstMaterial?.emission.contents = on ? NSColor.systemYellow : NSColor.orange
        }
    }

    static func spinPropeller(_ node: SCNNode, delta: CGFloat) {
        if let prop = node.childNode(withName: "propeller", recursively: true) {
            let newW = (prop.rotation.w + delta * 25).truncatingRemainder(dividingBy: CGFloat.pi * 2)
            prop.rotation = SCNVector4(0, 0, 1, newW)
        }
    }
}

private extension NSColor {
    convenience init(hex: UInt32) {
        self.init(calibratedRed: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

private func SCNXAxisToAngle(x: Float, y: Float, z: Float, angle: Float) -> SCNVector4 {
    SCNVector4(x, y, z, angle)
}
