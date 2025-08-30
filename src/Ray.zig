const std = @import("std");
const vec = @import("vec.zig");
const Colour = @import("vec.zig").Colour;
const Point3 = @import("vec.zig").Point3;
const Vec3 = vec.Vec3;

origin: Point3,
dir: Vec3,
const Ray = @This();

pub const empty: Ray = .{
    .origin = vec.empty,
    .dir = vec.empty,
};

pub fn init(orig: Point3, dir: Vec3) Ray {
    return .{
        .origin = orig,
        .dir = dir,
    };
}

pub fn at(self: *Ray, t: f64) Point3 {
    return self.origin + vec.scale(self.dir, t);
}
