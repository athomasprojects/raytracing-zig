const std = @import("std");
const vec = @import("vec.zig");
const Ray = @import("Ray.zig");
const Interval = @import("Interval.zig");
const Material = @import("material.zig").Material;
const Vec3 = vec.Vec3;
const Point3 = vec.Point3;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

pub const HitRecord = struct {
    t: f64,
    p: Point3,
    normal: Vec3,
    front_face: bool,
    mat: Material,

    pub fn update(ray: *Ray, t: f64, center: Vec3, radius: f64, mat: Material) HitRecord {
        const p = ray.at(t);
        const outward_normal = vec.divScalar(p - center, radius); // Assumed to have unit length.
        const front_face = vec.dot(ray.dir, outward_normal) < 0;
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
    allocator: Allocator,
    objects: ArrayList(Sphere),

    pub fn init(allocator: Allocator, capacity: usize) !HittableList {
        return .{
            .allocator = allocator,
            .objects = try ArrayList(Sphere).initCapacity(allocator, capacity),
        };
    }

    pub fn deinit(self: *HittableList) void {
        self.objects.deinit();
    }

    pub fn hit(self: *HittableList, ray: *Ray, ray_interval: Interval, rec: *HitRecord) bool {
        var temp_rec: HitRecord = undefined;
        var hit_anything = false;
        var closest_so_far = ray_interval.max;

        for (self.objects.items) |object| {
            if (object.hit(ray, .init(ray_interval.min, closest_so_far), &temp_rec)) {
                hit_anything = true;
                closest_so_far = temp_rec.t;
                rec.* = temp_rec;
            }
        }
        return hit_anything;
    }

    pub fn add(self: *HittableList, object: Sphere) !void {
        try self.objects.append(self.allocator, object);
    }
};

pub const Sphere = struct {
    center: Point3,
    radius: f64,
    mat: Material,

    pub fn init(center: Point3, radius: f64, mat: Material) Sphere {
        return .{
            .center = center,
            .radius = @max(0, radius),
            .mat = mat,
        };
    }

    fn hit(self: Sphere, ray: *Ray, ray_interval: Interval, rec: *HitRecord) bool {
        const oc: Vec3 = self.center - ray.origin; // vector from the ray origin to the center of the sphere.
        const a: f64 = vec.magnitude2(ray.dir);
        const h: f64 = vec.dot(ray.dir, oc);
        const c: f64 = vec.magnitude2(oc) - self.radius * self.radius;

        // discriminant < 0 : no solutions (ray does not hit).
        // discriminant == 0 : 1 solution (ray intersects sphere at one point tangent to the sphere).
        // discriminant > 0 : 2 solutions (ray intersects the sphere at 2 unique points).
        const discriminant: f64 = h * h - a * c;

        if (discriminant < 0)
            return false;

        // Find the nearest root that lies in the acceptable range.
        const sqrtd = std.math.sqrt(discriminant);
        var root = (h - sqrtd) / a;
        if (!ray_interval.surrounds(root)) {
            root = (h + sqrtd) / a;
            if (!ray_interval.surrounds(root)) {
                return false;
            }
        }

        // Update hit record.
        rec.* = .update(
            ray,
            root,
            self.center,
            self.radius,
            self.mat,
        );
        return true;
    }
};
