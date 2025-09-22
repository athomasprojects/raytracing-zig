const vec = @import("vec.zig");
const Vec3 = vec.Vec3;
const Point3 = vec.Point3;
const Interval = @import("Interval.zig");
const Ray = @import("Ray.zig");

x: Interval,
y: Interval,
z: Interval,

const Aabb = @This();

pub const empty: Aabb = .{
    .x = .empty,
    .y = .empty,
    .z = .empty,
};

/// Returns a bounding box created from the points `a` and `b`.
///
/// Treats `a` and `b` as extrema for the bounding box, so we don't require a
/// particular minimum/maximum coordinate order.
pub fn fromPoints(a: Point3, b: Point3) Aabb {
    var bbox: Aabb = undefined;
    const fields = @typeInfo(Aabb).@"struct".fields;
    inline for (fields, 0..fields.len) |field, idx| {
        switch (idx) {
            0...fields.len - 1 => @field(bbox, field.name) = if (a[idx] <= b[idx]) .{ .min = a[idx], .max = b[idx] } else .{ .min = b[idx], .max = a[idx] },
            else => unreachable, // return error.IndexOutOfBounds,
        }
    }
    return bbox;

    // return .{
    //     .x = if (a[0] <= b[0]) .{ .min = a[0], .max = b[0] } else .{ .min = b[0], .max = a[0] },
    //     .y = if (a[1] <= b[1]) .{ .min = a[1], .max = b[1] } else .{ .min = b[1], .max = a[1] },
    //     .z = if (a[2] <= b[2]) .{ .min = a[2], .max = b[2] } else .{ .min = b[2], .max = a[2] },
    // };
}

pub fn fromEnclosedBoxes(box0: Aabb, box1: Aabb) Aabb {
    return .{
        .x = .expandToInclude(box0.x, box1.x),
        .y = .expandToInclude(box0.y, box1.y),
        .z = .expandToInclude(box0.z, box1.z),
    };
}

pub fn axisInterval(self: Aabb, n: usize) Interval {
    if (n == 1) return self.y;
    if (n == 2) return self.z;
    return self.x;
}

pub fn longestAxis(self: Aabb) usize {
    const dx = self.x.size();
    const dy = self.y.size();
    const dz = self.z.size();

    if (dx > dy) return if (dx > dz) 0 else 2;
    return if (dy > dz) 1 else 2;
}

pub fn hit(self: Aabb, ray: Ray, ray_interval: Interval) bool {
    var intersection_interval: Interval = ray_interval;

    const fields = @typeInfo(Aabb).@"struct".fields;
    for (0..fields.len) |axis_idx| {
        const ax: Interval = self.axisInterval(axis_idx);
        const adinv: f64 = 1.0 / ray.direction[axis_idx];

        const t0 = (ax.min - ray.origin[axis_idx]) * adinv;
        const t1 = (ax.max - ray.origin[axis_idx]) * adinv;

        if (t0 < t1) {
            if (t0 > ray_interval.min) intersection_interval.min = t0;
            if (t1 < ray_interval.max) intersection_interval.max = t1;
        } else {
            if (t1 > ray_interval.min) intersection_interval.min = t1;
            if (t0 < ray_interval.max) intersection_interval.max = t0;
        }

        if (intersection_interval.max <= intersection_interval.min) return false;
    }

    return true;
}
