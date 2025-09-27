const std = @import("std");
const vec = @import("vec.zig");

const Allocator = std.mem.Allocator;
const Aabb = @import("AxisAlignedBoundingBox.zig");
const Interval = @import("Interval.zig");
const Material = @import("material.zig").Material;
const Point3 = vec.Point3;
const Ray = @import("Ray.zig");
const Vec3 = vec.Vec3;

pub const HitRecord = struct {
    t: f64,
    u: f64, // Normalized texture space coordinate. Azimuthal angle around the Y axis from X=-1, at the intersection point.
    v: f64, // Normalized texture space coordinate. Polar angle angle from the positive Y axis (Y=-1) to Y=+1, at the intersection point.
    p: Point3,
    normal: Vec3,
    front_face: bool,
    material: Material,
};

pub const Primitive = union(enum) {
    sphere: Sphere,
    quad: Quad,
    box: Box,
    translate: Translation,
    rotate: RotateY,

    pub fn hit(self: *const Primitive, ray: Ray, ray_interval: Interval) ?HitRecord {
        return switch (self.*) {
            inline else => |prim| prim.hit(ray, ray_interval),
        };
    }

    pub fn bbox(self: *const Primitive) Aabb {
        return switch (self.*) {
            inline else => |prim| prim.bbox,
        };
    }
};

pub const Translation = struct {
    primitive: *const Primitive,
    offset: Vec3,
    bbox: Aabb,

    pub fn init(primitive: *const Primitive, offset: Vec3) Translation {
        return .{
            .primitive = primitive,
            .offset = offset,
            .bbox = primitive.bbox().fromOffset(offset),
        };
    }

    pub fn hit(self: Translation, ray: Ray, ray_interval: Interval) ?HitRecord {
        // Move the ray backwards by the offset.
        const offset_ray: Ray = .initMoving(
            ray.origin - self.offset,
            ray.direction,
            ray.time,
        );

        // Determine whether an intersection exists along the offset ray (and if so, where).
        var translated_hit: ?HitRecord = self.primitive.hit(offset_ray, ray_interval) orelse return null;

        // Move the intersection point forwards by the offset.
        translated_hit.?.p += self.offset;
        return translated_hit;
    }
};

pub const RotateY = struct {
    primitive: *const Primitive,
    sin_theta: f64,
    cos_theta: f64,
    bbox: Aabb,

    const CoordTransform = enum {
        from_world_to_object_space,
        from_object_to_world_space,
    };

    pub fn init(primitive: *const Primitive, angle_deg: f64) RotateY {
        const radians: f64 = std.math.degreesToRadians(angle_deg);
        const sin_theta = @sin(radians);
        const cos_theta = @cos(radians);
        const bbox = primitive.bbox(); // Bounding box of the unrotated primitive in world space.

        var rotated_primitive: RotateY = .{
            .primitive = primitive,
            .cos_theta = cos_theta,
            .sin_theta = sin_theta,
            .bbox = bbox,
        };

        // Pre-compute corner offsets.
        const corners_world_space: [8]Vec3 = .{
            .{ bbox.x.min, bbox.y.min, bbox.z.min },
            .{ bbox.x.max, bbox.y.min, bbox.z.min },
            .{ bbox.x.min, bbox.y.max, bbox.z.min },
            .{ bbox.x.max, bbox.y.max, bbox.z.min },
            .{ bbox.x.min, bbox.y.min, bbox.z.max },
            .{ bbox.x.max, bbox.y.min, bbox.z.max },
            .{ bbox.x.min, bbox.y.max, bbox.z.max },
            .{ bbox.x.max, bbox.y.max, bbox.z.max },
        };

        var min: Vec3 = vec.splat(vec.infinity);
        var max: Vec3 = vec.splat(-vec.infinity);
        for (corners_world_space) |corner| {
            // Rotate around Y-axis.
            const rotated_corner: Vec3 = rotated_primitive.coordTransform(corner, .from_object_to_world_space);
            min = @min(min, rotated_corner);
            max = @max(max, rotated_corner);
        }

        // Compute the rotated primitive's bounding box.
        rotated_primitive.bbox = .fromPoints(min, max);
        return rotated_primitive;
    }

    pub fn hit(self: RotateY, ray: Ray, ray_interval: Interval) ?HitRecord {
        // Transform the ray from world space to object space.
        const rotated_ray: Ray = .{
            .origin = self.coordTransform(ray.origin, .from_world_to_object_space),
            .direction = self.coordTransform(ray.direction, .from_world_to_object_space),
            .time = ray.time,
        };

        var rotated_hit: ?HitRecord = self.primitive.hit(rotated_ray, ray_interval) orelse return null;

        // Transform the intersection point from object space back to world space.
        rotated_hit.?.p = self.coordTransform(rotated_hit.?.p, .from_object_to_world_space);
        rotated_hit.?.normal = self.coordTransform(rotated_hit.?.normal, .from_object_to_world_space);
        return rotated_hit;
    }

    fn coordTransform(self: RotateY, v: Vec3, tx: CoordTransform) Vec3 {
        return switch (tx) {
            .from_world_to_object_space => .{
                self.cos_theta * vec.x(v) - self.sin_theta * vec.z(v),
                vec.y(v),
                self.sin_theta * vec.x(v) + self.cos_theta * vec.z(v),
            },
            .from_object_to_world_space => .{
                self.cos_theta * vec.x(v) + self.sin_theta * vec.z(v),
                vec.y(v),
                -self.sin_theta * vec.x(v) + self.cos_theta * vec.z(v),
            },
        };
    }
};

pub const Sphere = struct {
    center: Ray,
    radius: f64,
    material: Material,
    bbox: Aabb,

    pub fn init(center: Point3, radius: f64, material: Material) Sphere {
        const r: Vec3 = vec.splat(radius);
        return .{
            .center = .init(center, vec.zero),
            .radius = @max(0, radius),
            .material = material,
            .bbox = .fromPoints(center - r, center + r),
        };
    }

    pub fn initMoving(center_from: Point3, center_to: Point3, radius: f64, material: Material) Sphere {
        const center: Ray = .init(center_from, center_to - center_from);
        const r: Vec3 = vec.splat(radius);

        const center_at_0 = center.at(0);
        const center_at_1 = center.at(1);
        return .{
            .center = center,
            .radius = @max(0, radius),
            .material = material,
            .bbox = .fromEnclosedBoxes(
                .fromPoints(center_at_0 - r, center_at_0 + r),
                .fromPoints(center_at_1 - r, center_at_1 + r),
            ),
        };
    }

    pub fn hit(self: Sphere, ray: Ray, ray_interval: Interval) ?HitRecord {
        const current_center: Point3 = self.center.at(ray.time);
        const oc: Vec3 = current_center - ray.origin; // Vector from the ray origin to the center of the sphere.
        const a: f64 = vec.magnitude2(ray.direction);
        const h: f64 = vec.dot(ray.direction, oc);
        const c: f64 = vec.magnitude2(oc) - self.radius * self.radius;

        // discriminant < 0 : no solutions (ray does not hit).
        // discriminant == 0 : 1 solution (ray intersects sphere at one point tangent to the sphere).
        // discriminant > 0 : 2 solutions (ray intersects the sphere at 2 unique points).
        const discriminant: f64 = h * h - a * c;

        if (discriminant < 0) return null;

        // Find the nearest root that lies in the acceptable range.
        const sqrtd = std.math.sqrt(discriminant);
        var root = (h - sqrtd) / a;

        if (!ray_interval.surrounds(root)) {
            root = (h + sqrtd) / a;
            if (!ray_interval.surrounds(root)) return null;
        }

        const p = ray.at(root);
        const outward_unit_normal = vec.divScalar(p - current_center, self.radius);
        const front_face = vec.dot(ray.direction, outward_unit_normal) < 0;

        return .{
            .t = root,
            .p = p,
            .u = (vec.atan2(-vec.z(outward_unit_normal), vec.x(outward_unit_normal)) + vec.pi) / vec.two_pi,
            .v = vec.acos(-vec.y(outward_unit_normal)) / vec.pi,
            .normal = if (front_face) outward_unit_normal else -outward_unit_normal,
            .front_face = front_face,
            .material = self.material,
        };
    }
};

pub const Quad = struct {
    q: Point3, // Starting corner (vertex) of the quadrilateral.
    u: Vec3, // Vector representing the fist side of the quadrilateral.
    v: Vec3, // Vector representing the second side of the quadrilateral.
    w: Vec3, // n = (u x v):  w = n / (n . n)
    unit_normal: Vec3,
    offset: f64,
    material: Material,
    bbox: Aabb,

    pub fn init(q: Point3, u: Vec3, v: Vec3, material: Material) Quad {
        const n = vec.cross(u, v);
        const normal = vec.unit(n);

        // Compute the bounding box of all 4 vertices.
        const bbox_diagonal1: Aabb = .fromPoints(q, q + u + v);
        const bbox_diagonal2: Aabb = .fromPoints(q + u, q + v);
        const bbox: Aabb = .fromEnclosedBoxes(bbox_diagonal1, bbox_diagonal2);

        return .{
            .q = q,
            .u = u,
            .v = v,
            .w = vec.divScalar(n, vec.magnitude2(n)),
            .unit_normal = normal,
            .offset = vec.dot(normal, q),
            .material = material,
            .bbox = bbox,
        };
    }

    pub fn hit(self: Quad, ray: Ray, ray_interval: Interval) ?HitRecord {
        const denominator = vec.dot(self.unit_normal, ray.direction);

        // Return a miss if the ray is parallel to the plane.
        if (@abs(denominator) < vec.tolerance) return null;

        // Return a miss if the hit point parameter `t` is outside the ray interval.
        const t = (self.offset - vec.dot(self.unit_normal, ray.origin)) / denominator;
        if (!ray_interval.contains(t)) return null;

        // Determine if the hit point lies within the quad using its plane coordinates.
        // The hit point is inside the quad if: 0 <= alpha <= 1, and 0 <= beta <= 1.
        const intersection: Point3 = ray.at(t);
        const planar_hit_point_vec = intersection - self.q;
        const alpha = vec.dot(self.w, vec.cross(planar_hit_point_vec, self.v));
        const beta = vec.dot(self.w, vec.cross(self.u, planar_hit_point_vec));

        // Given the hit point in plane coordinates, return a miss if it is
        // outside the primitive, otherwise set the hit record UV coordinates.
        const quad_space_interval: Interval = .{ .min = 0, .max = 1 };
        if (!quad_space_interval.contains(alpha) or !quad_space_interval.contains(beta)) return null;

        const front_face = vec.dot(ray.direction, self.unit_normal) < 0;

        return .{
            .t = t,
            .p = intersection,
            .u = alpha,
            .v = beta,
            .normal = if (front_face) self.unit_normal else -self.unit_normal,
            .front_face = front_face,
            .material = self.material,
        };
    }
};

const Box = struct {
    sides: [6]Quad,
    bbox: Aabb,

    /// Creates a 3D box (six sides) that contains the two opposite vertices `a` & `b` to the list of primitives.
    pub fn init(a: Point3, b: Point3, material: Material) Box {

        // Construct the two opposite vertices with the minimum and maximum coordinates.
        const min: Point3 = @min(a, b);
        const max: Point3 = @max(a, b);

        const dx: Vec3 = .{ vec.x(max - min), 0, 0 };
        const dy: Vec3 = .{ 0, vec.y(max - min), 0 };
        const dz: Vec3 = .{ 0, 0, vec.z(max - min) };

        const sides = [_]Quad{
            .init(Point3{ vec.x(min), vec.y(min), vec.z(max) }, dx, dy, material), // front
            .init(Point3{ vec.x(max), vec.y(min), vec.z(max) }, -dz, dy, material), // right
            .init(Point3{ vec.x(max), vec.y(min), vec.z(min) }, -dx, dy, material), // back
            .init(Point3{ vec.x(min), vec.y(min), vec.z(min) }, dz, dy, material), // left
            .init(Point3{ vec.x(min), vec.y(max), vec.z(max) }, dx, -dz, material), // top
            .init(Point3{ vec.x(min), vec.y(min), vec.z(min) }, dx, dz, material), // bottom
        };

        var bbox: Aabb = .empty;
        for (sides) |side| bbox = .fromEnclosedBoxes(bbox, side.bbox);

        return .{ .sides = sides, .bbox = bbox };
    }

    fn hit(self: Box, ray: Ray, ray_interval: Interval) ?HitRecord {
        var closest_hit: ?HitRecord = null;
        var closest_so_far: f64 = ray_interval.max;

        for (self.sides) |quad| {
            if (quad.hit(ray, .{ .min = ray_interval.min, .max = closest_so_far })) |h| {
                closest_hit = h;
                closest_so_far = h.t;
            }
        }
        return closest_hit;
    }
};
