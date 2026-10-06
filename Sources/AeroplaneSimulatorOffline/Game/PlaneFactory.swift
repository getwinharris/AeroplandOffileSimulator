import SceneKit
import SceneKit.ModelIO
import AppKit
import ModelIO

/// Real 3D airplanes, loaded from actual model FILES
/// (Sources/.../Resources/Planes/*.obj + .mtl + textures).
/// Native SceneKit + ModelIO — no three.js, no web views, fully offline.
///
/// Every plane is auto-centred and auto-scaled to a ~7-unit wingspan so the
/// flight loop, camera and collectibles behave identically for all models.
/// If a file is ever missing, a small procedural plane stands in so the game
/// never breaks (emergency path only — the files ship in the bundle).
enum PlaneFactory {
    /// Target wingspan in world units — matches the original flight tuning.
    static let targetSpan: CGFloat = 7.0

    static func makePlaneNode(for plane: KidPlane) -> SCNNode {
        let root = loadRealPlane(for: plane) ?? proceduralPlane(for: plane)
        root.name = "plane-\(plane.id)"
        return root
    }

    // MARK: - Real model files
    static func loadRealPlane(for plane: KidPlane) -> SCNNode? {
        guard let url = Bundle.module.url(forResource: plane.modelFile,
                                           withExtension: "obj",
                                           subdirectory: "Planes") else { return nil }
        let asset = MDLAsset(url: url)
        let holder = SCNNode()
        var foundMesh = false
        func walk(_ o: MDLObject) {
            if let mesh = o as? MDLMesh {
                holder.addChildNode(SCNNode(mdlObject: mesh))
                foundMesh = true
            }
            for c in o.children.objects { walk(c) }
        }
        for i in 0..<asset.count { walk(asset.object(at: i)) }
        guard foundMesh else { return nil }

        // The MDL→SceneKit bridge copies the MTL ambient (Ka 1,1,1) into
        // emission, which makes every model glow white. Kill emission so the
        // real file colours show.
        holder.enumerateChildNodes { node, _ in
            node.geometry?.materials.forEach { $0.emission.contents = NSColor.black }
        }

        // Optional forced texture (when the MTL ships without one).
        if let tex = plane.forceTexture,
           let texURL = Bundle.module.url(forResource: tex, withExtension: "png", subdirectory: "Planes"),
           let img = NSImage(contentsOf: texURL) {
            holder.enumerateChildNodes { node, _ in
                node.geometry?.materials.forEach { $0.diffuse.contents = img }
            }
        }

        // Centre on origin + normalise size.
        let (mn, mx) = holder.boundingBox
        let center = SCNVector3((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, (mn.z + mx.z) / 2)
        let span = max(mx.x - mn.x, mx.z - mn.z, 0.001)
        holder.position = SCNVector3(-center.x, -center.y, -center.z)

        let root = SCNNode()
        root.addChildNode(holder)
        root.scale = SCNVector3(targetSpan / span, targetSpan / span, targetSpan / span)
        if plane.yawCorrection != 0 {
            root.eulerAngles = SCNVector3(0, CGFloat(plane.yawCorrection), 0)
        }

        // Boost rainbow trail (hidden unless boosting).
        let trail = SCNNode(geometry: SCNCylinder(radius: 0.18, height: 6.0))
        trail.position = SCNVector3(0, 0, -6.0)
        trail.rotation = SCNVector4(1, 0, 0, Float(CGFloat.pi / 2))
        trail.geometry?.firstMaterial?.diffuse.contents = NSColor.systemPink.withAlphaComponent(0.55)
        trail.geometry?.firstMaterial?.emission.contents = NSColor.systemPink
        trail.geometry?.firstMaterial?.transparency = 0.55
        trail.name = "trail"
        trail.isHidden = true
        root.addChildNode(trail)
        return root
    }

    // MARK: - Emergency procedural fallback (files always ship — never seen)
    static func proceduralPlane(for plane: KidPlane) -> SCNNode {
        let root = SCNNode()
        let body = NSColor.systemRed
        let wing = NSColor.white

        let fuselage = SCNNode(geometry: SCNSphere(radius: 1.0))
        fuselage.scale = SCNVector3(1.0, 1.0, 2.6)
        fuselage.geometry?.firstMaterial?.diffuse.contents = body
        fuselage.geometry?.firstMaterial?.roughness.contents = NSNumber(value: 0.6)
        root.addChildNode(fuselage)

        let nose = SCNNode(geometry: SCNSphere(radius: 0.55))
        nose.position = SCNVector3(0, -0.1, 2.5)
        nose.geometry?.firstMaterial?.diffuse.contents = NSColor.white
        root.addChildNode(nose)

        let cockpit = SCNNode(geometry: SCNSphere(radius: 0.62))
        cockpit.position = SCNVector3(0, 0.75, 0.6)
        cockpit.scale = SCNVector3(1, 0.8, 1.3)
        cockpit.geometry?.firstMaterial?.diffuse.contents = NSColor(calibratedRed: 0.65, green: 0.9, blue: 1.0, alpha: 1)
        root.addChildNode(cockpit)

        let wings = SCNNode(geometry: SCNBox(width: 7.0, height: 0.16, length: 1.5, chamferRadius: 0.08))
        wings.position = SCNVector3(0, -0.05, 0.3)
        wings.geometry?.firstMaterial?.diffuse.contents = wing
        root.addChildNode(wings)

        let fin = SCNNode(geometry: SCNBox(width: 0.16, height: 1.6, length: 1.1, chamferRadius: 0.06))
        fin.position = SCNVector3(0, 0.85, -2.3)
        fin.geometry?.firstMaterial?.diffuse.contents = wing
        root.addChildNode(fin)

        if plane.style == .jet || plane.style == .rocket || plane.style == .jumbo {
            let flame = SCNNode(geometry: SCNCone(topRadius: 0.1, bottomRadius: 0.45, height: 1.6))
            flame.position = SCNVector3(0, 0, -3.2)
            flame.rotation = SCNVector4(1, 0, 0, Float(CGFloat.pi / 2))
            flame.geometry?.firstMaterial?.diffuse.contents = NSColor.orange
            flame.geometry?.firstMaterial?.emission.contents = NSColor.orange
            flame.name = "exhaust"
            root.addChildNode(flame)
        } else {
            let prop = SCNNode(geometry: SCNBox(width: 0.22, height: 3.2, length: 0.1, chamferRadius: 0.05))
            prop.position = SCNVector3(0, -0.1, 3.25)
            prop.geometry?.firstMaterial?.diffuse.contents = NSColor.darkGray.withAlphaComponent(0.9)
            prop.name = "propeller"
            root.addChildNode(prop)
        }

        let trail = SCNNode(geometry: SCNCylinder(radius: 0.18, height: 6.0))
        trail.position = SCNVector3(0, 0, -5.5)
        trail.rotation = SCNVector4(1, 0, 0, Float(CGFloat.pi / 2))
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
