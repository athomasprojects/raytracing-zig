const std = @import("std");
const vec = @import("vec.zig");

const Allocator = std.mem.Allocator;
const Aabb = @import("AxisAlignedBoundingBox.zig");
const BoundedList = @import("util.zig").BoundedList;
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
    mat: Material,
};

pub const Primitive = union(enum) {
    sphere: Sphere,
    quad: Quad,

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

pub const Sphere = struct {
    center: Ray,
    radius: f64,
    mat: Material,
    bbox: Aabb,

    pub fn init(center: Point3, radius: f64, mat: Material) Sphere {
        const r: Vec3 = vec.splat(radius);
        return .{
            .center = .init(center, vec.zero),
            .radius = @max(0, radius),
            .mat = mat,
            .bbox = .fromPoints(center - r, center + r),
        };
    }

    pub fn initMoving(center_from: Point3, center_to: Point3, radius: f64, mat: Material) Sphere {
        const center: Ray = .init(center_from, center_to - center_from);
        const r: Vec3 = vec.splat(radius);

        const center_at_0 = center.at(0);
        const center_at_1 = center.at(1);
        return .{
            .center = center,
            .radius = @max(0, radius),
            .mat = mat,
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
            .mat = self.mat,
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
    mat: Material,
    bbox: Aabb,

    pub fn init(q: Point3, u: Vec3, v: Vec3, mat: Material) Quad {
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
            .mat = mat,
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
            .mat = self.mat,
        };
    }
};
