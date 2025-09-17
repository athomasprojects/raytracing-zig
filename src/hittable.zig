const std = @import("std");
const vec = @import("vec.zig");
const Allocator = std.mem.Allocator;
const Aabb = @import("AxisAlignedBoundingBox.zig");
const Interval = @import("Interval.zig");
const Material = @import("material.zig").Material;
const Point3 = vec.Point3;
const Ray = @import("Ray.zig");
const Vec3 = vec.Vec3;

pub const HitRecord = struct {
    t: f64,
    p: Point3,
    normal: Vec3,
    front_face: bool,
    mat: Material,

    pub fn init(ray: Ray, t: f64, center: Vec3, radius: f64, mat: Material) HitRecord {
        const p = ray.at(t);
        const outward_normal = vec.divScalar(p - center, radius); // Assumed to have unit length.
        const front_face = vec.dot(ray.direction, outward_normal) < 0;
        return .{
            .t = t,
            .p = p,
            .normal = if (front_face) outward_normal else -outward_normal,
            .front_face = front_face,
            .mat = mat,
        };
    }
};

pub const HittableList = struct {
    gpa: Allocator,
    objects: std.ArrayListUnmanaged(Sphere) = .empty,
    ptrs: std.ArrayListUnmanaged(*Sphere) = .empty,
    // indices: []u32 = &.{},
    root_bbox: Aabb = .empty,

    pub fn init(gpa: Allocator) !HittableList {
        return .{
            .gpa = gpa,
        };
    }

    pub fn initCapacity(gpa: Allocator, size: usize) !HittableList {
        return .{
            .gpa = gpa,
            .objects = try .initCapacity(gpa, size),
            .ptrs = try .initCapacity(gpa, size),
            // .indices = try gpa.alloc(u32, size),
        };
    }

    pub fn deinit(self: *HittableList) void {
        self.objects.deinit(self.gpa);
        self.ptrs.deinit(self.gpa);
        // self.indices.deinit(self.gpa);
    }

    pub fn add(self: *HittableList, object: Sphere) !void {
        try self.objects.append(self.gpa, object);
        try self.ptrs.append(self.gpa, &self.objects.items[self.objects.items.len - 1]);
        // try self.indices.append(self.gpa, @intCast(self.objects.items.len - 1));
        self.root_bbox = .fromEnclosedBoxes(self.root_bbox, object.bbox);
    }

    pub fn addSlice(self: *HittableList, objects: []Sphere) !void {
        const start = self.objects.items.len;
        try self.objects.appendSlice(self.gpa, objects);

        for (objects, 0..objects.len) |object, offset| {
            self.root_bbox = .fromEnclosedBoxes(self.root_bbox, object.bbox);
            try self.ptrs.append(self.gpa, &self.objects.items[start + offset]);
            // try self.indices.append(self.gpa, @intCast(start + offset));
        }
    }

    pub fn addIndices(self: *HittableList) !void {
        self.indices = try self.gpa.alloc(u32, self.objects.items.len);
        for (0..self.objects.items.len) |idx| {
            self.indices[idx] = @intCast(idx);
        }
    }

    pub fn hitAll(self: *HittableList, ray: Ray, ray_interval: Interval) ?HitRecord {
        var hit: ?HitRecord = null;
        var closest_so_far = vec.infinity;

        for (self.objects.items) |object| {
            if (object.hit(ray, .{ .min = ray_interval.min, .max = closest_so_far })) |h| {
                closest_so_far = h.t;
                hit = h;
            }
        }
        return hit;
    }
};

pub const Sphere = struct {
    center: Ray,
    radius: f64,
    mat: Material,
    bbox: Aabb,

    pub fn init(center: Point3, radius: f64, mat: Material) Sphere {
        const r: Vec3 = vec.splat(radius);
        return .{
            .center = .init(center, vec.zero),
            .radius = @max(0, radius),
            .mat = mat,
            .bbox = .fromPoints(center - r, center + r),
        };
    }

    pub fn initMoving(center_from: Point3, center_to: Point3, radius: f64, mat: Material) Sphere {
        const center: Ray = .init(center_from, center_to - center_from);
        const r: Vec3 = vec.splat(radius);

        const center_at_0 = center.at(0);
        const center_at_1 = center.at(1);
        return .{
            .center = center,
            .radius = @max(0, radius),
            .mat = mat,
            .bbox = .fromEnclosedBoxes(
                .fromPoints(center_at_0 - r, center_at_0 + r),
                .fromPoints(center_at_1 - r, center_at_1 + r),
            ),
        };
    }

    pub fn hit(self: Sphere, ray: Ray, ray_interval: Interval) ?HitRecord {
        const current_center: Point3 = self.center.at(ray.time);
        const oc: Vec3 = current_center - ray.origin; // Vector from the ray origin to the center of the sphere.
        const a: f64 = vec.magnitude2(ray.direction);
        const h: f64 = vec.dot(ray.direction, oc);
        const c: f64 = vec.magnitude2(oc) - self.radius * self.radius;

        // discriminant < 0 : no solutions (ray does not hit).
        // discriminant == 0 : 1 solution (ray intersects sphere at one point tangent to the sphere).
        // discriminant > 0 : 2 solutions (ray intersects the sphere at 2 unique points).
        const discriminant: f64 = h * h - a * c;

        if (discriminant < 0) return null;

        // Find the nearest root that lies in the acceptable range.
        const sqrtd = std.math.sqrt(discriminant);
        var root = (h - sqrtd) / a;
        if (!ray_interval.surrounds(root)) {
            root = (h + sqrtd) / a;
            if (!ray_interval.surrounds(root)) {
                return null;
            }
        }
        return .init(ray, root, current_center, self.radius, self.mat);
    }
};
