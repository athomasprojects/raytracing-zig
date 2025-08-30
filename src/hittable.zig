const std = @import("std");
const vec = @import("vec.zig");
const Ray = @import("Ray.zig");
const Sphere = @import("Sphere.zig");
const Vec3 = vec.Vec3;
const Point3 = vec.Point3;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

pub const HitRecord = struct {
    p: Point3,
    normal: Vec3,
    t: f64,
    front_face: bool,

    /// Sets the hit record normal vector. `outward_normal` is assumed to have unit length.
    pub fn setFaceNormal(self: *HitRecord, ray: *Ray, outward_normal: Vec3) void {
        self.front_face = vec.dot(ray.dir, outward_normal) < 0;
        self.normal = if (self.front_face) outward_normal else -outward_normal;
    }
};

pub const Hittable = union(enum) {
    sphere: Sphere,

    pub fn hit(self: Hittable, ray: *Ray, t_min: f64, t_max: f64, rec: *HitRecord) bool {
        return switch (self) {
            inline else => |impl| impl.hit(ray, t_min, t_max, rec),
        };
    }
};

pub const HittableList = struct {
    allocator: Allocator,
    objects: ArrayList(Hittable),

    pub fn init(allocator: Allocator, capacity: usize) !HittableList {
        return .{
            .allocator = allocator,
            .objects = try ArrayList(Hittable).initCapacity(allocator, capacity),
        };
    }

    pub fn deinit(self: *HittableList) void {
        self.objects.deinit();
        // self.* = undefined;
    }

    pub fn hit(self: *HittableList, ray: *Ray, ray_tmin: f64, ray_tmax: f64, rec: *HitRecord) bool {
        var temp_rec: HitRecord = undefined;
        var hit_anything = false;
        var closest_so_far = ray_tmax;

        for (self.objects.items) |object| {
            if (object.hit(ray, ray_tmin, closest_so_far, &temp_rec)) {
                hit_anything = true;
                closest_so_far = temp_rec.t;
                rec.* = temp_rec;
            }
        }
        return hit_anything;
    }

    pub fn add(self: *HittableList, object: Hittable) !void {
        try self.objects.append(self.allocator, object);
    }
};
