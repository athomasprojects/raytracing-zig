const std = @import("std");
const vec = @import("vec.zig");
const hittable = @import("hittable.zig");
const Vec3 = vec.Vec3;
const Point3 = vec.Point3;
const Hittable = hittable.Hittable;
const HitRecord = hittable.HitRecord;
const Ray = @import("Ray.zig");

center: Point3,
radius: f64,
const Sphere = @This();

pub fn init(center: Point3, radius: f64) Sphere {
    return .{
        .center = center,
        .radius = @max(0, radius),
    };
}

pub fn hit(self: Sphere, ray: *Ray, t_min: f64, t_max: f64, rec: *HitRecord) bool {
    const oc: Vec3 = self.center - ray.origin; // vector from the ray origin to the center of the sphere.
    const a: f64 = vec.lengthSquared(ray.dir);
    const h: f64 = vec.dot(ray.dir, oc);
    const c: f64 = vec.lengthSquared(oc) - self.radius * self.radius;

    // discriminant < 0 : no solutions (ray does not hit).
    // discriminant == 0 : 1 solution (ray intersects sphere at one point tangent to the sphere).
    // discriminant > 0 : 2 solutions (ray intersects the sphere at 2 unique points).
    const discriminant: f64 = h * h - a * c;

    if (discriminant < 0) {
        return false;
    }

    // Find the nearest root that lies in the acceptable range.
    const sqrtd = std.math.sqrt(discriminant);
    var root = (h - sqrtd) / a;
    if (root <= t_min or t_max <= root) {
        root = (h + sqrtd) / a;
        if (root <= t_min or t_max <= root) {
            return false;
        }
    }

    // Update hit record.
    rec.t = root;
    rec.p = ray.at(rec.t);
    const outward_normal: Vec3 = vec.divScalar(rec.p - self.center, self.radius);
    rec.setFaceNormal(ray, outward_normal);

    return true;
}
