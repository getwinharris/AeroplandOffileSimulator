import SceneKit
import AppKit
import SwiftUI
import GameplayKit

/// Telemetry passed every frame to the GTA VI-styled HUD
struct FlightTelemetry {
    var altitude: CGFloat
    var verticalSpeed: CGFloat
    var airspeed: CGFloat
    var headingDeg: Double
    var isBoosting: Bool
    var pitchDeg: Double
    var bankDeg: Double
    var throttlePct: Int
    var flapsDeg: Int           // 0, 15, 30
    var isBraking: Bool
    var gForce: Double
    var gearDown: Bool
    var cameraMode: Int
    var zone: String
    var subzone: String
    var posX: CGFloat
    var posZ: CGFloat
    var nearestAirfield: String
    var distToNearestAirfield: CGFloat
    var onRunway: Bool
    var runwayAlignmentDeg: Double
    var papiState: Int          // 0: 4W, 1: 3W1R, 2: 2W2R (perfect), 3: 1W3R, 4: 4R
    var flightPhase: String     // "PARKED", "TAKEOFF ROLL", "ROTATE!", "CLIMBING", "CRUISE", "APPROACH", "FLARE!", "TOUCHDOWN"
}

/// Runway definitions across the State of Leonida
struct RunwayZone {
    let id: String
    let code: String
    let name: String
    let zone: String
    let position: SCNVector3
    let length: CGFloat
    let width: CGFloat
    let headingDeg: Double
    let elevation: CGFloat
}

/// GTA VI State of Leonida Simulation Scene with:
/// - Realistic takeoff roll, rotation, climb-out, approach, flare, and touchdown scoring
/// - Continuous throttle & speed control (W/S progressive throttle, flaps, brakes, gear drag)
/// - High-resolution multi-pass Leonida terrain textures & photo-realistic runway markings
/// - 6 full-featured Airfields with PAPI glidepath lights, towers, hangars, and windsocks
/// - PBR aircraft finishes with retractable 3D landing gear and navigation strobe lights
final class FlightScene: SCNScene, SCNSceneRendererDelegate {
    var planeNode: SCNNode!
    var cameraNode: SCNNode!
    var plane: KidPlane = KidPlane.all[1]

    // Traditional & Mouse Controls
    var mouseSteer = CGVector(dx: 0, dy: 0) // -1...1
    var boostHeld = false
    var sensitivity: Float = 1.0
    var invertY = false

    // GTA V Flight & Speed Controls
    var pitchInput: CGFloat = 0     // -1 (dive) to +1 (climb)
    var rollInput: CGFloat = 0      // -1 (bank left) to +1 (bank right)
    var rudderInput: CGFloat = 0    // -1 (yaw left) to +1 (yaw right)
    var throttlePct: Int = 0        // 0% (idle/brake) to 100% (full power)
    var throttleChange: CGFloat = 0 // continuous throttle advance
    var flapsDeg: Int = 0           // 0, 15, 30
    var isBraking: Bool = true      // Parking brake initially ON
    var gearDown: Bool = true       // Landing gear
    var cameraMode: Int = 0         // 0: Close Chase, 1: Wide Chase, 2: Cockpit

    // Realistic Flight State
    private var altitude: CGFloat = 0.35    // height above runway (m)
    private var verticalSpeed: CGFloat = 0  // m/s, positive = climbing
    private var airspeed: CGFloat = 0       // starts stationary on runway!
    private var heading: CGFloat = CGFloat.pi / 2 // aligned with Runway 09R (East)
    private var bank: CGFloat = 0           // roll angle (radians)
    private var angleOfAttack: CGFloat = 0  // radians
    private var sideSlip: CGFloat = 0       // rudder coordination
    private var gForce: CGFloat = 1.0
    private var isGrounded: Bool = true
    private var wasAirborne: Bool = false
    private var flightPhase: String = "PARKED"
    private var touchdownRating: String? = nil

    // Physics constants
    private var stallSpeed: CGFloat = 18

    // World & effects
    private var starNodes: [SCNNode] = []
    private var ringNodes: [SCNNode] = []
    private var cloudNodes: [SCNNode] = []
    private var targetNodes: [SCNNode] = []
    private var oceanNode: SCNNode?
    private var lakeNode: SCNNode?
    private var skyDomeNode: SCNNode?
    private var beaconNodes: [SCNNode] = []
    private var papiNodes: [SCNNode] = []
    private var time: TimeInterval = 0

    // Terrain heightmap (State of Leonida)
    private var heightMap: [[Float]] = []
    private let terrainGridSize = 140
    private let terrainWorldSize: CGFloat = 1400

    // Runway zones catalog
    let runways: [RunwayZone] = [
        RunwayZone(id: "vcia", code: "VCIA", name: "Vice City International", zone: "VICE CITY", position: SCNVector3(220, 1.2, 120), length: 280, width: 14, headingDeg: 90, elevation: 1.2),
        RunwayZone(id: "keys", code: "KEYS", name: "Leonida Keys Airstrip", zone: "LEONIDA KEYS", position: SCNVector3(80, 1.2, 420), length: 170, width: 9, headingDeg: 120, elevation: 1.2),
        RunwayZone(id: "kalaga", code: "KLGA", name: "Mount Kalaga Ridge", zone: "MOUNT KALAGA", position: SCNVector3(-80, 48.2, -360), length: 180, width: 9, headingDeg: 0, elevation: 48.2),
        RunwayZone(id: "gellhorn", code: "PORT", name: "Port Gellhorn Airfield", zone: "PORT GELLHORN", position: SCNVector3(-320, 1.2, -60), length: 200, width: 10, headingDeg: 90, elevation: 1.2),
        RunwayZone(id: "ambrosia", code: "AMBR", name: "Ambrosia Dustoff Strip", zone: "AMBROSIA", position: SCNVector3(40, 6.2, -100), length: 150, width: 8, headingDeg: 30, elevation: 6.2),
        RunwayZone(id: "everglades", code: "EVRG", name: "Grassrivers Bush Strip", zone: "GRASSRIVERS", position: SCNVector3(-160, 1.2, 200), length: 140, width: 8, headingDeg: 150, elevation: 1.2)
    ]

    var onStar: (() -> Void)?
    var onRing: (() -> Void)?
    var onTargetHit: ((CGFloat, CGFloat) -> Void)?
    var onTelemetry: ((FlightTelemetry) -> Void)?
    var onTouchdown: ((String) -> Void)?
    var onStats: ((CGFloat, CGFloat, CGFloat, CGFloat, Bool, CGFloat, CGFloat) -> Void)?

    convenience init(plane: KidPlane) {
        self.init()
        self.plane = plane
        generateHeightMap()
        buildWorld()
    }

    // MARK: - Leonida Heightmap Generation

    private func generateHeightMap() {
        let source = GKPerlinNoiseSource(
            frequency: 0.005,
            octaveCount: 5,
            persistence: 0.5,
            lacunarity: 2.0,
            seed: 77
        )
        let noise = GKNoise(source)
        let map = GKNoiseMap(
            noise,
            size: vector_double2(Double(terrainWorldSize), Double(terrainWorldSize)),
            origin: vector_double2(0, 0),
            sampleCount: vector_int2(Int32(terrainGridSize), Int32(terrainGridSize)),
            seamless: false
        )

        heightMap = Array(repeating: Array(repeating: Float(0), count: terrainGridSize), count: terrainGridSize)

        for y in 0..<terrainGridSize {
            for x in 0..<terrainGridSize {
                let worldX = (CGFloat(x) / CGFloat(terrainGridSize - 1) - 0.5) * terrainWorldSize
                let worldZ = (CGFloat(y) / CGFloat(terrainGridSize - 1) - 0.5) * terrainWorldSize
                let raw = Float(map.value(at: vector_int2(Int32(x), Int32(y))))

                // Base height from geographical zones
                var h = calculateLeonidaBaseHeight(x: worldX, z: worldZ, noise: raw)

                // Flatten exactly at all 6 runway locations
                for r in runways {
                    let dx = worldX - r.position.x
                    let dz = worldZ - r.position.z
                    let dist = sqrt(dx * dx + dz * dz)
                    if dist < r.length * 0.75 {
                        let blend = Swift.max(0, 1.0 - (dist / (r.length * 0.75)))
                        h = Float(Double(h) * (1.0 - Double(blend)) + Double(r.elevation) * Double(blend))
                    }
                }

                heightMap[y][x] = h
            }
        }
    }

    private func calculateLeonidaBaseHeight(x: CGFloat, z: CGFloat, noise: Float) -> Float {
        let dx = (x - 20) / 480.0
        let dz = (z - 50) / 580.0
        let dist = sqrt(dx * dx + dz * dz)

        if dist > 1.08 {
            return -8.0 + noise * 3.0
        }

        let coastFactor = Float(Swift.max(0, 1.0 - (dist - 0.85) / 0.23))

        // 1. Mount Kalaga (North)
        if z < -200 {
            let mDist = sqrt(pow((x + 60) / 200.0, 2) + pow((z + 360) / 160.0, 2))
            let mountainHeight = Float(Swift.max(0, 1.0 - mDist)) * 80.0 * (0.6 + abs(noise) * 0.8)
            return Swift.max(2.0, mountainHeight * coastFactor)
        }

        // 2. Lake Leonida
        let lakeDx = (x - 120) / 70.0
        let lakeDz = (z - 230) / 60.0
        let lakeDist = sqrt(lakeDx * lakeDx + lakeDz * lakeDz)
        if lakeDist < 1.0 {
            return -2.5 + noise * 0.4
        }

        // 3. Ambrosia Farmlands
        if z >= -220 && z < -40 && abs(x) < 220 {
            let rolling = 5.0 + noise * 4.0
            return Swift.max(2.0, rolling * coastFactor)
        }

        // 4. Port Gellhorn
        if x < -160 && z >= -160 && z < 50 {
            return Swift.max(1.2, (2.0 + noise * 1.5) * coastFactor)
        }

        // 5. Vice City
        if x > 40 && z >= -60 && z < 280 {
            let isCanal = abs(sin(x * 0.05) * cos(z * 0.05)) < 0.15 && x < 260
            if isCanal { return -1.5 }
            return Swift.max(1.5, (2.5 + noise * 1.0) * coastFactor)
        }

        // 6. Grassrivers / Everglades
        if x < 40 && z >= 40 && z < 320 {
            return Swift.max(0.6, (1.2 + noise * 0.8) * coastFactor)
        }

        // 7. Leonida Keys
        if z >= 320 {
            let keyDist = abs(x - (80 - (z - 320) * 0.4))
            if keyDist < 75 && dist < 1.05 {
                return Swift.max(1.2, (2.0 + noise * 1.0) * coastFactor)
            }
            return -6.0 + noise * 2.0
        }

        return Swift.max(1.5, (3.5 + noise * 3.0) * coastFactor)
    }

    func sampleHeight(worldX: CGFloat, worldZ: CGFloat) -> CGFloat {
        let halfSize = terrainWorldSize / 2
        let wx = worldX.clamped(to: -halfSize...halfSize)
        let wz = worldZ.clamped(to: -halfSize...halfSize)

        let gx = (wx + halfSize) / terrainWorldSize * CGFloat(terrainGridSize - 1)
        let gz = (wz + halfSize) / terrainWorldSize * CGFloat(terrainGridSize - 1)

        let ix = Int(gx.clamped(to: 0...CGFloat(terrainGridSize - 2)))
        let iz = Int(gz.clamped(to: 0...CGFloat(terrainGridSize - 2)))
        let fx = gx - CGFloat(ix)
        let fz = gz - CGFloat(iz)

        let h00 = CGFloat(heightMap[iz][ix])
        let h10 = CGFloat(heightMap[iz][Swift.min(ix + 1, terrainGridSize - 1)])
        let h01 = CGFloat(heightMap[Swift.min(iz + 1, terrainGridSize - 1)][ix])
        let h11 = CGFloat(heightMap[Swift.min(iz + 1, terrainGridSize - 1)][Swift.min(ix + 1, terrainGridSize - 1)])

        let top = h00 + (h10 - h00) * fx
        let bot = h01 + (h11 - h01) * fx
        return top + (bot - top) * fz
    }

    // MARK: - World Construction

    private func buildWorld() {
        buildSkyDome()
        buildLighting()
        buildTerrain()
        buildOcean()
        buildLakeLeonida()
        buildClouds()
        buildAllAirfields()
        buildViceCitySkyline()
        buildLeonidaLandmarks()

        // Practice targets & balloons
        for _ in 0..<16 {
            let b = makeTargetBalloon()
            b.position = SCNVector3(CGFloat.random(in: -450...450), CGFloat.random(in: 35...120), CGFloat.random(in: -450...450))
            rootNode.addChildNode(b)
            targetNodes.append(b)
        }

        // Spawn plane stationary on VCIA Runway 09R threshold ready for takeoff
        planeNode = PlaneFactory.makePlaneNode(for: plane)
        let spawn = runways[0] // VCIA
        planeNode.position = SCNVector3(spawn.position.x - spawn.length / 2 + 30, spawn.elevation + 0.35, spawn.position.z)
        heading = CGFloat.pi / 2 // pointing East straight down the runway
        planeNode.eulerAngles = SCNVector3(0, heading, 0)
        rootNode.addChildNode(planeNode)

        // Reset flight state to parked
        airspeed = 0
        throttlePct = 0
        isBraking = true
        isGrounded = true
        wasAirborne = false
        flightPhase = "PARKED"

        // Camera setup
        cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 55
        cameraNode.camera?.zFar = 3200
        cameraNode.camera?.zNear = 0.5
        cameraNode.camera?.wantsHDR = true
        cameraNode.camera?.bloomIntensity = 0.45
        cameraNode.camera?.bloomThreshold = 0.8
        cameraNode.camera?.motionBlurIntensity = 0.15
        rootNode.addChildNode(cameraNode)
        updateCamera(snap: true)
    }

    // MARK: - Sky & Lighting

    private func buildSkyDome() {
        let skyGeo = SCNSphere(radius: 1400)
        skyGeo.segmentCount = 48
        let skyMat = SCNMaterial()
        skyMat.lightingModel = .constant
        skyMat.isDoubleSided = true

        let skyTex = generateSkyGradientTexture(size: 512)
        skyMat.diffuse.contents = skyTex
        skyMat.diffuse.wrapS = .clamp
        skyMat.diffuse.wrapT = .clamp
        skyGeo.materials = [skyMat]

        skyDomeNode = SCNNode(geometry: skyGeo)
        skyDomeNode?.renderingOrder = -10
        rootNode.addChildNode(skyDomeNode!)

        fogStartDistance = 400
        fogEndDistance = 1800
        fogColor = NSColor(calibratedRed: 0.68, green: 0.84, blue: 0.96, alpha: 0.38)
        fogDensityExponent = 1.2
    }

    private func generateSkyGradientTexture(size: Int) -> NSImage {
        let img = NSImage(size: NSSize(width: size, height: size))
        img.lockFocus()
        for y in 0..<size {
            let t = CGFloat(y) / CGFloat(size)
            let r: CGFloat, g: CGFloat, b: CGFloat
            if t < 0.18 {
                let f = t / 0.18
                r = 0.98 - f * 0.38
                g = 0.76 - f * 0.14
                b = 0.70 + f * 0.18
            } else if t < 0.55 {
                let f = (t - 0.18) / 0.37
                r = 0.60 - f * 0.28
                g = 0.62 + f * 0.20
                b = 0.88 + f * 0.08
            } else {
                let f = (t - 0.55) / 0.45
                r = 0.32 - f * 0.18
                g = 0.82 - f * 0.35
                b = 0.96 - f * 0.15
            }
            NSColor(calibratedRed: r, green: g, blue: b, alpha: 1).set()
            NSRect(x: 0, y: y, width: size, height: 1).fill()
        }
        img.unlockFocus()
        return img
    }

    private func buildLighting() {
        let sun = SCNNode()
        sun.light = SCNLight()
        sun.light?.type = .directional
        sun.light?.color = NSColor(calibratedRed: 1.0, green: 0.96, blue: 0.88, alpha: 1.0)
        sun.light?.intensity = 1150
        sun.light?.castsShadow = true
        sun.light?.shadowMode = .deferred
        sun.light?.shadowSampleCount = 4
        sun.light?.shadowRadius = 3.0
        sun.eulerAngles = SCNVector3(-CGFloat.pi * 0.32, CGFloat.pi * 0.22, 0)
        rootNode.addChildNode(sun)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.color = NSColor(calibratedRed: 0.46, green: 0.56, blue: 0.66, alpha: 1.0)
        ambient.light?.intensity = 480
        rootNode.addChildNode(ambient)
    }

    // MARK: - Terrain Mesh & Ultra-Detailed Texture

    private func buildTerrain() {
        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var texCoords: [CGPoint] = []
        var indices: [Int32] = []

        let gs = terrainGridSize
        let step = terrainWorldSize / CGFloat(gs - 1)
        let half = terrainWorldSize / 2

        for y in 0..<gs {
            for x in 0..<gs {
                let wx = CGFloat(x) * step - half
                let wz = CGFloat(y) * step - half
                let h = CGFloat(heightMap[y][x])
                vertices.append(SCNVector3(wx, h, wz))

                let u = CGFloat(x) / CGFloat(gs - 1)
                let v = CGFloat(y) / CGFloat(gs - 1)
                texCoords.append(CGPoint(x: u, y: v))

                let hL = CGFloat(heightMap[y][Swift.max(0, x - 1)])
                let hR = CGFloat(heightMap[y][Swift.min(gs - 1, x + 1)])
                let hD = CGFloat(heightMap[Swift.max(0, y - 1)][x])
                let hU = CGFloat(heightMap[Swift.min(gs - 1, y + 1)][x])

                let normal = SCNVector3(-(hR - hL) / (2 * step), 1.0, -(hU - hD) / (2 * step)).normalized()
                normals.append(normal)
            }
        }

        for y in 0..<(gs - 1) {
            for x in 0..<(gs - 1) {
                let topLeft = Int32(y * gs + x)
                let topRight = Int32(y * gs + (x + 1))
                let bottomLeft = Int32((y + 1) * gs + x)
                let bottomRight = Int32((y + 1) * gs + (x + 1))

                indices.append(contentsOf: [topLeft, bottomLeft, topRight, topRight, bottomLeft, bottomRight])
            }
        }

        let vertSource = SCNGeometrySource(vertices: vertices)
        let normSource = SCNGeometrySource(normals: normals)
        let texSource = SCNGeometrySource(textureCoordinates: texCoords)
        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)

        let geo = SCNGeometry(sources: [vertSource, normSource, texSource], elements: [element])
        let mat = SCNMaterial()
        mat.lightingModel = .physicallyBased
        mat.diffuse.contents = generateLeonidaDiffuseTexture(size: 1024)
        mat.roughness.contents = NSNumber(value: 0.82)
        mat.metalness.contents = NSNumber(value: 0.0)
        geo.materials = [mat]

        let terrainNode = SCNNode(geometry: geo)
        rootNode.addChildNode(terrainNode)
    }

    private func generateLeonidaDiffuseTexture(size: Int) -> NSImage {
        let img = NSImage(size: NSSize(width: size, height: size))
        img.lockFocus()

        for py in 0..<size {
            for px in 0..<size {
                let u = CGFloat(px) / CGFloat(size)
                let v = CGFloat(py) / CGFloat(size)
                let wx = (u - 0.5) * terrainWorldSize
                let wz = (v - 0.5) * terrainWorldSize

                let h = sampleHeight(worldX: wx, worldZ: wz)
                var r: CGFloat = 0.26, g: CGFloat = 0.52, b: CGFloat = 0.22

                if h < 0.2 {
                    // Golden beach sand with shoreline surf wash
                    r = 0.90; g = 0.84; b = 0.68
                } else if wz < -220 {
                    // Mount Kalaga: Rocky mountains with pine forests and snow peaks
                    if h > 55 {
                        r = 0.94; g = 0.95; b = 0.98 // snow
                    } else if h > 25 {
                        r = 0.44; g = 0.42; b = 0.39 // granite slate
                    } else {
                        r = 0.16; g = 0.34; b = 0.18 // alpine conifer forest
                    }
                } else if wz >= -220 && wz < -40 && abs(wx) < 220 {
                    // Ambrosia: Patchwork crop fields (sunflower gold / emerald crop rows)
                    let pattern = (Int(wx * 0.05) + Int(wz * 0.05)) % 2 == 0
                    if pattern {
                        r = 0.84; g = 0.74; b = 0.32 // golden harvest
                    } else {
                        r = 0.22; g = 0.58; b = 0.24 // lush green crops
                    }
                } else if wx > 60 && wz >= -60 && wz < 280 {
                    // Vice City: Urban asphalt street grids and coastal sands
                    if wx > 240 {
                        r = 0.92; g = 0.86; b = 0.70 // Ocean Drive sands
                    } else {
                        let isRoad = Int(wx * 0.1) % 4 == 0 || Int(wz * 0.1) % 4 == 0
                        if isRoad {
                            r = 0.25; g = 0.26; b = 0.28 // asphalt street grid
                        } else {
                            r = 0.54; g = 0.56; b = 0.58 // city blocks
                        }
                    }
                } else if wx < -160 && wz >= -160 && wz < 50 {
                    // Port Gellhorn: Industrial asphalt & harbor concrete
                    r = 0.38; g = 0.40; b = 0.42
                } else if wx < 40 && wz >= 40 && wz < 320 {
                    // Everglades: swamp marshlands
                    r = 0.28; g = 0.38; b = 0.20
                } else if wz >= 320 {
                    // Leonida Keys: pristine white coral sand & shallow turquoise rim
                    r = 0.92; g = 0.90; b = 0.80
                }

                NSColor(calibratedRed: r, green: g, blue: b, alpha: 1).set()
                NSRect(x: px, y: py, width: 1, height: 1).fill()
            }
        }

        img.unlockFocus()
        return img
    }

    // MARK: - Ocean & Lake Leonida

    private func buildOcean() {
        let oceanSize: CGFloat = 1600
        let oceanGeo = SCNPlane(width: oceanSize, height: oceanSize)
        oceanGeo.widthSegmentCount = 60
        oceanGeo.heightSegmentCount = 60

        let waterMat = SCNMaterial()
        waterMat.lightingModel = .physicallyBased
        waterMat.diffuse.contents = NSColor(calibratedRed: 0.04, green: 0.30, blue: 0.55, alpha: 0.90)
        waterMat.roughness.contents = NSNumber(value: 0.05)
        waterMat.metalness.contents = NSNumber(value: 0.05)
        waterMat.transparency = 0.92
        waterMat.isDoubleSided = true

        let waveShader = """
        #pragma body
        float2 uv = _surface.diffuseTexcoord;
        float t = scn_frame.time;
        float w1 = sin(uv.x * 60.0 + t * 1.6) * cos(uv.y * 45.0 + t * 0.9) * 0.12;
        float w2 = sin(uv.x * 120.0 - t * 2.2) * cos(uv.y * 90.0 + t * 1.4) * 0.06;
        _surface.normal = normalize(float3(-w1 * 2.0, 1.0, -w2 * 2.0));
        _surface.roughness = 0.04 + abs(w1 + w2) * 0.1;
        """
        waterMat.shaderModifiers = [.surface: waveShader]
        oceanGeo.materials = [waterMat]

        oceanNode = SCNNode(geometry: oceanGeo)
        oceanNode?.position = SCNVector3(0, -1.0, 0)
        oceanNode?.eulerAngles = SCNVector3(-CGFloat.pi / 2, 0, 0)
        rootNode.addChildNode(oceanNode!)
    }

    private func buildLakeLeonida() {
        let lakeGeo = SCNPlane(width: 140, height: 110)
        let lakeMat = SCNMaterial()
        lakeMat.lightingModel = .physicallyBased
        lakeMat.diffuse.contents = NSColor(calibratedRed: 0.10, green: 0.45, blue: 0.60, alpha: 0.95)
        lakeMat.roughness.contents = NSNumber(value: 0.04)
        lakeGeo.materials = [lakeMat]

        lakeNode = SCNNode(geometry: lakeGeo)
        lakeNode?.position = SCNVector3(120, -0.8, -230)
        lakeNode?.eulerAngles = SCNVector3(-CGFloat.pi / 2, 0, 0)
        rootNode.addChildNode(lakeNode!)
    }

    // MARK: - The 6 Leonida Airfields with PAPI Glidepath Lights

    private func buildAllAirfields() {
        for r in runways {
            buildRunwaySurface(r)
            buildPAPILights(r)
        }

        buildVCIASpecialFacilities()
        buildKeysFacilities()
        buildKalagaFacilities()
        buildPortGellhornFacilities()
        buildAmbrosiaFacilities()
        buildEvergladesFacilities()
    }

    private func buildRunwaySurface(_ r: RunwayZone) {
        let node = SCNNode()
        node.position = r.position
        let rad = r.headingDeg * Double.pi / 180.0
        node.eulerAngles = SCNVector3(0, -rad, 0)

        // Realistic asphalt runway with tire touchdown skid marks
        let runwayGeo = SCNPlane(width: r.length, height: r.width)
        let mat = SCNMaterial()
        mat.lightingModel = .physicallyBased
        mat.diffuse.contents = generateRunwayTexture(length: r.length, width: r.width)
        mat.roughness.contents = NSNumber(value: 0.68)
        mat.metalness.contents = NSNumber(value: 0.0)
        runwayGeo.materials = [mat]

        let surface = SCNNode(geometry: runwayGeo)
        surface.eulerAngles = SCNVector3(-CGFloat.pi / 2, 0, 0)
        surface.position = SCNVector3(0, 0.05, 0)
        node.addChildNode(surface)

        // Threshold Piano Keys
        let keyCount = 6
        for side in [-1, 1] as [CGFloat] {
            let endX = side * (r.length / 2 - 8)
            for k in 0..<keyCount {
                let bar = SCNNode(geometry: SCNPlane(width: 8, height: 0.8))
                let yOffset = (CGFloat(k) - CGFloat(keyCount - 1) / 2) * 1.5
                bar.position = SCNVector3(endX, 0.08, yOffset)
                bar.eulerAngles = SCNVector3(-CGFloat.pi / 2, 0, 0)
                bar.geometry?.firstMaterial?.diffuse.contents = NSColor.white
                node.addChildNode(bar)
            }
        }

        // Edge Lights (Yellow/White)
        for side in [-1, 1] as [CGFloat] {
            for x in stride(from: -r.length / 2, through: r.length / 2, by: 18) {
                let light = SCNNode(geometry: SCNSphere(radius: 0.22))
                light.position = SCNVector3(x, 0.18, side * (r.width / 2 + 0.6))
                let lMat = SCNMaterial()
                lMat.lightingModel = .constant
                lMat.diffuse.contents = NSColor.yellow
                lMat.emission.contents = NSColor(calibratedRed: 1.0, green: 0.85, blue: 0.4, alpha: 1)
                light.geometry?.materials = [lMat]
                node.addChildNode(light)
            }
        }

        // Threshold Green Lights
        for end in [-r.length / 2, r.length / 2] {
            for side in stride(from: -r.width / 2, through: r.width / 2, by: 2) {
                let tLight = SCNNode(geometry: SCNSphere(radius: 0.2))
                tLight.position = SCNVector3(end, 0.18, side)
                let tlMat = SCNMaterial()
                tlMat.lightingModel = .constant
                tlMat.diffuse.contents = NSColor.green
                tlMat.emission.contents = NSColor(calibratedRed: 0.2, green: 1.0, blue: 0.4, alpha: 1)
                tLight.geometry?.materials = [tlMat]
                node.addChildNode(tLight)
            }
        }

        rootNode.addChildNode(node)
    }

    private func generateRunwayTexture(length: CGFloat, width: CGFloat) -> NSImage {
        let w = 512, h = 64
        let img = NSImage(size: NSSize(width: w, height: h))
        img.lockFocus()

        // Dark weathered asphalt base
        NSColor(calibratedRed: 0.16, green: 0.17, blue: 0.18, alpha: 1).set()
        NSRect(x: 0, y: 0, width: w, height: h).fill()

        // Dashed Centerline
        NSColor.white.set()
        for i in stride(from: 30, to: w - 30, by: 40) {
            NSRect(x: i, y: h / 2 - 2, width: 22, height: 4).fill()
        }

        // Touchdown Zone Tire Rubber Marks (both ends)
        NSColor(calibratedWhite: 0.08, alpha: 0.55).set()
        for end in [40, w - 100] {
            NSRect(x: end, y: h / 2 - 12, width: 60, height: 8).fill()
            NSRect(x: end, y: h / 2 + 4, width: 60, height: 8).fill()
        }

        // White side boundary stripes
        NSColor.white.set()
        NSRect(x: 0, y: 2, width: w, height: 2).fill()
        NSRect(x: 0, y: h - 4, width: w, height: 2).fill()

        img.unlockFocus()
        return img
    }

    /// 4-Light PAPI (Precision Approach Path Indicator)
    private func buildPAPILights(_ r: RunwayZone) {
        let papiNode = SCNNode()
        let rad = r.headingDeg * Double.pi / 180.0
        papiNode.position = r.position
        papiNode.eulerAngles = SCNVector3(0, -rad, 0)

        // 4 PAPI light boxes on left side of runway threshold
        for i in 0..<4 {
            let lightBox = SCNNode(geometry: SCNSphere(radius: 0.35))
            lightBox.position = SCNVector3(-r.length / 2 + 40, 0.4, (r.width / 2 + 4.0) + CGFloat(i) * 1.8)
            let mat = SCNMaterial()
            mat.lightingModel = .constant
            mat.diffuse.contents = NSColor.white
            mat.emission.contents = NSColor.white
            lightBox.geometry?.materials = [mat]
            lightBox.name = "papi_\(r.code)_\(i)"
            papiNode.addChildNode(lightBox)
            papiNodes.append(lightBox)
        }
        rootNode.addChildNode(papiNode)
    }

    private func buildVCIASpecialFacilities() {
        let vciaPos = SCNVector3(220, 1.2, 120)

        // Cross Runway 14/32
        let crossRunway = RunwayZone(id: "vcia_cross", code: "VCIA", name: "VCIA Cross", zone: "VICE CITY", position: SCNVector3(vciaPos.x, vciaPos.y, vciaPos.z), length: 200, width: 12, headingDeg: 45, elevation: 1.2)
        buildRunwaySurface(crossRunway)

        // 26m Modern Airport Control Tower
        let tower = makeControlTower(height: 26)
        tower.position = SCNVector3(vciaPos.x - 35, vciaPos.y, vciaPos.z - 40)
        rootNode.addChildNode(tower)

        // Passenger Terminal
        let terminal = SCNNode(geometry: SCNBox(width: 75, height: 14, length: 30, chamferRadius: 1))
        terminal.position = SCNVector3(vciaPos.x + 35, vciaPos.y + 7, vciaPos.z - 48)
        let tMat = SCNMaterial()
        tMat.lightingModel = .physicallyBased
        tMat.diffuse.contents = NSColor(calibratedRed: 0.85, green: 0.88, blue: 0.92, alpha: 1)
        terminal.geometry?.materials = [tMat]
        rootNode.addChildNode(terminal)

        // Hangars
        for i in 0..<2 {
            let hangar = makeHangar(width: 28, height: 11, length: 32)
            hangar.position = SCNVector3(vciaPos.x - 85 + CGFloat(i * 38), vciaPos.y, vciaPos.z + 45)
            rootNode.addChildNode(hangar)
        }
    }

    private func buildKeysFacilities() {
        let p = SCNVector3(80, 1.2, 420)
        let shack = makeBuilding(w: 14, h: 6, l: 10, color: NSColor(calibratedRed: 0.9, green: 0.72, blue: 0.55, alpha: 1))
        shack.position = SCNVector3(p.x - 18, p.y + 3, p.z - 22)
        rootNode.addChildNode(shack)

        for _ in 0..<12 {
            let palm = makeRealisticPalmTree()
            palm.position = SCNVector3(p.x + CGFloat.random(in: -45...45), p.y, p.z + CGFloat.random(in: -35...35))
            rootNode.addChildNode(palm)
        }
    }

    private func buildKalagaFacilities() {
        let p = SCNVector3(-80, 48.2, -360)
        let tower = makeControlTower(height: 14)
        tower.position = SCNVector3(p.x - 18, p.y, p.z)
        rootNode.addChildNode(tower)

        for _ in 0..<18 {
            let tree = makeRealisticTree()
            tree.position = SCNVector3(p.x + CGFloat.random(in: -50...50), p.y, p.z + CGFloat.random(in: -40...40))
            rootNode.addChildNode(tree)
        }
    }

    private func buildPortGellhornFacilities() {
        let p = SCNVector3(-320, 1.2, -60)
        let colors: [NSColor] = [.systemRed, .systemBlue, .systemYellow, .systemGreen, .systemOrange]
        for i in 0..<8 {
            let box = SCNNode(geometry: SCNBox(width: 8, height: 4, length: 18, chamferRadius: 0.1))
            box.position = SCNVector3(p.x - 30 + CGFloat(i % 4 * 10), p.y + 2 + CGFloat(i / 4 * 4), p.z + 30)
            let bMat = SCNMaterial()
            bMat.lightingModel = .physicallyBased
            bMat.diffuse.contents = colors[i % colors.count]
            box.geometry?.materials = [bMat]
            rootNode.addChildNode(box)
        }
    }

    private func buildAmbrosiaFacilities() {
        let p = SCNVector3(40, 6.2, -100)
        let barn = makeBuilding(w: 18, h: 10, l: 24, color: NSColor(calibratedRed: 0.75, green: 0.2, blue: 0.15, alpha: 1))
        barn.position = SCNVector3(p.x - 24, p.y + 5, p.z - 16)
        rootNode.addChildNode(barn)

        let silo = SCNNode(geometry: SCNCylinder(radius: 3.8, height: 18))
        silo.position = SCNVector3(p.x - 36, p.y + 9, p.z - 16)
        let sMat = SCNMaterial()
        sMat.lightingModel = .physicallyBased
        sMat.diffuse.contents = NSColor(calibratedRed: 0.8, green: 0.82, blue: 0.85, alpha: 1)
        silo.geometry?.materials = [sMat]
        rootNode.addChildNode(silo)
    }

    private func buildEvergladesFacilities() {
        let p = SCNVector3(-160, 1.2, 200)
        let tower = makeControlTower(height: 12)
        tower.position = SCNVector3(p.x - 16, p.y, p.z - 15)
        rootNode.addChildNode(tower)

        for _ in 0..<14 {
            let tree = makeRealisticTree()
            tree.position = SCNVector3(p.x + CGFloat.random(in: -40...40), p.y, p.z + CGFloat.random(in: -40...40))
            rootNode.addChildNode(tree)
        }
    }

    // MARK: - Vice City Skyline & Landmarks

    private func buildViceCitySkyline() {
        let cityX: CGFloat = 190
        let cityZ: CGFloat = 40

        for i in 0..<22 {
            let h = CGFloat.random(in: 25...75)
            let w = CGFloat.random(in: 12...22)
            let l = CGFloat.random(in: 12...22)
            let ox = cityX + CGFloat(i % 5 * 28) - 60
            let oz = cityZ + CGFloat(i / 5 * 28) - 50

            let b = SCNNode(geometry: SCNBox(width: w, height: h, length: l, chamferRadius: 0.5))
            b.position = SCNVector3(ox, 1.5 + h / 2, oz)

            let mat = SCNMaterial()
            mat.lightingModel = .physicallyBased
            if i % 3 == 0 {
                mat.diffuse.contents = NSColor(calibratedRed: 0.2, green: 0.45, blue: 0.65, alpha: 1)
                mat.roughness.contents = NSNumber(value: 0.15)
                mat.metalness.contents = NSNumber(value: 0.7)
            } else {
                mat.diffuse.contents = NSColor(calibratedRed: 0.80, green: 0.82, blue: 0.85, alpha: 1)
                mat.roughness.contents = NSNumber(value: 0.45)
            }
            b.geometry?.materials = [mat]
            b.castsShadow = true
            rootNode.addChildNode(b)

            if h > 50 {
                let rLight = SCNNode(geometry: SCNSphere(radius: 0.5))
                rLight.position = SCNVector3(ox, 1.5 + h + 0.6, oz)
                let rlMat = SCNMaterial()
                rlMat.lightingModel = .constant
                rlMat.diffuse.contents = NSColor.red
                rlMat.emission.contents = NSColor.red
                rLight.geometry?.materials = [rlMat]
                rootNode.addChildNode(rLight)
                beaconNodes.append(rLight)
            }
        }
    }

    private func buildLeonidaLandmarks() {
        for i in 0..<8 {
            let bridge = SCNNode(geometry: SCNBox(width: 8, height: 1.5, length: 30, chamferRadius: 0.2))
            bridge.position = SCNVector3(70 - CGFloat(i * 12), 1.0, 340 + CGFloat(i * 26))
            let bMat = SCNMaterial()
            bMat.lightingModel = .physicallyBased
            bMat.diffuse.contents = NSColor(calibratedRed: 0.7, green: 0.72, blue: 0.75, alpha: 1)
            bridge.geometry?.materials = [bMat]
            rootNode.addChildNode(bridge)
        }
    }

    private func makeControlTower(height: CGFloat) -> SCNNode {
        let node = SCNNode()
        let shaft = SCNNode(geometry: SCNCylinder(radius: 2.2, height: height))
        shaft.position = SCNVector3(0, height / 2, 0)
        let sMat = SCNMaterial()
        sMat.lightingModel = .physicallyBased
        sMat.diffuse.contents = NSColor(calibratedRed: 0.82, green: 0.85, blue: 0.88, alpha: 1)
        shaft.geometry?.materials = [sMat]
        node.addChildNode(shaft)

        let cab = SCNNode(geometry: SCNCylinder(radius: 4.2, height: 3.5))
        cab.position = SCNVector3(0, height + 1.75, 0)
        let cMat = SCNMaterial()
        cMat.lightingModel = .physicallyBased
        cMat.diffuse.contents = NSColor(calibratedRed: 0.15, green: 0.45, blue: 0.65, alpha: 0.9)
        cab.geometry?.materials = [cMat]
        node.addChildNode(cab)

        let beacon = SCNNode(geometry: SCNSphere(radius: 0.6))
        beacon.position = SCNVector3(0, height + 4.0, 0)
        let bMat = SCNMaterial()
        bMat.lightingModel = .constant
        bMat.diffuse.contents = NSColor.white
        bMat.emission.contents = NSColor.white
        beacon.geometry?.materials = [bMat]
        node.addChildNode(beacon)
        beaconNodes.append(beacon)

        return node
    }

    private func makeHangar(width: CGFloat, height: CGFloat, length: CGFloat) -> SCNNode {
        let hangar = SCNNode(geometry: SCNBox(width: width, height: height, length: length, chamferRadius: 1))
        hangar.position = SCNVector3(0, height / 2, 0)
        let hMat = SCNMaterial()
        hMat.lightingModel = .physicallyBased
        hMat.diffuse.contents = NSColor(calibratedRed: 0.75, green: 0.78, blue: 0.82, alpha: 1)
        hMat.metalness.contents = NSNumber(value: 0.5)
        hangar.geometry?.materials = [hMat]
        return hangar
    }

    private func makeBuilding(w: CGFloat = 10, h: CGFloat = 8, l: CGFloat = 10, color: NSColor? = nil) -> SCNNode {
        let b = SCNNode(geometry: SCNBox(width: w, height: h, length: l, chamferRadius: 0.2))
        let mat = SCNMaterial()
        mat.lightingModel = .physicallyBased
        mat.diffuse.contents = color ?? NSColor(calibratedRed: 0.8, green: 0.8, blue: 0.85, alpha: 1)
        b.geometry?.materials = [mat]
        return b
    }

    private func makeRealisticTree() -> SCNNode {
        let tree = SCNNode()
        let h = CGFloat.random(in: 4...8)
        let trunk = SCNNode(geometry: SCNCylinder(radius: 0.4, height: h))
        trunk.position = SCNVector3(0, h / 2, 0)
        trunk.geometry?.firstMaterial?.diffuse.contents = NSColor(calibratedRed: 0.35, green: 0.22, blue: 0.12, alpha: 1)
        tree.addChildNode(trunk)

        let leaf = SCNNode(geometry: SCNCone(topRadius: 0, bottomRadius: 2.8, height: h * 1.2))
        leaf.position = SCNVector3(0, h + h * 0.4, 0)
        leaf.geometry?.firstMaterial?.diffuse.contents = NSColor(calibratedRed: 0.12, green: 0.38, blue: 0.16, alpha: 1)
        tree.addChildNode(leaf)
        return tree
    }

    private func makeRealisticPalmTree() -> SCNNode {
        let palm = SCNNode()
        let h: CGFloat = 9
        let trunk = SCNNode(geometry: SCNCylinder(radius: 0.35, height: h))
        trunk.position = SCNVector3(0, h / 2, 0)
        trunk.geometry?.firstMaterial?.diffuse.contents = NSColor(calibratedRed: 0.5, green: 0.35, blue: 0.2, alpha: 1)
        palm.addChildNode(trunk)

        for _ in 0..<5 {
            let frond = SCNNode(geometry: SCNSphere(radius: 2.2))
            frond.scale = SCNVector3(1.2, 0.25, 2.8)
            frond.position = SCNVector3(CGFloat.random(in: -1...1), h, CGFloat.random(in: -1...1))
            frond.eulerAngles = SCNVector3(0.2, CGFloat.random(in: 0...CGFloat.pi * 2), 0.2)
            frond.geometry?.firstMaterial?.diffuse.contents = NSColor(calibratedRed: 0.15, green: 0.55, blue: 0.2, alpha: 1)
            palm.addChildNode(frond)
        }
        return palm
    }

    private func makeTargetBalloon() -> SCNNode {
        let n = SCNNode()
        let body = SCNNode(geometry: SCNSphere(radius: 2.0))
        let mat = SCNMaterial()
        mat.lightingModel = .physicallyBased
        mat.diffuse.contents = NSColor(calibratedRed: 0.95, green: 0.2, blue: 0.25, alpha: 1)
        mat.roughness.contents = NSNumber(value: 0.3)
        body.geometry?.materials = [mat]
        n.addChildNode(body)
        return n
    }

    private func buildClouds() {
        for _ in 0..<20 {
            let c = SCNNode()
            for _ in 0..<5 {
                let p = SCNNode(geometry: SCNSphere(radius: CGFloat.random(in: 18...35)))
                p.position = SCNVector3(CGFloat.random(in: -30...30), CGFloat.random(in: -5...5), CGFloat.random(in: -30...30))
                let m = SCNMaterial()
                m.lightingModel = .physicallyBased
                m.diffuse.contents = NSColor.white
                m.transparency = 0.85
                p.geometry?.materials = [m]
                c.addChildNode(p)
            }
            c.position = SCNVector3(CGFloat.random(in: -600...600), CGFloat.random(in: 120...240), CGFloat.random(in: -600...600))
            rootNode.addChildNode(c)
            cloudNodes.append(c)
        }
    }

    // MARK: - Per-Frame Realistic Flight Dynamics & Takeoff/Landing Loop

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime t: TimeInterval) {
        let dt: CGFloat = 1.0 / 60.0
        time = t

        // Airport beacon blink
        let beaconOn = Int(time * 2.0) % 2 == 0
        for b in beaconNodes { b.isHidden = !beaconOn }
        PlaneFactory.updateStrobes(planeNode, time: time)

        // 1. Inputs: GTA V Keyboard + Mouse Controls
        let mousePitch = CGFloat(-mouseSteer.dy) * CGFloat(sensitivity)
        let mouseRoll = CGFloat(mouseSteer.dx) * CGFloat(sensitivity) * CGFloat(plane.turnSpeed)

        let pitchTotal = (mousePitch * 0.7 + pitchInput * 0.9).clamped(to: -1...1)
        let rollTotal = (mouseRoll * 0.7 + rollInput * 0.9).clamped(to: -1...1)
        let rudderTotal = (rudderInput * 0.8 + (mouseRoll * 0.35)).clamped(to: -1...1)

        // Progressive Throttle Control
        if throttleChange != 0 {
            throttlePct = Int((CGFloat(throttlePct) + throttleChange * 30.0 * dt).clamped(to: 0...100))
            if throttlePct > 10 { isBraking = false }
        }
        let effectiveThrottle = boostHeld ? 100 : throttlePct

        // 2. Runway Surface & Airfield Elevation Check
        let px = planeNode.position.x
        let pz = planeNode.position.z
        var groundElev = sampleHeight(worldX: px, worldZ: pz)
        var currentlyOnRunway = false
        var activeRunway: RunwayZone? = nil

        for r in runways {
            let dx = abs(px - r.position.x)
            let dz = abs(pz - r.position.z)
            if dx < r.length / 2 + 15 && dz < r.width / 2 + 8 {
                groundElev = r.elevation
                currentlyOnRunway = true
                activeRunway = r
                break
            }
        }

        let wheelHeight = groundElev + 0.35
        isGrounded = planeNode.position.y <= wheelHeight + 0.12

        // 3. PAPI Glidepath Evaluation for Nearest Airfield
        let (nearestAfCode, distAf) = findNearestAirfield(x: px, z: pz)
        var papiState = 2 // 2 White 2 Red (on slope)
        if let targetAf = runways.first(where: { $0.code == nearestAfCode }) {
            let altFt = (planeNode.position.y - targetAf.elevation) * 3.28084
            let distNm = distAf / 1852.0
            if distNm > 0.05 && distNm < 3.0 {
                let nominalAltFt = distNm * 318.0 // 3 degree glidepath ~ 318 ft/NM
                let diff = altFt - nominalAltFt
                if diff > 150 { papiState = 0 }      // 4 White (very high)
                else if diff > 50 { papiState = 1 }  // 3 White 1 Red
                else if diff > -50 { papiState = 2 } // 2 White 2 Red (optimal)
                else if diff > -150 { papiState = 3 }// 1 White 3 Red
                else { papiState = 4 }               // 4 Red (low)
            }
        }

        // 4. Ground Taxiing vs Takeoff Roll vs Flight Dynamics
        if isGrounded {
            planeNode.position.y = wheelHeight
            angleOfAttack = 0
            bank = 0

            // Touchdown evaluation
            if wasAirborne {
                wasAirborne = false
                let sinkRate = abs(verticalSpeed)

                if !gearDown {
                    touchdownRating = "💥 BELLY SCRAPE! GEAR WAS UP!"
                    SoundManager.shared.boing()
                } else if sinkRate < 1.0 {
                    touchdownRating = "🧈 BUTTER! PERFECT LANDING! ⭐⭐⭐"
                    SoundManager.shared.touchdown()
                    SoundManager.shared.fanfare()
                } else if sinkRate < 2.5 {
                    touchdownRating = "👍 SMOOTH LANDING! ⭐⭐"
                    SoundManager.shared.touchdown()
                } else if sinkRate < 4.0 {
                    touchdownRating = "🛬 ACCEPTABLE TOUCHDOWN! ⭐"
                    SoundManager.shared.touchdown()
                } else {
                    touchdownRating = "💥 HARD LANDING! BOUNCED!"
                    SoundManager.shared.boing()
                }

                if let rName = activeRunway?.name {
                    onTouchdown?("\(touchdownRating ?? "") (\(rName.uppercased()))")
                }
                verticalSpeed = 0
            }

            // Taxi nosewheel steering
            heading -= rudderTotal * 1.6 * Swift.max(0.2, airspeed / 22.0) * dt

            // Ground Acceleration / Braking
            if isBraking || effectiveThrottle == 0 {
                flightPhase = airspeed < 1 ? "PARKED" : "BRAKING"
                airspeed = Swift.max(0, airspeed - 18.0 * dt)
            } else {
                let targetGroundSpeed = CGFloat(effectiveThrottle) * 0.42
                if airspeed < targetGroundSpeed {
                    flightPhase = airspeed < 12 ? "TAXI" : "TAKEOFF ROLL"
                    airspeed += (CGFloat(effectiveThrottle) / 100.0) * 12.0 * dt
                } else {
                    airspeed = Swift.max(0, airspeed - 5.0 * dt)
                }

                // Rotation Prompt & Lift-off
                if airspeed >= stallSpeed * 1.15 {
                    flightPhase = "ROTATE!"
                    // Pilot pulls back (pitchTotal > 0.2)
                    if pitchTotal > 0.2 {
                        isGrounded = false
                        wasAirborne = true
                        verticalSpeed = 3.2 * pitchTotal
                        planeNode.position.y += verticalSpeed * dt
                        flightPhase = "AIRBORNE - CLIMBING"
                        SoundManager.shared.ring()
                    }
                }
            }
        } else {
            // Airborne Flight Dynamics
            wasAirborne = true

            // Flaps effect: extra lift + slight drag
            let flapLiftMult: CGFloat = flapsDeg == 30 ? 1.35 : (flapsDeg == 15 ? 1.18 : 1.0)
            let flapDragAdd: CGFloat = flapsDeg == 30 ? 0.015 : (flapsDeg == 15 ? 0.007 : 0.0)

            // Angle of attack
            angleOfAttack = pitchTotal * 0.8 - sideSlip * 0.4

            // Lift Generation
            let maxLift: CGFloat = 26.5 * flapLiftMult
            let liftCurve: CGFloat = -0.15 * angleOfAttack * angleOfAttack + 0.8 * angleOfAttack
            let lift = maxLift * Swift.min(1.2, Swift.max(-1.0, liftCurve)) * (airspeed / 28.0)

            // Aerodynamic Drag (Gear down adds drag!)
            let gearDrag: CGFloat = gearDown ? 0.012 : 0.0
            let dragCoeff = 0.022 * (airspeed / 28.0) + gearDrag + flapDragAdd
            let drag = -airspeed * dragCoeff * airspeed

            // Engine Thrust
            let baseThrust = CGFloat(plane.topSpeed) * 0.17 * (CGFloat(effectiveThrottle) / 60.0)
            let thrust = boostHeld ? baseThrust * 1.85 : baseThrust

            // Gravity
            let gravity: CGFloat = 24.5

            // Vertical Acceleration
            let netLift = lift - gravity
            verticalSpeed += (netLift / 9.5) * dt
            verticalSpeed = Swift.max(-12, Swift.min(12, verticalSpeed))

            // Forward Airspeed
            let speedAccel = (thrust + drag) / 10.0
            airspeed += speedAccel * dt
            airspeed = Swift.max(stallSpeed * 0.65, Swift.min(CGFloat(plane.topSpeed) * 1.65, airspeed))

            // Banked Turning
            let turnFromBank = Double(sin(bank)) * Double(airspeed) * 0.0095
            let turnFromRudder = Double(rudderTotal) * Double(plane.turnSpeed) * 0.45
            heading -= CGFloat(turnFromBank + turnFromRudder) * dt

            let targetBank = rollTotal * (CGFloat.pi / 3.2)
            bank += (targetBank - bank) * 6.0 * dt
            sideSlip = rudderTotal * 0.3 * dt

            // Vertical position update
            planeNode.position.y += verticalSpeed * dt

            // Flight phase determination
            let relAlt = planeNode.position.y - groundElev
            if relAlt < 4.5 && verticalSpeed < -0.5 {
                flightPhase = "FLARE!"
            } else if relAlt < 35 && currentlyOnRunway {
                flightPhase = "APPROACH"
            } else if verticalSpeed > 1.5 {
                flightPhase = "CLIMBING"
            } else {
                flightPhase = "CRUISE"
            }

            // Ground touchdown
            if planeNode.position.y <= wheelHeight {
                planeNode.position.y = wheelHeight
                isGrounded = true
            }
        }

        // 5. Plane Forward Motion
        let forwardStep = airspeed * dt
        planeNode.position.x += sin(heading) * cos(bank) * forwardStep
        planeNode.position.z += -cos(heading) * cos(bank) * forwardStep

        let pitchRot = isGrounded ? 0 : angleOfAttack * 0.6
        planeNode.eulerAngles = SCNVector3(pitchRot, heading, -bank)

        // Propeller & Boost effects
        PlaneFactory.spinPropeller(planeNode, delta: dt * (effectiveThrottle > 60 ? 3.0 : 1.5))
        PlaneFactory.setBoost(planeNode, on: boostHeld)
        PlaneFactory.setGear(planeNode, down: gearDown)

        // World Bounds Wrapping
        let bound: CGFloat = terrainWorldSize / 2
        if planeNode.position.x > bound { planeNode.position.x -= terrainWorldSize }
        if planeNode.position.x < -bound { planeNode.position.x += terrainWorldSize }
        if planeNode.position.z > bound { planeNode.position.z -= terrainWorldSize }
        if planeNode.position.z < -bound { planeNode.position.z += terrainWorldSize }

        // Balloons Practice
        for t in targetNodes where !t.isHidden {
            if planeNode.position.distance(to: t.position) < 6.0 {
                t.isHidden = true
                onTargetHit?(t.position.x, t.position.z)
                SoundManager.shared.pickup()
                DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                    t.position = SCNVector3(CGFloat.random(in: -450...450), CGFloat.random(in: 40...100), CGFloat.random(in: -450...450))
                    t.isHidden = false
                }
            }
        }

        skyDomeNode?.position = SCNVector3(planeNode.position.x, 0, planeNode.position.z)
        oceanNode?.position = SCNVector3(planeNode.position.x, -1.0, planeNode.position.z)
        updateCamera(snap: false)

        // 6. Telemetry Emission
        altitude = Swift.max(0, planeNode.position.y - groundElev)
        let hdgDeg = (-heading * 180 / CGFloat.pi).truncatingRemainder(dividingBy: 360)
        let hdgNorm = (hdgDeg + 360).truncatingRemainder(dividingBy: 360)
        let pitchDeg = Double(angleOfAttack * 180 / CGFloat.pi)
        let bankDeg = Double(bank * 180 / CGFloat.pi)
        gForce = Swift.max(0.5, 1.0 + Double(abs(verticalSpeed)) * 0.05 + (Double(effectiveThrottle) > 80 ? 0.4 : 0.0))

        let (zoneName, subzoneName) = detectCurrentZone(x: px, z: pz)

        var runwayAlign: Double = 0
        if let targetAf = runways.first(where: { $0.code == nearestAfCode }) {
            runwayAlign = (targetAf.headingDeg - hdgNorm).truncatingRemainder(dividingBy: 360)
        }

        let telem = FlightTelemetry(
            altitude: altitude * 3.28084,
            verticalSpeed: verticalSpeed,
            airspeed: airspeed * 1.94384,
            headingDeg: hdgNorm,
            isBoosting: boostHeld,
            pitchDeg: pitchDeg,
            bankDeg: bankDeg,
            throttlePct: effectiveThrottle,
            flapsDeg: flapsDeg,
            isBraking: isBraking,
            gForce: gForce,
            gearDown: gearDown,
            cameraMode: cameraMode,
            zone: zoneName,
            subzone: subzoneName,
            posX: px,
            posZ: pz,
            nearestAirfield: nearestAfCode,
            distToNearestAirfield: distAf,
            onRunway: currentlyOnRunway,
            runwayAlignmentDeg: runwayAlign,
            papiState: papiState,
            flightPhase: flightPhase
        )

        DispatchQueue.main.async {
            self.onTelemetry?(telem)
            self.onStats?(CGFloat(self.altitude * 3.28), self.verticalSpeed, self.airspeed, CGFloat(hdgNorm), self.boostHeld, CGFloat(pitchDeg), CGFloat(bankDeg))
        }
    }

    // MARK: - GTA VI Zones & Navigation

    private func detectCurrentZone(x: CGFloat, z: CGFloat) -> (String, String) {
        if z < -240 {
            return ("MOUNT KALAGA", "National Wilderness & Peaks")
        } else if z > 320 {
            return ("LEONIDA KEYS", "Tropical Coral Archipelago")
        } else if x < -160 && z >= -160 && z < 50 {
            return ("PORT GELLHORN", "Industrial Harbor & Bay")
        } else if x < 30 && z >= 40 && z < 320 {
            return ("GRASSRIVERS", "The Everglades Wetlands")
        } else if z >= -220 && z < -40 && abs(x) < 200 {
            return ("AMBROSIA", "Heartland Agricultural Plains")
        } else if x > 40 && z >= -70 && z < 290 {
            return ("VICE CITY", "Metropolitan Beach District")
        } else {
            return ("LEONIDA COAST", "Oceanic Flight Corridor")
        }
    }

    private func findNearestAirfield(x: CGFloat, z: CGFloat) -> (String, CGFloat) {
        var closestCode = "VCIA"
        var minDist: CGFloat = 999999
        for r in runways {
            let dx = x - r.position.x
            let dz = z - r.position.z
            let d = sqrt(dx * dx + dz * dz)
            if d < minDist {
                minDist = d
                closestCode = r.code
            }
        }
        return (closestCode, minDist)
    }

    func respawnAtNearestRunway() {
        let (code, _) = findNearestAirfield(x: planeNode.position.x, z: planeNode.position.z)
        guard let target = runways.first(where: { $0.code == code }) else { return }

        let rad = target.headingDeg * Double.pi / 180.0
        heading = CGFloat(rad)
        planeNode.position = SCNVector3(target.position.x - CGFloat(cos(rad)) * (target.length / 2 - 30), target.elevation + 0.35, target.position.z - CGFloat(sin(rad)) * (target.length / 2 - 30))
        planeNode.eulerAngles = SCNVector3(0, heading, 0)
        airspeed = 0
        throttlePct = 0
        isBraking = true
        verticalSpeed = 0
        isGrounded = true
        wasAirborne = false
        gearDown = true
        flightPhase = "PARKED"
        updateCamera(snap: true)
    }

    // MARK: - GTA Camera Modes

    private func updateCamera(snap: Bool) {
        guard let camera = cameraNode.camera else { return }

        var camDist: CGFloat = 14
        var camUp: CGFloat = 4.5
        var fov: CGFloat = 55

        switch cameraMode {
        case 0:
            camDist = 13.5
            camUp = 4.2
            fov = 55 + Swift.min(15, (airspeed - 20) * 0.4)
        case 1:
            camDist = 22.0
            camUp = 7.0
            fov = 65 + Swift.min(18, (airspeed - 20) * 0.5)
        case 2:
            camDist = -2.2
            camUp = 0.8
            fov = 70 + Swift.min(15, (airspeed - 20) * 0.3)
        default:
            break
        }

        camera.fieldOfView = fov

        let cx = planeNode.position.x + sin(heading) * camDist
        let cz = planeNode.position.z + cos(heading) * camDist
        let cy = planeNode.position.y + camUp
        var targetCamPos = SCNVector3(cx, cy, cz)

        if airspeed > 35 && cameraMode != 2 {
            let shake = (airspeed - 35) * 0.004
            targetCamPos.x += CGFloat.random(in: -shake...shake)
            targetCamPos.y += CGFloat.random(in: -shake...shake)
        }

        if snap {
            cameraNode.position = targetCamPos
        } else {
            cameraNode.position = cameraNode.position.lerp(to: targetCamPos, t: 0.16)
        }

        if cameraMode == 2 {
            let forwardLook = SCNVector3(
                planeNode.position.x - sin(heading) * 100,
                planeNode.position.y + angleOfAttack * 40,
                planeNode.position.z + cos(heading) * 100
            )
            cameraNode.look(at: forwardLook)
        } else {
            cameraNode.look(at: SCNVector3(planeNode.position.x, planeNode.position.y + 0.5, planeNode.position.z))
        }
    }
}

// MARK: - Extensions

private extension SCNVector3 {
    func distance(to other: SCNVector3) -> CGFloat {
        let dx = x - other.x, dy = y - other.y, dz = z - other.z
        return sqrt(dx * dx + dy * dy + dz * dz)
    }
    func lerp(to other: SCNVector3, t: CGFloat) -> SCNVector3 {
        SCNVector3(x + (other.x - x) * t, y + (other.y - y) * t, z + (other.z - z) * t)
    }
    func normalized() -> SCNVector3 {
        let len = sqrt(x * x + y * y + z * z)
        guard len > 0.0001 else { return SCNVector3(0, 1, 0) }
        return SCNVector3(x / len, y / len, z / len)
    }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}