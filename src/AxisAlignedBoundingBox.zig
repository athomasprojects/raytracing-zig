const vec = @import("vec.zig");
const Vec3 = vec.Vec3;
const Point3 = vec.Point3;
const Interval = @import("Interval.zig");
const Ray = @import("Ray.zig");

x: Interval,
y: Interval,
z: Interval,
const Self = @This();

pub const empty: Self = .{
    .x = .empty,
    .y = .empty,
    .z = .empty,
};

/// Treats the two points `a` and `b` as extrema for the bounding box, so we don't
/// require a particular minimum/maximum coordinate order.
pub fn init(a: Point3, b: Point3) Self {
    return .{
        .x = if (a[0] <= b[0]) .{ .min = a[0], .max = b[0] } else .{ .min = b[0], .max = a[0] },
        .y = if (a[1] <= b[1]) .{ .min = a[1], .max = b[1] } else .{ .min = b[1], .max = a[1] },
        .z = if (a[2] <= b[2]) .{ .min = a[2], .max = b[2] } else .{ .min = b[2], .max = a[2] },
    };
}

pub fn axisInterval(self: Self, n: usize) Interval {
    if (n == 1) return self.y;
    if (n == 2) return self.z;
    return self.x;
}

pub fn hit(self: Self, ray: Ray, ray_interval: Interval) ?Interval {
    var intersection_interval: ?Interval = ray_interval;

    for (0..3) |axis| {
        const ax: Interval = self.axisInterval(axis);
        const adinv: f64 = 1.0 / ray.direction[axis];

        const t0 = (ax.min - ray.origin[axis]) * adinv;
        const t1 = (ax.max - ray.origin[axis]) * adinv;

        if (t0 < t1) {
            if (t0 > ray_interval.min) intersection_interval.?.min = t0;
            if (t1 < ray_interval.max) intersection_interval.?.max = t1;
        } else {
            if (t1 > ray_interval.min) intersection_interval.?.min = t1;
            if (t0 < ray_interval.max) intersection_interval.?.max = t0;
        }

        if (intersection_interval.?.max <= intersection_interval.?.min) return null;
    }

    return intersection_interval;
}
