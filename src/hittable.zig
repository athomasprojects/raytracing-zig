const std = @import("std");
const vec = @import("vec.zig");
const Ray = @import("ray.zig").Ray;
const Sphere = @import("sphere.zig").Sphere;
const Point3 = @import("vec.zig").Point3;
const Vec3 = vec.Vec3;

pub const HitRecord = struct {
    p: Point3,
    normal: Vec3,
    t: f64,
};

pub const Hittable = union(enum) {
    Sphere: Sphere,

    pub fn hit(self: Hittable, r: Ray, t_min: f64, t_max: f64, rec: HitRecord) Hittable {
        return switch (self) {
            .Sphere => |s| s.hit(r, t_min, t_max, rec),
        };
    }

    pub fn sphere(center: Point3, radius: f64) Hittable {
        return .{ .Sphere = Sphere{ .center = center, .radius = @max(0, radius) } };
    }
};
