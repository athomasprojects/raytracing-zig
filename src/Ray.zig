const Ray = @This();

origin: Point3,
direction: Vec3,
time: f64 = 0,

pub const empty: Ray = .{
    .origin = vec.zero,
    .direction = vec.zero,
};

pub fn init(origin: Point3, direction: Vec3) Ray {
    return .{
        .origin = origin,
        .direction = direction,
    };
}

pub fn initMoving(origin: Point3, direction: Vec3, time: f64) Ray {
    return .{
        .origin = origin,
        .direction = direction,
        .time = time,
    };
}

/// Returns position of the ray displaced by `t` along the ray direction.
///
/// `r`(`t`) = (`t` * `direction`) + `origin`
pub fn at(self: Ray, t: f64) Point3 {
    return @mulAdd(Vec3, @splat(t), self.direction, self.origin);
}

const vec = @import("vec.zig");
const Point3 = vec.Point3;
const Vec3 = vec.Vec3;
