const std = @import("std");
const Colour = @import("vec.zig").Colour;
const Point3 = @import("vec.zig").Point3;
const F64x3 = @import("vec.zig").F64x3;

pub const Ray = struct {
    orig: Point3,
    dir: F64x3,

    pub fn init(orig: Point3, dir: F64x3) Ray {
        return .{ .orig = orig, .dir = dir };
    }

    pub fn origin(self: Ray) Point3 {
        return self.orig;
    }

    pub fn direction(self: Ray) F64x3 {
        return self.dir;
    }

    pub fn at(self: Ray, t: f64) Point3 {
        return self.orig + F64x3.scale(self, t);
    }
};
