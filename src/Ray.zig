const vec = @import("vec.zig");
const Point3 = @import("vec.zig").Point3;
const Vec3 = vec.Vec3;

origin: Point3,
direction: Vec3,
time: f64 = 0,
const Self = @This();

pub const empty: Self = .{
    .origin = vec.zero,
    .direction = vec.zero,
};

pub fn init(origin: Point3, direction: Vec3) Self {
    return .{
        .origin = origin,
        .direction = direction,
    };
}

pub fn initMoving(origin: Point3, direction: Vec3, time: f64) Self {
    return .{
        .origin = origin,
        .direction = direction,
        .time = time,
    };
}

pub fn at(self: Self, t: f64) Point3 {
    // return self.origin + vec.scale(self.dir, t);
    return @mulAdd(Vec3, @splat(t), self.direction, self.origin);
}
