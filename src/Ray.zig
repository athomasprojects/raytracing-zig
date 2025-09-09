const vec = @import("vec.zig");
const Point3 = @import("vec.zig").Point3;
const Vec3 = vec.Vec3;

origin: Point3,
dir: Vec3,
const Self = @This();

pub const empty: Self = .{
    .origin = vec.zero,
    .dir = vec.zero,
};

pub fn init(orig: Point3, dir: Vec3) Self {
    return .{
        .origin = orig,
        .dir = dir,
    };
}

pub fn at(self: Self, t: f64) Point3 {
    // return self.origin + vec.scale(self.dir, t);
    return @mulAdd(Vec3, @splat(t), self.dir, self.origin);
}
