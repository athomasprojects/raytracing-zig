pub const Aabb = @This();

x: Interval,
y: Interval,
z: Interval,

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
            0...fields.len - 1 => {
                var interval: Interval = if (a[idx] <= b[idx]) .{ .min = a[idx], .max = b[idx] } else .{ .min = b[idx], .max = a[idx] };

                // Adjust bounding box so that no side is narrower
                // than some delta, padding if necessary.
                const delta = 0.0001;
                if (interval.size() < delta) interval.padBy(delta);
                @field(bbox, field.name) = interval;
            },
            else => unreachable,
        }
    }
    return bbox;
}

/// Returns the bounding box containing both input bounding boxes.
pub fn fromEnclosedBoxes(box0: Aabb, box1: Aabb) Aabb {
    return .{
        .x = .expandToInclude(box0.x, box1.x),
        .y = .expandToInclude(box0.y, box1.y),
        .z = .expandToInclude(box0.z, box1.z),
    };
}

/// Constructs a new bounding box by adding `offset` to the minima and maxima
/// of the input bounding box's x, y, and z axis intervals.
pub fn fromOffset(self: Aabb, offset: Vec3) Aabb {
    return .{
        .x = self.x.fromOffset(vec.x(offset)),
        .y = self.y.fromOffset(vec.y(offset)),
        .z = self.z.fromOffset(vec.z(offset)),
    };
}

pub fn centroid(self: Aabb) Point3 {
    var c: Vec3 = vec.zero;
    const fields = @typeInfo(Aabb).@"struct".fields;
    inline for (fields, 0..fields.len) |field, idx| {
        switch (idx) {
            0...fields.len - 1 => {
                const interval: Interval = @field(self, field.name);
                c[idx] = 0.5 * (interval.min + interval.max);
            },
            else => @panic("unexpected attempt to access invalid Interval struct field"),
        }
    }
    return c;
}

pub fn surfaceArea(self: Aabb) f64 {
    const dx = self.x.size();
    const dy = self.y.size();
    const dz = self.z.size();

    // Multiply this entire expression by 2 to get the actual bounding box
    // surface area.
    //
    // Note: We can omit the factor of 2 in our calculation since the
    // probability that a primitive's bounding box will be hit is proportional
    // to the total surface of all the primitives within a node. Thus, a
    // scaling fact does not matter.
    return dx * dy + dy * dz + dz * dx;
}

/// Returns the `Interval` along the bounding box axis given by `index`.
pub fn intervalFromAxisIndex(self: Aabb, i: usize) Interval {
    if (i == 1) return self.y;
    if (i == 2) return self.z;
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
        const ax: Interval = self.intervalFromAxisIndex(axis_idx);
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

pub fn hitFast(self: Aabb, origin: Vec3, inv_dir: Vec3, t_min: f64, t_max: f64) bool {
    // Slab test using pre-computed inverse direction.
    var tmin = t_min;
    var tmax = t_max;

    const fields = @typeInfo(Aabb).@"struct".fields;
    inline for (fields, 0..fields.len) |field, idx| {
        switch (idx) {
            0...fields.len - 1 => {
                const axis_interval: Interval = @field(self, field.name);
                const inv_component = inv_dir[idx];
                const t0 = (axis_interval.min - origin[idx]) * inv_component;
                const t1 = (axis_interval.max - origin[idx]) * inv_component;
                const ta, const tb = if (t0 <= t1) .{ t0, t1 } else .{ t1, t0 };
                tmin = @max(ta, tmin);
                tmax = @min(tb, tmin);
                if (tmax <= tmin) return false;
            },
            else => unreachable,
        }
    }
    return true;
}

/// Returns the nearest entry distance to this AABB for ordering purposes,
/// otherwise returns null for a ray miss.
pub fn entryDistance(self: Aabb, origin: Vec3, inv_dir: Vec3) ?f64 {
    var tmin: f64 = -vec.infinity;
    var tmax: f64 = vec.infinity;

    const fields = @typeInfo(Aabb).@"struct".fields;
    inline for (fields, 0..fields.len) |field, idx| {
        switch (idx) {
            0...fields.len - 1 => {
                const axis_interval: Interval = @field(self, field.name);
                const inv_component = inv_dir[idx];
                const t0 = (axis_interval.min - origin[idx]) * inv_component;
                const t1 = (axis_interval.max - origin[idx]) * inv_component;
                const ta, const tb = if (t0 <= t1) .{ t0, t1 } else .{ t1, t0 };
                tmin = @max(ta, tmin);
                tmax = @min(tb, tmin);
                if (tmax <= tmin) return null;
            },
            else => unreachable,
        }
    }
    return tmin;
}

const Interval = @import("Interval.zig");
const Ray = @import("Ray.zig");
const vec = @import("vec.zig");
const Vec3 = vec.Vec3;
const Point3 = vec.Point3;
