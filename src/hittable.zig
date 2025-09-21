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
    u: f64, // Texture coordinate.
    v: f64, // Texture coordinate.
    p: Point3,
    normal: Vec3,
    front_face: bool,
    mat: Material,

    pub fn init(ray: Ray, t: f64, center: Vec3, radius: f64, mat: Material) HitRecord {
        const p = ray.at(t);
        const outward_normal = vec.divScalar(p - center, radius); // Assumed to have unit length.
        const front_face = vec.dot(ray.direction, outward_normal) < 0;

        const theta_rad = vec.acos(-vec.y(outward_normal)); // Polar angle from the positive negative y-axis (i.e. the _bottom_ pole).
        const phi_rad = vec.atan2(-vec.z(outward_normal), vec.x(outward_normal)) + vec.pi;

        return .{
            .t = t,
            .p = p,
            .u = phi_rad / vec.two_pi,
            .v = theta_rad / vec.pi,
            .normal = if (front_face) outward_normal else -outward_normal,
            .front_face = front_face,
            .mat = mat,
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

        return .init(ray, root, current_center, self.radius, self.mat);
    }

    // /// `p`: a given point on the sphere of radius one, centered at the origin.
    // /// `u`: returned value [0,1] of angle around the Y axis from X=-1.
    // /// `v`: returned value [0,1] of angle from Y=-1 to Y=+1.
    // pub fn getSphereUv(self: Sphere, p: Point3, u: f64, v: f64) void {
    //     //     <1 0 0> yields <0.50 0.50>       <-1  0  0> yields <0.00 0.50>
    //     //     <0 1 0> yields <0.50 1.00>       < 0 -1  0> yields <0.50 0.00>
    //     //     <0 0 1> yields <0.25 0.50>       < 0  0 -1> yields <0.75 0.50>
    //
    // }
};
