const std = @import("std");
const sqrt = std.math.sqrt;
const vec = @import("vec.zig");
const hittable_ = @import("hittable.zig");

const Vec3 = vec.Vec3;
const Point3 = vec.Point3;
const Hittable = hittable_.Hittable;
const HitRecord = hittable_.HitRecord;
const Ray = @import("ray.zig").Ray;

pub const Sphere = struct {
    center: Point3,
    radius: f64,

    pub fn hit(self: Sphere, r: Ray, t_min: f64, t_max: f64, rec: HitRecord) bool {
        const oc: Vec3 = self.center - r.orig; // vector from the ray origin to the center of the sphere
        const a: f64 = vec.lengthSquared(r.dir);
        const h: f64 = vec.dot(r.dir, oc);
        const c: f64 = vec.lengthSquared(oc) - self.radius * self.radius;

        // discriminant < 0 - no solutions (ray does not hit)
        // discriminant == 0 - 1 solution (ray intersects sphere at one point tangent to the sphere)
        // discriminant > 0 - 2 solutions (ray intersects the sphere at 2 unique points)
        const discriminant: f64 = h * h - a * c;

        if (discriminant < 0) {
            return false;
        }

        const sqrtd = sqrt(discriminant);

        // Find the nearest root that lies in the acceptable range.
        var root = (h - sqrtd) / a;
        if (root <= t_min or t_max <= root) {
            root = (h + sqrtd) / a;
            if (root <= t_min or t_max <= root) {
                return false;
            }
        }

        rec.t = root;
        rec.p = r.at(rec.t);
        rec.normal = (rec.p - self.center) / self.radius;

        return true;
    }
};
