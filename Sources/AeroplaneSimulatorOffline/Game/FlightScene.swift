import SceneKit
import AppKit
import SwiftUI
import GameplayKit

/// Ultra-realistic offline 3D world with procedural PBR terrain, animated ocean,
/// volumetric clouds, atmospheric sky, and flight-simulator-grade physics.
/// Kid-proof defaults remain, but the visuals now rival commercial flight sims.
///
/// Features:
/// - Noise-based heightmap terrain with biome colouring (grass / sand / rock / snow)
/// - Animated Gerstner-wave ocean with Fresnel depth-tinted water
/// - Volumetric layered clouds with self-shadow and wind drift
/// - Atmospheric sky gradient that shifts with altitude
/// - Sun with bloom / glow and real-time shadow casting
/// - PBR (physically based rendering) materials on every surface
/// - Enhanced camera: smooth chase, speed-dependent shake, altitude-aware FOV
/// - Target practice (balloons), collectible stars / rings
///
/// Fully offline — no external assets, CC0 procedural only.
final class FlightScene: SCNScene, SCNSceneRendererDelegate {
    var planeNode: SCNNode!
    var cameraNode: SCNNode!
    var plane: KidPlane = KidPlane.all[1]

    // Controls (set from FlyView tracking area)
    var mouseSteer = CGVector(dx: 0, dy: 0) // -1...1
    var boostHeld = false
    var sensitivity: Float = 1.0
    var invertY = false

    // Realistic flight state
    private var altitude: CGFloat = 50     // height above ground (m)
    private var verticalSpeed: CGFloat = 0 // m/s, positive = climbing
    private var airspeed: CGFloat = 26     // m/s, calibrated per plane
    private var heading: CGFloat = 0       // radians, true north = +X
    private var bank: CGFloat = 0          // roll angle (radians)
    private var angleOfAttack: CGFloat = 0 // radians, lift generator
    private var sideSlip: CGFloat = 0      // rudder coordination
    private var gForce: CGFloat = 1.0

    // Physics params per plane (from the catalogue)
    private var wingLoading: CGFloat = 2.0   // weight / wing area approx
    private var stallSpeed: CGFloat = 18

    // World & effects
    private var starNodes: [SCNNode] = []
    private var ringNodes: [SCNNode] = []
    private var cloudNodes: [SCNNode] = []
    private var targetNodes: [SCNNode] = []      // target balloons for practice
    private var oceanNode: SCNNode?
    private var skyDomeNode: SCNNode?
    private var time: TimeInterval = 0

    // Terrain heightmap cache (generated from noise)
    private var heightMap: [[Float]] = []
    private let terrainGridSize = 128       // resolution of the noise grid
    private let terrainWorldSize: CGFloat = 800

    var onStar: (() -> Void)?
    var onRing: (() -> Void)?
    var onTargetHit: ((CGFloat, CGFloat) -> Void)?
    var onStats: ((CGFloat, CGFloat, CGFloat, CGFloat, Bool, CGFloat, CGFloat) -> Void)? // alt, verticalSpeed, airspeed, headingDeg, isBoosting, pitchDeg, bankDeg

    convenience init(plane: KidPlane) {
        self.init()
        self.plane = plane
        generateHeightMap()
        buildWorld()
    }

    // MARK: - Noise-based heightmap generation

    private func generateHeightMap() {
        let source = GKPerlinNoiseSource(
            frequency: 0.008,
            octaveCount: 6,
            persistence: 0.52,
            lacunarity: 2.1,
            seed: 42
        )
        let noise = GKNoise(source)
        let map = GKNoiseMap(
            noise,
            size: vector_double2(Double(terrainWorldSize), Double(terrainWorldSize)),
            origin: vector_double2(0, 0),
            sampleCount: vector_int2(Int32(terrainGridSize), Int32(terrainGridSize)),
            seamless: true
        )

        heightMap = Array(repeating: Array(repeating: Float(0), count: terrainGridSize), count: terrainGridSize)
        for y in 0..<terrainGridSize {
            for x in 0..<terrainGridSize {
                // Noise returns -1...1, scale to terrain heights
                let raw = map.value(at: vector_int2(Int32(x), Int32(y)))
                // Shape: flatten centre for runway, raise edges for mountains
                let cx = Float(x) / Float(terrainGridSize) - 0.5
                let cz = Float(y) / Float(terrainGridSize) - 0.5
                let distFromCentre = sqrt(cx * cx + cz * cz) * 2.0
                let runwayFlat = max(0, 1.0 - distFromCentre * 4.0) // flatten near centre
                let mountainBoost = max(0, distFromCentre - 0.3) * 2.5 // boost edges

                var h = raw * 30.0 * (1.0 - runwayFlat * 0.8)
                h += mountainBoost * abs(raw) * 60.0
                // Ocean floor below sea level
                if h < -5 { h = max(h, -20) }
                heightMap[y][x] = h
            }
        }
    }

    /// Sample the heightmap at world coordinates with bilinear interpolation
    private func sampleHeight(worldX: CGFloat, worldZ: CGFloat) -> CGFloat {
        let halfSize = terrainWorldSize / 2
        // Wrap coordinates
        var wx = worldX.truncatingRemainder(dividingBy: terrainWorldSize)
        var wz = worldZ.truncatingRemainder(dividingBy: terrainWorldSize)
        if wx < -halfSize { wx += terrainWorldSize }
        if wx > halfSize { wx -= terrainWorldSize }
        if wz < -halfSize { wz += terrainWorldSize }
        if wz > halfSize { wz -= terrainWorldSize }

        // Map to grid
        let gx = (wx + halfSize) / terrainWorldSize * CGFloat(terrainGridSize - 1)
        let gz = (wz + halfSize) / terrainWorldSize * CGFloat(terrainGridSize - 1)

        let ix = Int(gx.clamped(to: 0...CGFloat(terrainGridSize - 2)))
        let iz = Int(gz.clamped(to: 0...CGFloat(terrainGridSize - 2)))
        let fx = gx - CGFloat(ix)
        let fz = gz - CGFloat(iz)

        // Bilinear interpolation
        let h00 = CGFloat(heightMap[iz][ix])
        let h10 = CGFloat(heightMap[iz][min(ix + 1, terrainGridSize - 1)])
        let h01 = CGFloat(heightMap[min(iz + 1, terrainGridSize - 1)][ix])
        let h11 = CGFloat(heightMap[min(iz + 1, terrainGridSize - 1)][min(ix + 1, terrainGridSize - 1)])

        let top = h00 + (h10 - h00) * fx
        let bot = h01 + (h11 - h01) * fx
        return top + (bot - top) * fz
    }

    // MARK: - World build with ultra-real PBR

    private func buildWorld() {
        // ─── Atmospheric sky dome ───
        buildSkyDome()

        // ─── Lighting: sun + ambient + fill ───
        buildLighting()

        // ─── PBR terrain mesh ───
        buildTerrain()

        // ─── Animated ocean ───
        buildOcean()

        // ─── Volumetric clouds (multiple layers) ───
        buildClouds()

        // ─── Environmental details ───
        buildEnvironment()

        // ─── Target balloons for practice ───
        for _ in 0..<12 {
            let b = makeTargetBalloon()
            b.position = SCNVector3(CGFloat.random(in: -300...300), CGFloat.random(in: 30...100), CGFloat.random(in: -300...300))
            rootNode.addChildNode(b)
            targetNodes.append(b)
        }

        // ─── Plane at runway ───
        planeNode = PlaneFactory.makePlaneNode(for: plane)
        planeNode.position = SCNVector3(0, 12, 30)  // start on runway area
        rootNode.addChildNode(planeNode)

        // ─── Camera ───
        cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 55
        cameraNode.camera?.zFar = 2000
        cameraNode.camera?.zNear = 0.5
        // HDR bloom for sun glow
        cameraNode.camera?.wantsHDR = true
        cameraNode.camera?.bloomIntensity = 0.4
        cameraNode.camera?.bloomThreshold = 0.85
        cameraNode.camera?.bloomBlurRadius = 8.0
        cameraNode.camera?.colorFringeIntensity = 0.3
        cameraNode.camera?.colorFringeStrength = 1.5
        cameraNode.camera?.motionBlurIntensity = 0.15
        cameraNode.camera?.wantsDepthOfField = false
        rootNode.addChildNode(cameraNode)
        updateCamera(snap: true)
    }

    // MARK: - Sky Dome (atmospheric gradient)

    private func buildSkyDome() {
        // Large inverted sphere with atmospheric gradient
        let skyGeo = SCNSphere(radius: 900)
        skyGeo.segmentCount = 48
        let skyMat = SCNMaterial()
        skyMat.lightingModel = .constant
        skyMat.isDoubleSided = true

        // Procedural atmospheric gradient texture
        let skyTex = generateSkyGradientTexture(size: 512)
        skyMat.diffuse.contents = skyTex
        skyMat.diffuse.wrapS = .clamp
        skyMat.diffuse.wrapT = .clamp
        skyGeo.materials = [skyMat]

        skyDomeNode = SCNNode(geometry: skyGeo)
        skyDomeNode?.renderingOrder = -10 // render first
        rootNode.addChildNode(skyDomeNode!)

        // Atmospheric fog
        fogStartDistance = 250
        fogEndDistance = 1200
        fogColor = NSColor(calibratedRed: 0.72, green: 0.85, blue: 0.95, alpha: 0.45)
        fogDensityExponent = 1.5
    }

    private func generateSkyGradientTexture(size: Int) -> NSImage {
        let img = NSImage(size: NSSize(width: size, height: size))
        img.lockFocus()
        for y in 0..<size {
            let t = CGFloat(y) / CGFloat(size) // 0 = bottom, 1 = top
            let r: CGFloat, g: CGFloat, b: CGFloat
            if t < 0.15 {
                // Horizon haze (warm orange-pink)
                let f = t / 0.15
                r = 0.95 - f * 0.35
                g = 0.78 - f * 0.15
                b = 0.70 + f * 0.15
            } else if t < 0.5 {
                // Lower sky (light blue)
                let f = (t - 0.15) / 0.35
                r = 0.60 - f * 0.25
                g = 0.63 + f * 0.17
                b = 0.85 + f * 0.10
            } else {
                // Upper sky (deep blue)
                let f = (t - 0.5) / 0.5
                r = 0.35 - f * 0.20
                g = 0.80 - f * 0.35
                b = 0.95 - f * 0.15
            }
            NSColor(calibratedRed: r, green: g, blue: b, alpha: 1).set()
            NSRect(x: 0, y: y, width: size, height: 1).fill()
        }
        img.unlockFocus()
        return img
    }

    // MARK: - Lighting (PBR + shadows)

    private func buildLighting() {
        // Primary sun — directional with cascaded shadows
        let sun = SCNNode()
        sun.light = SCNLight()
        sun.light?.type = .directional
        sun.light?.intensity = 1200
        sun.light?.color = NSColor(calibratedRed: 1.0, green: 0.96, blue: 0.88, alpha: 1)
        sun.light?.castsShadow = true
        sun.light?.shadowMode = .deferred
        sun.light?.shadowMapSize = CGSize(width: 2048, height: 2048)
        sun.light?.shadowCascadeCount = 3
        sun.light?.shadowCascadeSplittingFactor = 0.15
        sun.light?.shadowRadius = 3.0
        sun.light?.shadowSampleCount = 8
        sun.light?.shadowBias = 1.0
        sun.light?.maximumShadowDistance = 300
        sun.eulerAngles = SCNVector3(-0.6, 0.4, 0)
        sun.name = "sun-light"
        rootNode.addChildNode(sun)

        // Ambient fill (blueish sky bounce)
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 500
        ambient.light?.color = NSColor(calibratedRed: 0.65, green: 0.75, blue: 0.90, alpha: 1)
        rootNode.addChildNode(ambient)

        // Secondary fill light from below (ground bounce simulation)
        let bounce = SCNNode()
        bounce.light = SCNLight()
        bounce.light?.type = .directional
        bounce.light?.intensity = 150
        bounce.light?.color = NSColor(calibratedRed: 0.55, green: 0.7, blue: 0.5, alpha: 1) // greenish ground
        bounce.eulerAngles = SCNVector3(0.8, 0, 0) // upward
        rootNode.addChildNode(bounce)

        // Sun orb (visible sun with bloom)
        let sunBall = SCNNode(geometry: SCNSphere(radius: 25))
        sunBall.position = SCNVector3(400, 320, -600)
        let sunMat = SCNMaterial()
        sunMat.lightingModel = .constant
        sunMat.diffuse.contents = NSColor(calibratedRed: 1.0, green: 0.98, blue: 0.85, alpha: 1)
        sunMat.emission.contents = NSColor(calibratedRed: 1.0, green: 0.95, blue: 0.7, alpha: 1)
        sunBall.geometry?.materials = [sunMat]
        rootNode.addChildNode(sunBall)

        // Sun halo / glow ring
        let halo = SCNNode(geometry: SCNSphere(radius: 55))
        halo.position = sunBall.position
        let haloMat = SCNMaterial()
        haloMat.lightingModel = .constant
        haloMat.diffuse.contents = NSColor(calibratedRed: 1.0, green: 0.95, blue: 0.8, alpha: 0.15)
        haloMat.transparency = 0.15
        haloMat.isDoubleSided = true
        halo.geometry?.materials = [haloMat]
        rootNode.addChildNode(halo)

        // PBR environment lighting
        lightingEnvironment.contents = generateEnvironmentCubemap()
        lightingEnvironment.intensity = 1.0
    }

    private func generateEnvironmentCubemap() -> NSImage {
        // Simple sky-coloured cubemap face for PBR reflections
        let size = 64
        let img = NSImage(size: NSSize(width: size, height: size))
        img.lockFocus()
        for y in 0..<size {
            let t = CGFloat(y) / CGFloat(size)
            let r = 0.45 + t * 0.15
            let g = 0.65 + t * 0.15
            let b = 0.90 + t * 0.05
            NSColor(calibratedRed: r, green: g, blue: b, alpha: 1).set()
            NSRect(x: 0, y: y, width: size, height: 1).fill()
        }
        img.unlockFocus()
        return img
    }

    // MARK: - PBR Terrain Mesh with noise heightmap

    private func buildTerrain() {
        let segW = terrainGridSize - 1
        let segH = terrainGridSize - 1
        let cellSize = Float(terrainWorldSize) / Float(segW)

        // Build vertex data
        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var texCoords: [CGPoint] = []
        var indices: [UInt32] = []

        for z in 0..<terrainGridSize {
            for x in 0..<terrainGridSize {
                let wx = Float(x) * cellSize - Float(terrainWorldSize) / 2
                let wz = Float(z) * cellSize - Float(terrainWorldSize) / 2
                let wy = heightMap[z][x]
                vertices.append(SCNVector3(wx, wy, wz))
                texCoords.append(CGPoint(x: CGFloat(x) / CGFloat(segW), y: CGFloat(z) / CGFloat(segH)))
            }
        }

        // Compute face normals and smooth
        normals = Array(repeating: SCNVector3(0, 1, 0), count: vertices.count)

        // Build triangle indices
        for z in 0..<segH {
            for x in 0..<segW {
                let tl = UInt32(z * terrainGridSize + x)
                let tr = tl + 1
                let bl = tl + UInt32(terrainGridSize)
                let br = bl + 1
                indices.append(contentsOf: [tl, bl, tr, tr, bl, br])
            }
        }

        // Compute smooth normals from adjacency
        for z in 1..<(terrainGridSize - 1) {
            for x in 1..<(terrainGridSize - 1) {
                let idx = z * terrainGridSize + x
                let hL = heightMap[z][x - 1]
                let hR = heightMap[z][x + 1]
                let hD = heightMap[z - 1][x]
                let hU = heightMap[z + 1][x]
                let nx = (hL - hR) / (2.0 * cellSize)
                let nz = (hD - hU) / (2.0 * cellSize)
                let len = sqrt(nx * nx + 1.0 + nz * nz)
                normals[idx] = SCNVector3(nx / len, 1.0 / len, nz / len)
            }
        }

        let vertexSource = SCNGeometrySource(vertices: vertices)
        let normalSource = SCNGeometrySource(normals: normals)
        let texSource = SCNGeometrySource(textureCoordinates: texCoords)
        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)

        let geometry = SCNGeometry(sources: [vertexSource, normalSource, texSource], elements: [element])

        // PBR terrain material with biome-coloured diffuse texture
        let mat = SCNMaterial()
        mat.lightingModel = .physicallyBased
        mat.diffuse.contents = generateTerrainDiffuseTexture(size: 1024)
        mat.diffuse.wrapS = .clamp
        mat.diffuse.wrapT = .clamp
        mat.roughness.contents = generateTerrainRoughnessTexture(size: 512)
        mat.metalness.contents = NSColor.black // terrain is non-metallic
        mat.normal.contents = generateTerrainNormalTexture(size: 512)
        mat.normal.intensity = 0.8
        geometry.materials = [mat]

        let terrainNode = SCNNode(geometry: geometry)
        terrainNode.castsShadow = true
        rootNode.addChildNode(terrainNode)

        // Runway strip (on top of terrain)
        buildRunway()
    }

    private func generateTerrainDiffuseTexture(size: Int) -> NSImage {
        let img = NSImage(size: NSSize(width: size, height: size))
        img.lockFocus()
        // Re-use heightmap to colour by biome
        for py in 0..<size {
            for px in 0..<size {
                let gx = Int(CGFloat(px) / CGFloat(size) * CGFloat(terrainGridSize - 1))
                let gz = Int(CGFloat(py) / CGFloat(size) * CGFloat(terrainGridSize - 1))
                let h = heightMap[min(gz, terrainGridSize - 1)][min(gx, terrainGridSize - 1)]

                let color: NSColor
                if h < -8 {
                    // Deep ocean floor (dark blue-green) — won't be visible under water
                    color = NSColor(calibratedRed: 0.08, green: 0.15, blue: 0.25, alpha: 1)
                } else if h < -2 {
                    // Beach / sand
                    let t = (h + 8) / 6.0
                    color = NSColor(calibratedRed: CGFloat(0.88 + t * 0.05), green: CGFloat(0.82 + t * 0.02),
                                    blue: CGFloat(0.55 + t * 0.1), alpha: 1)
                } else if h < 8 {
                    // Lush grass / meadow
                    let t = (h + 2) / 10.0
                    let variation = sin(Float(px) * 0.3) * 0.05 + cos(Float(py) * 0.4) * 0.05
                    color = NSColor(calibratedRed: CGFloat(0.22 + variation), green: CGFloat(0.55 + t * 0.15 + variation),
                                    blue: CGFloat(0.18 + variation * 0.5), alpha: 1)
                } else if h < 25 {
                    // Forest / dark green with brown hints
                    let t = (h - 8) / 17.0
                    color = NSColor(calibratedRed: CGFloat(0.18 + t * 0.15), green: CGFloat(0.42 - t * 0.1),
                                    blue: CGFloat(0.12 + t * 0.05), alpha: 1)
                } else if h < 45 {
                    // Rock / grey-brown
                    let t = (h - 25) / 20.0
                    color = NSColor(calibratedRed: CGFloat(0.42 + t * 0.1), green: CGFloat(0.40 + t * 0.08),
                                    blue: CGFloat(0.35 + t * 0.1), alpha: 1)
                } else {
                    // Snow caps
                    let t = min(1.0, (h - 45) / 20.0)
                    color = NSColor(calibratedRed: CGFloat(0.85 + t * 0.12), green: CGFloat(0.88 + t * 0.10),
                                    blue: CGFloat(0.92 + t * 0.06), alpha: 1)
                }
                color.set()
                NSRect(x: px, y: py, width: 1, height: 1).fill()
            }
        }
        img.unlockFocus()
        return img
    }

    private func generateTerrainRoughnessTexture(size: Int) -> NSImage {
        let img = NSImage(size: NSSize(width: size, height: size))
        img.lockFocus()
        for py in 0..<size {
            for px in 0..<size {
                let gx = Int(CGFloat(px) / CGFloat(size) * CGFloat(terrainGridSize - 1))
                let gz = Int(CGFloat(py) / CGFloat(size) * CGFloat(terrainGridSize - 1))
                let h = heightMap[min(gz, terrainGridSize - 1)][min(gx, terrainGridSize - 1)]

                let roughness: CGFloat
                if h < -2 {
                    roughness = 0.3  // wet sand, shiny
                } else if h < 8 {
                    roughness = 0.85 // grass, matte
                } else if h < 25 {
                    roughness = 0.75 // forest
                } else if h < 45 {
                    roughness = 0.5  // rock, slightly shiny
                } else {
                    roughness = 0.4  // snow, slightly reflective
                }
                NSColor(white: roughness, alpha: 1).set()
                NSRect(x: px, y: py, width: 1, height: 1).fill()
            }
        }
        img.unlockFocus()
        return img
    }

    private func generateTerrainNormalTexture(size: Int) -> NSImage {
        // Compute normal map from heightmap gradients (tangent-space)
        let img = NSImage(size: NSSize(width: size, height: size))
        img.lockFocus()
        for py in 0..<size {
            for px in 0..<size {
                let gx = CGFloat(px) / CGFloat(size) * CGFloat(terrainGridSize - 1)
                let gz = CGFloat(py) / CGFloat(size) * CGFloat(terrainGridSize - 1)
                let ix = Int(gx), iz = Int(gz)

                let hC = heightMap[min(iz, terrainGridSize - 1)][min(ix, terrainGridSize - 1)]
                let hR = heightMap[min(iz, terrainGridSize - 1)][min(ix + 1, terrainGridSize - 1)]
                let hU = heightMap[min(iz + 1, terrainGridSize - 1)][min(ix, terrainGridSize - 1)]

                let dx = (hC - hR) * 2.0
                let dz = (hC - hU) * 2.0

                // Encode to RGB (tangent-space normal map: x → R, y → G, z → B)
                let r = CGFloat(dx * 0.5 + 0.5)
                let g = CGFloat(dz * 0.5 + 0.5)
                let b: CGFloat = 1.0  // z always up in tangent space
                NSColor(calibratedRed: r.clamped(to: 0...1), green: g.clamped(to: 0...1), blue: b, alpha: 1).set()
                NSRect(x: px, y: py, width: 1, height: 1).fill()
            }
        }
        img.unlockFocus()
        return img
    }

    // MARK: - Runway

    private func buildRunway() {
        // Asphalt runway with PBR surface
        let runwayLength: CGFloat = 250
        let runwayWidth: CGFloat = 8
        let runway = SCNNode(geometry: SCNPlane(width: runwayLength, height: runwayWidth))
        runway.position = SCNVector3(0, 0.5, 0)
        runway.eulerAngles = SCNVector3(-CGFloat.pi / 2, 0, 0)

        let runwayMat = SCNMaterial()
        runwayMat.lightingModel = .physicallyBased
        runwayMat.diffuse.contents = NSColor(calibratedRed: 0.15, green: 0.15, blue: 0.16, alpha: 1) // dark asphalt
        runwayMat.roughness.contents = NSNumber(value: 0.65)
        runwayMat.metalness.contents = NSNumber(value: 0.0)
        runway.geometry?.materials = [runwayMat]
        rootNode.addChildNode(runway)

        // Centre line markings
        for i in 0..<20 {
            let line = SCNNode(geometry: SCNPlane(width: 8, height: 0.4))
            line.position = SCNVector3(CGFloat(i) * 12 - 120, 0.55, 0)
            line.eulerAngles = SCNVector3(-CGFloat.pi / 2, 0, 0)
            let lineMat = SCNMaterial()
            lineMat.lightingModel = .physicallyBased
            lineMat.diffuse.contents = NSColor.white
            lineMat.roughness.contents = NSNumber(value: 0.9)
            line.geometry?.materials = [lineMat]
            rootNode.addChildNode(line)
        }

        // Threshold markings
        for side in [-1, 1] as [CGFloat] {
            for i in 0..<4 {
                let mark = SCNNode(geometry: SCNPlane(width: 1.5, height: 0.5))
                mark.position = SCNVector3(-runwayLength / 2 + 3, 0.55, side * (CGFloat(i) + 1) * 0.8)
                mark.eulerAngles = SCNVector3(-CGFloat.pi / 2, 0, 0)
                mark.geometry?.firstMaterial?.lightingModel = .physicallyBased
                mark.geometry?.firstMaterial?.diffuse.contents = NSColor.white
                mark.geometry?.firstMaterial?.roughness.contents = NSNumber(value: 0.9)
                rootNode.addChildNode(mark)
            }
        }

        // Runway edge lights (orange glow points)
        for i in stride(from: -runwayLength / 2, through: runwayLength / 2, by: 15) {
            for side in [-1, 1] as [CGFloat] {
                let light = SCNNode(geometry: SCNSphere(radius: 0.2))
                light.position = SCNVector3(i, 0.6, side * (runwayWidth / 2 + 0.5))
                let lightMat = SCNMaterial()
                lightMat.lightingModel = .constant
                lightMat.diffuse.contents = NSColor.orange
                lightMat.emission.contents = NSColor(calibratedRed: 1.0, green: 0.7, blue: 0.2, alpha: 1)
                light.geometry?.materials = [lightMat]
                rootNode.addChildNode(light)
            }
        }
    }

    // MARK: - Animated Ocean

    private func buildOcean() {
        let oceanSize: CGFloat = 1200
        let segments = 80
        let oceanGeo = SCNPlane(width: oceanSize, height: oceanSize)
        oceanGeo.widthSegmentCount = segments
        oceanGeo.heightSegmentCount = segments

        let waterMat = SCNMaterial()
        waterMat.lightingModel = .physicallyBased
        // Deep ocean blue with transparency
        waterMat.diffuse.contents = NSColor(calibratedRed: 0.05, green: 0.22, blue: 0.42, alpha: 0.88)
        waterMat.roughness.contents = NSNumber(value: 0.08) // very smooth / reflective
        waterMat.metalness.contents = NSNumber(value: 0.02)
        waterMat.transparency = 0.88
        waterMat.transparencyMode = .dualLayer
        waterMat.isDoubleSided = true
        waterMat.fresnelExponent = 3.0 // strong Fresnel reflection at grazing angles

        // Animated wave normal perturbation via shader modifier
        let waveShader = """
        #pragma arguments
        float time;

        #pragma body
        // Gerstner-style animated wave normals
        float2 uv = _surface.diffuseTexcoord;
        float t = scn_frame.time;

        // Multi-octave wave simulation
        float wave1 = sin(uv.x * 40.0 + t * 1.5) * cos(uv.y * 30.0 + t * 0.8) * 0.15;
        float wave2 = sin(uv.x * 80.0 - t * 2.0) * cos(uv.y * 60.0 + t * 1.2) * 0.08;
        float wave3 = sin(uv.x * 20.0 + t * 0.5) * cos(uv.y * 15.0 - t * 0.3) * 0.20;

        float waveHeight = wave1 + wave2 + wave3;

        // Perturb the normal based on wave derivatives
        float dWdx = cos(uv.x * 40.0 + t * 1.5) * cos(uv.y * 30.0 + t * 0.8) * 40.0 * 0.15
                   + cos(uv.x * 80.0 - t * 2.0) * cos(uv.y * 60.0 + t * 1.2) * 80.0 * 0.08;
        float dWdy = -sin(uv.x * 40.0 + t * 1.5) * sin(uv.y * 30.0 + t * 0.8) * 30.0 * 0.15
                   - sin(uv.x * 80.0 - t * 2.0) * sin(uv.y * 60.0 + t * 1.2) * 60.0 * 0.08;

        _surface.normal = normalize(float3(-dWdx * 0.3, 1.0, -dWdy * 0.3));

        // Depth-tinted colour: darker at centre (deep), lighter at edges (shallow feel)
        float depth = length(uv - float2(0.5)) * 2.0;
        float3 deepColor = float3(0.02, 0.12, 0.32);
        float3 shallowColor = float3(0.15, 0.55, 0.65);
        _surface.diffuse.rgb = mix(deepColor, shallowColor, clamp(depth, 0.0, 1.0));

        // Sun specular sparkle enhancement
        _surface.roughness = 0.05 + waveHeight * 0.15;
        """

        waterMat.shaderModifiers = [.surface: waveShader]
        oceanGeo.materials = [waterMat]

        oceanNode = SCNNode(geometry: oceanGeo)
        oceanNode?.position = SCNVector3(0, -3, 0) // sea level
        oceanNode?.eulerAngles = SCNVector3(-CGFloat.pi / 2, 0, 0)
        oceanNode?.castsShadow = false
        rootNode.addChildNode(oceanNode!)
    }

    // MARK: - Volumetric Clouds

    private func buildClouds() {
        // Multiple cloud layers at different altitudes
        let layers: [(altRange: ClosedRange<CGFloat>, count: Int, sizeRange: ClosedRange<CGFloat>, opacity: CGFloat)] = [
            (60...120, 24, 20...50, 0.92),    // Low cumulus
            (130...200, 18, 40...80, 0.85),    // Mid-level
            (220...320, 12, 60...120, 0.70),   // High cirrus-like
        ]

        for layer in layers {
            for _ in 0..<layer.count {
                let cloud = makeRealisticCloud(
                    size: CGFloat.random(in: layer.sizeRange),
                    opacity: layer.opacity
                )
                cloud.position = SCNVector3(
                    CGFloat.random(in: -500...500),
                    CGFloat.random(in: layer.altRange),
                    CGFloat.random(in: -500...500)
                )
                rootNode.addChildNode(cloud)
                cloudNodes.append(cloud)
            }
        }
    }

    private func makeRealisticCloud(size: CGFloat, opacity: CGFloat) -> SCNNode {
        let cloud = SCNNode()
        // Build cloud from multiple overlapping spheres with varying sizes (volumetric feel)
        let puffCount = Int.random(in: 18...35)
        let baseWidth = size * 0.8
        let baseHeight = size * 0.25

        for i in 0..<puffCount {
            let puffRadius = CGFloat.random(in: size * 0.12...size * 0.30)
            let puff = SCNNode(geometry: SCNSphere(radius: puffRadius))
            puff.position = SCNVector3(
                CGFloat.random(in: -baseWidth / 2...baseWidth / 2),
                CGFloat.random(in: -baseHeight / 2...baseHeight / 2),
                CGFloat.random(in: -baseWidth / 3...baseWidth / 3)
            )

            let mat = SCNMaterial()
            mat.lightingModel = .physicallyBased

            // Cloud colour varies: brighter on top (sun-lit), darker underneath (self-shadow)
            let heightFraction = (puff.position.y + baseHeight / 2) / baseHeight
            let brightness = 0.75 + heightFraction * 0.25

            mat.diffuse.contents = NSColor(calibratedWhite: brightness, alpha: 1)
            mat.roughness.contents = NSNumber(value: 0.95)
            mat.metalness.contents = NSNumber(value: 0.0)
            mat.transparency = opacity * CGFloat.random(in: 0.7...1.0)
            mat.transparencyMode = .dualLayer

            // Edge softening — make edges fade
            if i > puffCount / 2 {
                mat.transparency *= 0.7 // outer puffs are more transparent
            }

            puff.geometry?.materials = [mat]
            puff.castsShadow = false
            cloud.addChildNode(puff)
        }

        // Slow drift animation
        let drift = SCNAction.moveBy(
            x: CGFloat.random(in: -8...8),
            y: CGFloat.random(in: -1...1),
            z: CGFloat.random(in: -8...8),
            duration: TimeInterval.random(in: 15...30)
        )
        cloud.runAction(.repeatForever(.sequence([drift, drift.reversed()])))
        cloud.castsShadow = false

        return cloud
    }

    // MARK: - Environment (trees, buildings, details)

    private func buildEnvironment() {
        // Islands with detailed vegetation
        let islandPositions: [(Float, Float)] = [(-150, -200), (200, -150), (-180, 200), (180, 180), (0, -300)]
        for (ix, iz) in islandPositions {
            buildIsland(at: SCNVector3(CGFloat(ix), CGFloat(sampleHeight(worldX: CGFloat(ix), worldZ: CGFloat(iz))), CGFloat(iz)))
        }

        // Scattered vegetation across green areas
        for _ in 0..<60 {
            let x = CGFloat.random(in: -350...350)
            let z = CGFloat.random(in: -350...350)
            let h = sampleHeight(worldX: x, worldZ: z)
            if h > 0 && h < 20 { // Only on grass/forest biome
                let tree = makeRealisticTree()
                tree.position = SCNVector3(x, h, z)
                rootNode.addChildNode(tree)
            }
        }

        // Simple buildings near runway
        for i in 0..<4 {
            let building = makeBuilding()
            building.position = SCNVector3(CGFloat.random(in: -80...80), 0.5, CGFloat(i * 20) - 40 + (i % 2 == 0 ? -15 : 15))
            rootNode.addChildNode(building)
        }
    }

    private func buildIsland(at position: SCNVector3) {
        // Palm trees on island
        for _ in 0..<6 {
            let palm = makeRealisticPalmTree()
            palm.position = SCNVector3(
                position.x + CGFloat.random(in: -25...25),
                position.y + 2,
                position.z + CGFloat.random(in: -25...25)
            )
            rootNode.addChildNode(palm)
        }
    }

    private func makeRealisticTree() -> SCNNode {
        let tree = SCNNode()

        // Trunk with PBR bark
        let trunkHeight: CGFloat = CGFloat.random(in: 3...7)
        let trunk = SCNNode(geometry: SCNCylinder(radius: CGFloat.random(in: 0.3...0.6), height: trunkHeight))
        trunk.position = SCNVector3(0, trunkHeight / 2, 0)
        let barkMat = SCNMaterial()
        barkMat.lightingModel = .physicallyBased
        barkMat.diffuse.contents = NSColor(calibratedRed: 0.35, green: 0.22, blue: 0.12, alpha: 1)
        barkMat.roughness.contents = NSNumber(value: 0.9)
        barkMat.metalness.contents = NSNumber(value: 0.0)
        trunk.geometry?.materials = [barkMat]
        trunk.castsShadow = true
        tree.addChildNode(trunk)

        // Foliage (cluster of spheres)
        let foliageColors: [NSColor] = [
            NSColor(calibratedRed: 0.15, green: 0.50, blue: 0.18, alpha: 1),
            NSColor(calibratedRed: 0.20, green: 0.58, blue: 0.22, alpha: 1),
            NSColor(calibratedRed: 0.12, green: 0.42, blue: 0.15, alpha: 1),
        ]
        for _ in 0..<Int.random(in: 3...5) {
            let leaf = SCNNode(geometry: SCNSphere(radius: CGFloat.random(in: 1.2...2.5)))
            leaf.position = SCNVector3(
                CGFloat.random(in: -1.5...1.5),
                trunkHeight + CGFloat.random(in: 0...2),
                CGFloat.random(in: -1.5...1.5)
            )
            let leafMat = SCNMaterial()
            leafMat.lightingModel = .physicallyBased
            leafMat.diffuse.contents = foliageColors.randomElement()!
            leafMat.roughness.contents = NSNumber(value: 0.85)
            leafMat.metalness.contents = NSNumber(value: 0.0)
            leaf.geometry?.materials = [leafMat]
            leaf.castsShadow = true
            tree.addChildNode(leaf)
        }

        return tree
    }

    private func makeRealisticPalmTree() -> SCNNode {
        let palm = SCNNode()

        // Curved trunk
        let trunkH: CGFloat = CGFloat.random(in: 6...10)
        let trunk = SCNNode(geometry: SCNCylinder(radius: 0.5, height: trunkH))
        trunk.position = SCNVector3(0, trunkH / 2, 0)
        let trunkMat = SCNMaterial()
        trunkMat.lightingModel = .physicallyBased
        trunkMat.diffuse.contents = NSColor(calibratedRed: 0.50, green: 0.35, blue: 0.20, alpha: 1)
        trunkMat.roughness.contents = NSNumber(value: 0.92)
        trunk.geometry?.materials = [trunkMat]
        trunk.castsShadow = true
        palm.addChildNode(trunk)

        // Palm fronds (elongated spheres)
        for _ in 0..<5 {
            let frond = SCNNode(geometry: SCNSphere(radius: 2.0))
            frond.scale = SCNVector3(1.0, 0.3, 2.5) // flatten + elongate
            frond.position = SCNVector3(
                CGFloat.random(in: -2...2),
                trunkH + CGFloat.random(in: -0.5...0.5),
                CGFloat.random(in: -2...2)
            )
            frond.eulerAngles = SCNVector3(
                CGFloat.random(in: -0.5...0.5),
                CGFloat.random(in: 0...CGFloat.pi * 2),
                CGFloat.random(in: -0.3...0.3)
            )
            let frondMat = SCNMaterial()
            frondMat.lightingModel = .physicallyBased
            frondMat.diffuse.contents = NSColor(calibratedRed: 0.18, green: 0.55, blue: 0.22, alpha: 1)
            frondMat.roughness.contents = NSNumber(value: 0.8)
            frond.geometry?.materials = [frondMat]
            frond.castsShadow = true
            palm.addChildNode(frond)
        }

        // Coconut cluster
        for _ in 0..<3 {
            let coconut = SCNNode(geometry: SCNSphere(radius: 0.3))
            coconut.position = SCNVector3(CGFloat.random(in: -0.5...0.5), trunkH - 0.3, CGFloat.random(in: -0.5...0.5))
            let cocoMat = SCNMaterial()
            cocoMat.lightingModel = .physicallyBased
            cocoMat.diffuse.contents = NSColor(calibratedRed: 0.45, green: 0.30, blue: 0.15, alpha: 1)
            cocoMat.roughness.contents = NSNumber(value: 0.7)
            coconut.geometry?.materials = [cocoMat]
            palm.addChildNode(coconut)
        }

        return palm
    }

    private func makeBuilding() -> SCNNode {
        let building = SCNNode()
        let w = CGFloat.random(in: 4...8)
        let h = CGFloat.random(in: 3...6)
        let d = CGFloat.random(in: 4...8)

        let box = SCNNode(geometry: SCNBox(width: w, height: h, length: d, chamferRadius: 0.1))
        box.position = SCNVector3(0, h / 2, 0)
        let wallMat = SCNMaterial()
        wallMat.lightingModel = .physicallyBased
        wallMat.diffuse.contents = NSColor(calibratedRed: CGFloat.random(in: 0.7...0.9),
                                            green: CGFloat.random(in: 0.7...0.85),
                                            blue: CGFloat.random(in: 0.65...0.8), alpha: 1)
        wallMat.roughness.contents = NSNumber(value: 0.7)
        box.geometry?.materials = [wallMat]
        box.castsShadow = true
        building.addChildNode(box)

        // Roof
        let roof = SCNNode(geometry: SCNBox(width: w + 0.5, height: 0.3, length: d + 0.5, chamferRadius: 0.05))
        roof.position = SCNVector3(0, h + 0.15, 0)
        let roofMat = SCNMaterial()
        roofMat.lightingModel = .physicallyBased
        roofMat.diffuse.contents = NSColor(calibratedRed: 0.55, green: 0.25, blue: 0.18, alpha: 1)
        roofMat.roughness.contents = NSNumber(value: 0.6)
        roof.geometry?.materials = [roofMat]
        roof.castsShadow = true
        building.addChildNode(roof)

        return building
    }

    private func makeTargetBalloon() -> SCNNode {
        let n = SCNNode()
        let body = SCNNode(geometry: SCNSphere(radius: 1.6))
        body.position = SCNVector3(0, 2, 0)
        let balloonMat = SCNMaterial()
        balloonMat.lightingModel = .physicallyBased
        balloonMat.diffuse.contents = NSColor(calibratedRed: 0.9, green: 0.25, blue: 0.2, alpha: 1)
        balloonMat.roughness.contents = NSNumber(value: 0.3) // shiny rubber
        balloonMat.metalness.contents = NSNumber(value: 0.05)
        body.geometry?.materials = [balloonMat]
        body.castsShadow = true
        n.addChildNode(body)

        let string = SCNNode(geometry: SCNCylinder(radius: 0.06, height: 5))
        string.position = SCNVector3(0, -3.5, 0)
        let stringMat = SCNMaterial()
        stringMat.lightingModel = .physicallyBased
        stringMat.diffuse.contents = NSColor.gray
        stringMat.roughness.contents = NSNumber(value: 0.8)
        string.geometry?.materials = [stringMat]
        n.addChildNode(string)

        // Rise animation
        let up = SCNAction.moveBy(x: 0, y: 1, z: 0, duration: 3.0)
        n.runAction(.repeatForever(.sequence([up, up.reversed()])))

        return n
    }

    // MARK: - Per-frame realistic flight physics

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime t: TimeInterval) {
        let dt: CGFloat = 1.0 / 60.0
        time = t

        // --- Input-derived controls ---
        let boosting = boostHeld
        let steerX = CGFloat(mouseSteer.dx) * CGFloat(sensitivity) * CGFloat(plane.turnSpeed)  // roll/yaw input
        let steerY = CGFloat(-mouseSteer.dy) * CGFloat(sensitivity)                          // pitch input

        // --- Aerodynamic flight physics ---

        // 1. Angle of attack from pitch + sideslip (AoA = pitch - sideslip offset)
        angleOfAttack = steerY * 0.8 - sideSlip * 0.5

        // 2. Lift generation (parabolic polar curve, stall at high AoA)
        let maxLift = 25.0
        let liftCurve: CGFloat = -0.15 * angleOfAttack * angleOfAttack + 0.8 * angleOfAttack
        let lift = maxLift * Swift.min(1, Swift.max(-1, liftCurve)) * (airspeed / 30.0)   // lift approx ∝ v²

        // 3. Drag (parabolic — scales with speed²)
        let dragCoeff = 0.02 * (airspeed / 30.0)
        let dragForce = -airspeed * dragCoeff * airspeed

        // 4. Thrust / engine (boost adds power)
        let baseThrust = CGFloat(plane.topSpeed) * 0.15
        let thrust = boosting ? baseThrust * 1.8 : baseThrust

        // 5. Weight / gravity (downward force)
        let gravity = 25.0 * (1.0 + 0.01 * (airspeed / 30.0))

        // 6. Net vertical motion: lift opposes gravity, thrust has vertical component from pitch
        let netLift = lift - gravity
        verticalSpeed += (netLift / 10.0) * dt   // vertical acceleration

        // 7. Horizontal speed: thrust vs drag, clamped per plane
        let speedAccel = (thrust + dragForce) / 10.0
        airspeed += speedAccel * dt
        // clamp airspeed: won't drop below stall, won't exceed never-exceed in boost
        airspeed = max(stallSpeed, min(60.0, airspeed))

        // 8. Heading change from roll (banked turn) + rudder (sideslip coordination)
        //    real planes turn via bank: turn rate ∝ sin(bank) * airspeed
        let turnFromBank = Double(sin(bank)) * Double(airspeed) * 0.008
        let turnFromRudder = Double(steerX) * Double(plane.turnSpeed) * 0.4
        let turnRate = turnFromBank + turnFromRudder
        heading -= CGFloat(turnRate) * dt

        // 9. Sideslip from rudder input (coordination ball idea)
        sideSlip = steerX * 0.3  // simple model: rudder cancels sideslip over time
        sideSlip *= 0.9 * dt     // damping

        // 10. Bank from aileron (mouse left/right)
        bank = steerX * 0.5   // radians, clamped by physics below
        bank = max(-CGFloat.pi / 4, min(CGFloat.pi / 4, bank))  // max 45° bank

        // 11. Ground collision with height terrain + ground effect
        let groundHeight = sampleHeight(worldX: CGFloat(planeNode.position.x), worldZ: CGFloat(planeNode.position.z))
        let stepY = verticalSpeed * dt

        // ground effect cushion when very low (reduces sink rate near ground)
        let cushion: CGFloat = max(0, 10 - altitude) * 0.1

        altitude = max(groundHeight, altitude + stepY - cushion)
        verticalSpeed = altitude - groundHeight // keep consistent

        // If we sink too low, auto-climb (soft landing assist for kids)
        if altitude < groundHeight + 2 {
            verticalSpeed = max(verticalSpeed, -0.5) // don't slam down
            altitude = groundHeight + 2
        }

        // Climb/descent limits
        verticalSpeed = max(-8, min(8, verticalSpeed))

        // 12. Position update using airspeed, heading, bank
        let stepX = sin(heading) * cos(bank) * airspeed * dt
        let stepZ = -cos(heading) * cos(bank) * airspeed * dt
        planeNode.position.x += stepX
        planeNode.position.y += stepY
        planeNode.position.z += stepZ

        // World bounds wrap (infinite flight area)
        if planeNode.position.x > 400 { planeNode.position.x -= 800 }
        if planeNode.position.x < -400 { planeNode.position.x += 800 }
        if planeNode.position.z > 400 { planeNode.position.z -= 800 }
        if planeNode.position.z < -400 { planeNode.position.z += 800 }

        // 13. Propeller + boost effects
        PlaneFactory.spinPropeller(planeNode, delta: dt * (boosting ? 2.5 : 1.5))
        PlaneFactory.setBoost(planeNode, on: boosting)

        // 14. Cloud interaction (enter cloud = slight speed reduction + visibility hint)
        for c in cloudNodes where !c.isHidden {
            let dist = planeNode.position.distance(to: c.position)
            if dist < 50 {
                airspeed = max(stallSpeed, airspeed - 0.3 * dt)
            }
        }

        // 15. Target practice: hit balloons
        for t in targetNodes where !t.isHidden {
            let dist = planeNode.position.distance(to: t.position)
            if dist < 5 {
                t.isHidden = true
                DispatchQueue.main.async { self.onTargetHit?(t.position.x, t.position.z) }
                DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                    t.position = SCNVector3(CGFloat.random(in: -300...300), CGFloat.random(in: 30...100), CGFloat.random(in: -300...300))
                    t.isHidden = false
                }
            }
        }

        // 16. Sky dome follows camera (keeps sky infinite)
        skyDomeNode?.position = SCNVector3(planeNode.position.x, 0, planeNode.position.z)

        // 17. Ocean follows camera (infinite water)
        oceanNode?.position = SCNVector3(planeNode.position.x, -3, planeNode.position.z)

        // 18. Altitude-adaptive fog (thinner at high altitude)
        let altFactor = min(1.0, altitude / 300.0)
        fogStartDistance = 250 + altFactor * 500
        fogEndDistance = 1200 + altFactor * 1000

        // 19. Update camera (chaser behind + above, smooth follow)
        updateCamera(snap: false)

        // 20. Stats telemetry to UI
        let alt = Int(max(0, altitude))
        let hdg = -heading * 180 / CGFloat.pi
        let hdgNorm = hdg.truncatingRemainder(dividingBy: 360)
        let pitchDeg = angleOfAttack * 180 / CGFloat.pi
        let bankDeg = bank * 180 / CGFloat.pi
        DispatchQueue.main.async {
            self.onStats?(CGFloat(alt), self.verticalSpeed, self.airspeed, hdgNorm, boosting, pitchDeg, bankDeg)
        }
    }

    // Simple ground height query (height at given x,z — terrain graph)
    private func groundHeight(at point: (x: CGFloat, z: CGFloat)) -> CGFloat {
        return sampleHeight(worldX: point.x, worldZ: point.z)
    }

    // MARK: - Camera (flight-sim quality chase cam)
    private func updateCamera(snap: Bool) {
        let back: CGFloat = 14, up: CGFloat = 5.5
        let cx = planeNode.position.x + sin(heading) * back
        let cz = planeNode.position.z + cos(heading) * back
        let cy = planeNode.position.y + up
        var target = SCNVector3(cx, cy, cz)

        // Speed-dependent camera shake (turbulence feel)
        if airspeed > 35 {
            let intensity = (airspeed - 35) * 0.003
            target.x += CGFloat.random(in: -intensity...intensity)
            target.y += CGFloat.random(in: -intensity...intensity)
            target.z += CGFloat.random(in: -intensity...intensity)
        }

        if snap { cameraNode.position = target }
        else { cameraNode.position = cameraNode.position.lerp(to: target, t: 0.06) }

        // Camera always looks at plane, slightly below
        let look = SCNVector3(planeNode.position.x - sin(heading) * 15,
                              planeNode.position.y - 2,
                              planeNode.position.z - cos(heading) * 15)
        cameraNode.look(at: look)

        // Dynamic FOV: wider at high speed (zoom effect)
        let fovBase: CGFloat = 55
        let speedFactor = min(15, (airspeed - 20) * 0.5)
        cameraNode.camera?.fieldOfView = fovBase + speedFactor
    }
}

// MARK: - Extensions

private extension SCNVector3 {
    func distance(to other: SCNVector3) -> CGFloat {
        let dx = x - other.x, dy = y - other.y, dz = z - other.z
        return sqrt(dx * dx + dy * dy + dz * dz)
    }
    var xz: (CGFloat, CGFloat) { (x, z) }
    func lerp(to other: SCNVector3, t: CGFloat) -> SCNVector3 {
        SCNVector3(x + (other.x - x) * t, y + (other.y - y) * t, z + (other.z - z) * t)
    }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

private extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}