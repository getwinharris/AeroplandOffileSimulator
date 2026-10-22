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
        // emission, which makes every model glow white. Kill emission and
        // switch to PBR so the real file colours show with realistic lighting.
        holder.enumerateChildNodes { node, _ in
            node.geometry?.materials.forEach {
                $0.emission.contents = NSColor.black
                $0.lightingModel = .physicallyBased
                $0.roughness.contents = NSNumber(value: 0.5)
                $0.metalness.contents = NSNumber(value: 0.1)
            }
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

        // Boost exhaust trail (hidden unless boosting).
        let trail = SCNNode(geometry: SCNCylinder(radius: 0.18, height: 6.0))
        trail.position = SCNVector3(0, 0, -6.0)
        trail.rotation = SCNVector4(1, 0, 0, Float(CGFloat.pi / 2))
        let trailMat = SCNMaterial()
        trailMat.lightingModel = .constant
        trailMat.diffuse.contents = NSColor(calibratedRed: 1.0, green: 0.45, blue: 0.2, alpha: 0.6)
        trailMat.emission.contents = NSColor(calibratedRed: 1.0, green: 0.55, blue: 0.15, alpha: 1)
        trailMat.transparency = 0.55
        trail.geometry?.materials = [trailMat]
        trail.name = "trail"
        trail.isHidden = true
        trail.castsShadow = false
        root.addChildNode(trail)
        return root
    }

    // MARK: - Emergency procedural fallback (files always ship — never seen)
    static func proceduralPlane(for plane: KidPlane) -> SCNNode {
        let root = SCNNode()

        // PBR fuselage
        let fuselage = SCNNode(geometry: SCNSphere(radius: 1.0))
        fuselage.scale = SCNVector3(1.0, 1.0, 2.6)
        let fusMat = SCNMaterial()
        fusMat.lightingModel = .physicallyBased
        fusMat.diffuse.contents = NSColor.systemRed
        fusMat.roughness.contents = NSNumber(value: 0.4)
        fusMat.metalness.contents = NSNumber(value: 0.15)
        fuselage.geometry?.materials = [fusMat]
        fuselage.castsShadow = true
        root.addChildNode(fuselage)

        // PBR nose cone
        let nose = SCNNode(geometry: SCNSphere(radius: 0.55))
        nose.position = SCNVector3(0, -0.1, 2.5)
        let noseMat = SCNMaterial()
        noseMat.lightingModel = .physicallyBased
        noseMat.diffuse.contents = NSColor(calibratedWhite: 0.92, alpha: 1)
        noseMat.roughness.contents = NSNumber(value: 0.3)
        noseMat.metalness.contents = NSNumber(value: 0.2)
        nose.geometry?.materials = [noseMat]
        root.addChildNode(nose)

        // PBR cockpit glass
        let cockpit = SCNNode(geometry: SCNSphere(radius: 0.62))
        cockpit.position = SCNVector3(0, 0.75, 0.6)
        cockpit.scale = SCNVector3(1, 0.8, 1.3)
        let glassMat = SCNMaterial()
        glassMat.lightingModel = .physicallyBased
        glassMat.diffuse.contents = NSColor(calibratedRed: 0.55, green: 0.82, blue: 0.95, alpha: 0.7)
        glassMat.roughness.contents = NSNumber(value: 0.05) // very smooth glass
        glassMat.metalness.contents = NSNumber(value: 0.0)
        glassMat.transparency = 0.7
        glassMat.fresnelExponent = 3.0
        cockpit.geometry?.materials = [glassMat]
        root.addChildNode(cockpit)

        // PBR wings
        let wings = SCNNode(geometry: SCNBox(width: 7.0, height: 0.16, length: 1.5, chamferRadius: 0.08))
        wings.position = SCNVector3(0, -0.05, 0.3)
        let wingMat = SCNMaterial()
        wingMat.lightingModel = .physicallyBased
        wingMat.diffuse.contents = NSColor(calibratedWhite: 0.95, alpha: 1)
        wingMat.roughness.contents = NSNumber(value: 0.35)
        wingMat.metalness.contents = NSNumber(value: 0.1)
        wings.geometry?.materials = [wingMat]
        wings.castsShadow = true
        root.addChildNode(wings)

        // PBR tail fin
        let fin = SCNNode(geometry: SCNBox(width: 0.16, height: 1.6, length: 1.1, chamferRadius: 0.06))
        fin.position = SCNVector3(0, 0.85, -2.3)
        fin.geometry?.materials = [wingMat] // reuse wing material
        fin.castsShadow = true
        root.addChildNode(fin)

        if plane.style == .jet || plane.style == .rocket || plane.style == .jumbo {
            let flame = SCNNode(geometry: SCNCone(topRadius: 0.1, bottomRadius: 0.45, height: 1.6))
            flame.position = SCNVector3(0, 0, -3.2)
            flame.rotation = SCNVector4(1, 0, 0, Float(CGFloat.pi / 2))
            let flameMat = SCNMaterial()
            flameMat.lightingModel = .constant
            flameMat.diffuse.contents = NSColor(calibratedRed: 1.0, green: 0.55, blue: 0.1, alpha: 0.9)
            flameMat.emission.contents = NSColor(calibratedRed: 1.0, green: 0.6, blue: 0.15, alpha: 1)
            flame.geometry?.materials = [flameMat]
            flame.name = "exhaust"
            flame.castsShadow = false
            root.addChildNode(flame)
        } else {
            let prop = SCNNode(geometry: SCNBox(width: 0.22, height: 3.2, length: 0.1, chamferRadius: 0.05))
            prop.position = SCNVector3(0, -0.1, 3.25)
            let propMat = SCNMaterial()
            propMat.lightingModel = .physicallyBased
            propMat.diffuse.contents = NSColor(calibratedWhite: 0.25, alpha: 0.9)
            propMat.roughness.contents = NSNumber(value: 0.3)
            propMat.metalness.contents = NSNumber(value: 0.6) // metal propeller
            prop.geometry?.materials = [propMat]
            prop.name = "propeller"
            root.addChildNode(prop)
        }

        // PBR exhaust trail
        let trail = SCNNode(geometry: SCNCylinder(radius: 0.18, height: 6.0))
        trail.position = SCNVector3(0, 0, -5.5)
        trail.rotation = SCNVector4(1, 0, 0, Float(CGFloat.pi / 2))
        let trailMat = SCNMaterial()
        trailMat.lightingModel = .constant
        trailMat.diffuse.contents = NSColor(calibratedRed: 1.0, green: 0.45, blue: 0.2, alpha: 0.6)
        trailMat.emission.contents = NSColor(calibratedRed: 1.0, green: 0.55, blue: 0.15, alpha: 1)
        trailMat.transparency = 0.55
        trail.geometry?.materials = [trailMat]
        trail.name = "trail"
        trail.isHidden = true
        trail.castsShadow = false
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
