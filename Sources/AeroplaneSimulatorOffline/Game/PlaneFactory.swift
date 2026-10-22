import SceneKit
import SceneKit.ModelIO
import AppKit
import ModelIO

/// Real 3D airplanes, loaded from actual model FILES
/// (Sources/.../Resources/Planes/*.obj + .mtl + textures) with ultra-real PBR materials,
/// retractable 3D landing gear, navigation strobe lights, and custom livery finishes.
enum PlaneFactory {
    /// Target wingspan in world units — matches the original flight tuning.
    static let targetSpan: CGFloat = 7.0

    static func makePlaneNode(for plane: KidPlane) -> SCNNode {
        let root = loadRealPlane(for: plane) ?? proceduralPlane(for: plane)
        root.name = "plane-\(plane.id)"

        // Add 3D Retractable Landing Gear
        let gear = makeLandingGear()
        gear.name = "landingGear"
        root.addChildNode(gear)

        // Add Navigation Lights (Red Port, Green Starboard, White Tail Strobe)
        let navLights = makeNavigationLights()
        navLights.name = "navLights"
        root.addChildNode(navLights)

        return root
    }

    // MARK: - Real model files with Ultra-Realistic PBR Aircraft Skin
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

        // Apply realistic aviation clearcoat PBR materials
        holder.enumerateChildNodes { node, _ in
            node.geometry?.materials.forEach { mat in
                mat.emission.contents = NSColor.black
                mat.lightingModel = .physicallyBased
                // High-gloss aviation finish with subtle metallic sheen
                mat.roughness.contents = NSNumber(value: 0.25)
                mat.metalness.contents = NSNumber(value: 0.15)
                mat.fresnelExponent = 2.0
            }
        }

        // Texture mapping for planes that ship with textures
        let textureName = plane.forceTexture ?? (plane.modelFile == "an2" ? "An2_aeroflot" : nil)
        if let tex = textureName,
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

        // Dual Engine Boost / Exhaust Trails
        for side in [-1, 1] as [CGFloat] {
            let trail = SCNNode(geometry: SCNCylinder(radius: 0.14, height: 6.5))
            trail.position = SCNVector3(side * 0.8, -0.2, -4.5)
            trail.rotation = SCNVector4(1, 0, 0, Float(CGFloat.pi / 2))
            let trailMat = SCNMaterial()
            trailMat.lightingModel = .constant
            trailMat.diffuse.contents = NSColor(calibratedRed: 0.2, green: 0.7, blue: 1.0, alpha: 0.7)
            trailMat.emission.contents = NSColor(calibratedRed: 0.3, green: 0.85, blue: 1.0, alpha: 1)
            trailMat.transparency = 0.65
            trail.geometry?.materials = [trailMat]
            trail.name = side < 0 ? "trail_L" : "trail_R"
            trail.isHidden = true
            trail.castsShadow = false
            root.addChildNode(trail)
        }

        return root
    }

    // MARK: - 3D Retractable Landing Gear

    static func makeLandingGear() -> SCNNode {
        let gearRoot = SCNNode()

        let strutMat = SCNMaterial()
        strutMat.lightingModel = .physicallyBased
        strutMat.diffuse.contents = NSColor(calibratedWhite: 0.3, alpha: 1.0)
        strutMat.metalness.contents = NSNumber(value: 0.9)
        strutMat.roughness.contents = NSNumber(value: 0.2)

        let tireMat = SCNMaterial()
        tireMat.lightingModel = .physicallyBased
        tireMat.diffuse.contents = NSColor(calibratedWhite: 0.12, alpha: 1.0)
        tireMat.roughness.contents = NSNumber(value: 0.85)

        // 1. Nose Gear (Front center)
        let noseStrut = SCNNode(geometry: SCNCylinder(radius: 0.08, height: 1.0))
        noseStrut.position = SCNVector3(0, -0.5, 1.8)
        noseStrut.geometry?.materials = [strutMat]
        let noseWheel = SCNNode(geometry: SCNCylinder(radius: 0.28, height: 0.18))
        noseWheel.rotation = SCNVector4(0, 0, 1, Float(CGFloat.pi / 2))
        noseWheel.position = SCNVector3(0, -0.45, 0)
        noseWheel.geometry?.materials = [tireMat]
        noseStrut.addChildNode(noseWheel)
        gearRoot.addChildNode(noseStrut)

        // 2. Main Gear Left
        let mainStrutL = SCNNode(geometry: SCNCylinder(radius: 0.09, height: 1.1))
        mainStrutL.position = SCNVector3(-1.2, -0.55, -0.4)
        mainStrutL.geometry?.materials = [strutMat]
        let wheelL = SCNNode(geometry: SCNCylinder(radius: 0.34, height: 0.22))
        wheelL.rotation = SCNVector4(0, 0, 1, Float(CGFloat.pi / 2))
        wheelL.position = SCNVector3(0, -0.5, 0)
        wheelL.geometry?.materials = [tireMat]
        mainStrutL.addChildNode(wheelL)
        gearRoot.addChildNode(mainStrutL)

        // 3. Main Gear Right
        let mainStrutR = SCNNode(geometry: SCNCylinder(radius: 0.09, height: 1.1))
        mainStrutR.position = SCNVector3(1.2, -0.55, -0.4)
        mainStrutR.geometry?.materials = [strutMat]
        let wheelR = SCNNode(geometry: SCNCylinder(radius: 0.34, height: 0.22))
        wheelR.rotation = SCNVector4(0, 0, 1, Float(CGFloat.pi / 2))
        wheelR.position = SCNVector3(0, -0.5, 0)
        wheelR.geometry?.materials = [tireMat]
        mainStrutR.addChildNode(wheelR)
        gearRoot.addChildNode(mainStrutR)

        return gearRoot
    }

    // MARK: - Navigation Strobe Lights

    static func makeNavigationLights() -> SCNNode {
        let lights = SCNNode()

        // Red Port Light (Left wingtip)
        let redLight = SCNNode(geometry: SCNSphere(radius: 0.12))
        redLight.position = SCNVector3(-3.4, 0.2, -0.2)
        let rMat = SCNMaterial()
        rMat.lightingModel = .constant
        rMat.diffuse.contents = NSColor.red
        rMat.emission.contents = NSColor.red
        redLight.geometry?.materials = [rMat]
        lights.addChildNode(redLight)

        // Green Starboard Light (Right wingtip)
        let greenLight = SCNNode(geometry: SCNSphere(radius: 0.12))
        greenLight.position = SCNVector3(3.4, 0.2, -0.2)
        let gMat = SCNMaterial()
        gMat.lightingModel = .constant
        gMat.diffuse.contents = NSColor.green
        gMat.emission.contents = NSColor.green
        greenLight.geometry?.materials = [gMat]
        lights.addChildNode(greenLight)

        // White Tail Strobe Light
        let strobe = SCNNode(geometry: SCNSphere(radius: 0.14))
        strobe.position = SCNVector3(0, 0.8, -3.2)
        strobe.name = "tailStrobe"
        let sMat = SCNMaterial()
        sMat.lightingModel = .constant
        sMat.diffuse.contents = NSColor.white
        sMat.emission.contents = NSColor.white
        strobe.geometry?.materials = [sMat]
        lights.addChildNode(strobe)

        return lights
    }

    // MARK: - Procedural Fallback Plane
    static func proceduralPlane(for plane: KidPlane) -> SCNNode {
        let root = SCNNode()

        // PBR fuselage
        let fuselage = SCNNode(geometry: SCNSphere(radius: 1.0))
        fuselage.scale = SCNVector3(1.0, 1.0, 2.6)
        let fusMat = SCNMaterial()
        fusMat.lightingModel = .physicallyBased
        fusMat.diffuse.contents = NSColor(calibratedRed: 0.95, green: 0.96, blue: 0.98, alpha: 1)
        fusMat.roughness.contents = NSNumber(value: 0.2)
        fusMat.metalness.contents = NSNumber(value: 0.1)
        fuselage.geometry?.materials = [fusMat]
        fuselage.castsShadow = true
        root.addChildNode(fuselage)

        // Racing Stripe
        let stripe = SCNNode(geometry: SCNCylinder(radius: 1.02, height: 0.4))
        stripe.rotation = SCNVector4(1, 0, 0, Float(CGFloat.pi / 2))
        let strMat = SCNMaterial()
        strMat.lightingModel = .physicallyBased
        strMat.diffuse.contents = NSColor.systemRed
        stripe.geometry?.materials = [strMat]
        fuselage.addChildNode(stripe)

        // Cockpit Glass
        let cockpit = SCNNode(geometry: SCNSphere(radius: 0.65))
        cockpit.scale = SCNVector3(0.85, 0.75, 1.4)
        cockpit.position = SCNVector3(0, 0.55, 0.6)
        let glassMat = SCNMaterial()
        glassMat.lightingModel = .physicallyBased
        glassMat.diffuse.contents = NSColor(calibratedRed: 0.1, green: 0.35, blue: 0.55, alpha: 0.85)
        glassMat.roughness.contents = NSNumber(value: 0.1)
        glassMat.metalness.contents = NSNumber(value: 0.4)
        cockpit.geometry?.materials = [glassMat]
        root.addChildNode(cockpit)

        // Wings
        let wing = SCNNode(geometry: SCNBox(width: 7.0, height: 0.12, length: 1.5, chamferRadius: 0.05))
        wing.position = SCNVector3(0, 0, 0.2)
        let wingMat = SCNMaterial()
        wingMat.lightingModel = .physicallyBased
        wingMat.diffuse.contents = NSColor(calibratedRed: 0.92, green: 0.94, blue: 0.96, alpha: 1)
        wingMat.roughness.contents = NSNumber(value: 0.3)
        wing.geometry?.materials = [wingMat]
        wing.castsShadow = true
        root.addChildNode(wing)

        return root
    }

    // MARK: - State Controls

    static func setGear(_ node: SCNNode, down: Bool) {
        if let gear = node.childNode(withName: "landingGear", recursively: true) {
            let targetY: CGFloat = down ? 0 : 0.8
            let targetScale: CGFloat = down ? 1.0 : 0.01
            let move = SCNAction.move(to: SCNVector3(0, targetY, 0), duration: 0.4)
            let scale = SCNAction.scale(to: targetScale, duration: 0.4)
            gear.runAction(.group([move, scale]))
        }
    }

    static func setBoost(_ node: SCNNode, on: Bool) {
        node.childNode(withName: "trail_L", recursively: true)?.isHidden = !on
        node.childNode(withName: "trail_R", recursively: true)?.isHidden = !on
    }

    static func updateStrobes(_ node: SCNNode, time: TimeInterval) {
        if let strobe = node.childNode(withName: "tailStrobe", recursively: true) {
            let flash = Int(time * 3.0) % 3 == 0
            strobe.isHidden = !flash
        }
    }

    static func spinPropeller(_ node: SCNNode, delta: CGFloat) {
        if let prop = node.childNode(withName: "propeller", recursively: true) {
            let newW = (prop.rotation.w + delta * 28).truncatingRemainder(dividingBy: CGFloat.pi * 2)
            prop.rotation = SCNVector4(0, 0, 1, newW)
        }
    }
}
