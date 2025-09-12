const std = @import("std");
const vec = @import("vec.zig");
const Allocator = std.mem.Allocator;
// const ArrayList = std.ArrayList;
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
    objects: std.ArrayListUnmanaged(Sphere),

    pub fn init(allocator: Allocator) !HittableList {
        return .{
            .gpa = allocator,
            .objects = .empty,
        };
    }

    pub fn deinit(self: *HittableList) void {
        self.objects.deinit(self.gpa);
    }

    pub fn add(self: *HittableList, object: Sphere) !void {
        try self.objects.append(self.gpa, object);
    }

    pub fn addSlice(self: *HittableList, object: []Sphere) !void {
        try self.objects.appendSlice(self.gpa, object);
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

    pub fn init(center: Point3, radius: f64, mat: Material) Sphere {
        return .{
            .center = .init(center, vec.zero),
            .radius = @max(0, radius),
            .mat = mat,
        };
    }

    pub fn initMoving(center_from: Point3, center_to: Point3, radius: f64, mat: Material) Sphere {
        return .{
            .center = .init(center_from, center_to - center_from),
            .radius = @max(0, radius),
            .mat = mat,
        };
    }

    fn hit(self: Sphere, ray: Ray, ray_interval: Interval) ?HitRecord {
        const current_center: Point3 = self.center.at(ray.time);
        const oc: Vec3 = current_center - ray.origin; // vector from the ray origin to the center of the sphere.
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
