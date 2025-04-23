const std = @import("std");
const Colour = @import("vec.zig").Colour;
const Point3 = @import("vec.zig").Point3;
const Vec3 = @import("vec.zig").Vec3;

pub const Ray = struct {
    orig: Point3,
    dir: Vec3,

    pub fn init(orig: Point3, dir: Vec3) Ray {
        return .{ .orig = orig, .dir = dir };
    }

    pub fn at(self: Ray, t: f64) Point3 {
        return self.orig + Vec3.scale(self, t);
    }
};
