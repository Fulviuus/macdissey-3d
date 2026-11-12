import Foundation
import simd

/// Immutable geometry uploaded once. Dimensions are metres in display space;
/// animated sculptures rotate around their centres without moving the camera.
struct GalleryVertex {
  var position: SIMD4<Float>
  var normal: SIMD4<Float>
  var surface: SIMD4<Float>
  var object: SIMD4<Float>
}

enum GalleryScene {
  static func vertices() -> [GalleryVertex] {
    var mesh = GalleryMesh()
    // A shallow architectural display case, with a tiled floor, recessed wall
    // panels, columns, lintel and a frame at the physical screen plane.
    mesh.box(
      center: SIMD3(0, -0.121, -0.028), half: SIMD3(0.30, 0.006, 0.065), grey: 0.47, material: 1)
    mesh.box(
      center: SIMD3(0, 0.014, -0.078), half: SIMD3(0.30, 0.135, 0.004), grey: 0.49, material: 2)
    for x: Float in [-0.24, -0.12, 0, 0.12, 0.24] {
      mesh.box(center: SIMD3(x, 0.020, -0.071), half: SIMD3(0.052, 0.090, 0.002), grey: 0.40)
      mesh.box(center: SIMD3(x, 0.021, -0.068), half: SIMD3(0.046, 0.083, 0.001), grey: 0.45)
    }
    for x: Float in [-0.262, 0.262] {
      mesh.box(center: SIMD3(x, -0.010, -0.035), half: SIMD3(0.012, 0.105, 0.022), grey: 0.59)
      mesh.box(center: SIMD3(x, -0.108, -0.035), half: SIMD3(0.021, 0.007, 0.028), grey: 0.51)
      mesh.box(center: SIMD3(x, 0.097, -0.035), half: SIMD3(0.021, 0.007, 0.028), grey: 0.61)
    }
    mesh.box(center: SIMD3(0, 0.115, -0.035), half: SIMD3(0.283, 0.011, 0.028), grey: 0.56)
    for x: Float in [-0.295, 0.295] {
      mesh.box(center: SIMD3(x, 0, 0), half: SIMD3(0.005, 0.155, 0.005), grey: 0.37)
    }
    for y: Float in [-0.15, 0.15] {
      mesh.box(center: SIMD3(0, y, 0), half: SIMD3(0.30, 0.005, 0.005), grey: 0.37)
    }
    // Pedestals and varied silhouettes give occlusion, surface and depth cues
    // beyond the original cubes. No textures, asset downloads or per-frame mesh copies.
    for x: Float in [-0.15, 0, 0.15] {
      mesh.box(center: SIMD3(x, -0.096, -0.005), half: SIMD3(0.041, 0.019, 0.031), grey: 0.50)
      mesh.box(center: SIMD3(x, -0.075, -0.005), half: SIMD3(0.045, 0.003, 0.034), grey: 0.63)
    }
    mesh.sphere(center: SIMD3(-0.15, -0.039, 0.002), radius: 0.033, grey: 0.68)
    mesh.torus(
      center: SIMD3(0, -0.016, -0.004), radius: 0.047, tube: 0.006, grey: 0.64, speed: 0.35)
    mesh.torus(
      center: SIMD3(0, -0.016, -0.004), radius: 0.033, tube: 0.004, grey: 0.44, speed: -0.5,
      tilt: 0.9)
    mesh.sphere(center: SIMD3(0, -0.016, -0.004), radius: 0.012, grey: 0.68)
    mesh.torus(
      center: SIMD3(0.15, -0.032, 0.002), radius: 0.027, tube: 0.009, grey: 0.55, speed: -0.28,
      tilt: 0.35)
    mesh.sphere(center: SIMD3(0.15, 0.026, -0.018), radius: 0.013, grey: 0.65)
    // A fine hanging bar connects the floating ball to the gallery ceiling.
    mesh.box(center: SIMD3(0.15, 0.068, -0.018), half: SIMD3(0.001, 0.030, 0.001), grey: 0.36)
    return mesh.vertices
  }

  // U is shared with the diagnostic/cube shaders. Neutral device
  // greys respect the existing demo colour contract without guessing an ICC transform.
  static let shader = """
    struct GalleryVertex { float4 position, normal, surface, object; };
    struct GalleryV {
      float4 position [[position]];
      float3 world, normal;
      float4 surface;
    };
    float3 galleryRotate(float3 p, float angle) {
      float c=cos(angle),s=sin(angle);
      return float3(c*p.x+s*p.z,p.y,-s*p.x+c*p.z);
    }
    vertex GalleryV gallery(uint id [[vertex_id]], constant U& u [[buffer(0)]],
                           const device GalleryVertex* vertices [[buffer(1)]]) {
      GalleryVertex v=vertices[id];
      float angle=u.screenAndTime.z*v.object.w;
      float3 p=galleryRotate(v.position.xyz,angle)+v.object.xyz;
      float w=u.eye.z-p.z;
      float2 projected=(p.xy*u.eye.z-u.eye.xy*p.z)*2.0/u.screenAndTime.xy;
      GalleryV out;
      out.position=float4(projected,w*10.0/9.99-0.1/9.99,w);
      out.world=p; out.normal=galleryRotate(v.normal.xyz,angle); out.surface=v.surface;
      return out;
    }
    float galleryShadow(float3 p,float3 centre,float radius,float3 light) {
      float2 footprint=centre.xz-light.xz*(centre.y-p.y)/light.y;
      float2 delta=p.xz-footprint;
      return exp(-dot(delta,delta)/(radius*radius));
    }
    fragment float4 galleryShade(GalleryV v [[stage_in]],constant U& u [[buffer(0)]]) {
      float3 n=normalize(v.normal),view=normalize(u.eye.xyz-v.world);
      float3 light=normalize(float3(-0.45,0.85,0.6));
      float base=v.surface.x;
      uint material=uint(v.surface.w);
      float shadow=1.0;
      if (material==1 && n.y>0.5) {
        float2 tile=v.world.xz/0.036;
        float2 aa=max(fwidth(tile),float2(0.001));
        float2 edge=min(fract(tile),1.0-fract(tile));
        float grout=1.0-min(smoothstep(0.015-aa,0.015+aa,edge).x,
                            smoothstep(0.015-aa,0.015+aa,edge).y);
        float checker=fmod(abs(floor(tile.x)+floor(tile.y)),2.0);
        base=(base+0.035*checker)*(1.0-0.16*grout);
        // Analytic soft contact shadows on the floor; no full-screen ray march
        // or additional image transport is needed for this diagnostic scene.
        float shade=galleryShadow(v.world,float3(-0.15,-0.04,0.002),0.034,light)
                   +galleryShadow(v.world,float3(0,-0.02,-0.004),0.043,light)
                   +galleryShadow(v.world,float3(0.15,-0.03,0.002),0.035,light);
        shadow=1.0-0.30*clamp(shade,0.0,1.0);
      }
      float diffuse=max(dot(n,light),0.0);
      float ambient=0.18+0.10*(n.y*0.5+0.5);
      float gloss=material==3 ? 80.0 : 28.0;
      float specular=pow(max(dot(n,normalize(light+view)),0.0),gloss);
      float value=base*(ambient+0.72*diffuse)*shadow+specular*(material==3 ? 0.23 : 0.06);
      // Avoid stark white-on-black silhouettes while retaining material detail.
      return float4(float3(clamp(value,0.075,0.80)),1);
    }
    """
}

private struct GalleryMesh {
  var vertices: [GalleryVertex] = []

  mutating func triangle(
    _ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>,
    normals: [SIMD3<Float>]? = nil, grey: Float, material: Float,
    center: SIMD3<Float> = .zero, speed: Float = 0
  ) {
    let face = simd_normalize(simd_cross(b - a, c - a))
    for (i, p) in [a, b, c].enumerated() {
      vertices.append(
        GalleryVertex(
          position: SIMD4(p, 1), normal: SIMD4(normals?[i] ?? face, 0),
          surface: SIMD4(grey, grey, grey, material), object: SIMD4(center, speed)))
    }
  }

  mutating func box(center: SIMD3<Float>, half: SIMD3<Float>, grey: Float, material: Float = 0) {
    let points: [SIMD3<Float>] = [
      SIMD3(-1, -1, -1), SIMD3(1, -1, -1), SIMD3(1, 1, -1), SIMD3(-1, 1, -1),
      SIMD3(-1, -1, 1), SIMD3(1, -1, 1), SIMD3(1, 1, 1), SIMD3(-1, 1, 1),
    ].map { $0 * half }
    for face in [
      [0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [3, 7, 6, 2], [0, 4, 7, 3], [1, 2, 6, 5],
    ] {
      for t in [[0, 1, 2], [0, 2, 3]] {
        triangle(
          points[face[t[0]]], points[face[t[1]]], points[face[t[2]]], grey: grey,
          material: material, center: center)
      }
    }
  }

  mutating func sphere(center: SIMD3<Float>, radius: Float, grey: Float) {
    func normal(_ x: Int, _ y: Int) -> SIMD3<Float> {
      let longitude = Float(x) * 2 * .pi / 40
      let latitude = Float(y) * .pi / 24
      return SIMD3(sin(latitude) * cos(longitude), cos(latitude), sin(latitude) * sin(longitude))
    }
    for y in 0..<24 {
      for x in 0..<40 {
        let n = [normal(x, y), normal(x + 1, y), normal(x + 1, y + 1), normal(x, y + 1)]
        for t in [[0, 1, 2], [0, 2, 3]] {
          // Skip degenerate triangles at the two poles.
          if (y == 0 && t[1] == 1) || (y == 23 && t[2] == 3) { continue }
          triangle(
            n[t[0]] * radius, n[t[1]] * radius, n[t[2]] * radius,
            normals: t.map { n[$0] }, grey: grey, material: 3, center: center)
        }
      }
    }
  }

  mutating func torus(
    center: SIMD3<Float>, radius: Float, tube: Float, grey: Float, speed: Float, tilt: Float = 0
  ) {
    func vertex(_ x: Int, _ y: Int) -> (SIMD3<Float>, SIMD3<Float>) {
      let a = Float(x) * 2 * .pi / 48
      let b = Float(y) * 2 * .pi / 16
      let n = SIMD3(cos(a) * cos(b), sin(a) * cos(b), sin(b))
      let p = SIMD3(cos(a) * radius, sin(a) * radius, 0) + n * tube
      func lean(_ v: SIMD3<Float>) -> SIMD3<Float> {
        SIMD3(v.x, cos(tilt) * v.y - sin(tilt) * v.z, sin(tilt) * v.y + cos(tilt) * v.z)
      }
      return (lean(p), lean(n))
    }
    for x in 0..<48 {
      for y in 0..<16 {
        let v = [vertex(x, y), vertex(x + 1, y), vertex(x + 1, y + 1), vertex(x, y + 1)]
        for t in [[0, 1, 2], [0, 2, 3]] {
          triangle(
            v[t[0]].0, v[t[1]].0, v[t[2]].0, normals: t.map { v[$0].1 },
            grey: grey, material: 3, center: center, speed: speed)
        }
      }
    }
  }
}
