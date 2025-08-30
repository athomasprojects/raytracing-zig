const std = @import("std");
const vec = @import("vec.zig");
const hittable = @import("hittable.zig");
const Vec3 = vec.Vec3;
const Point3 = vec.Point3;
const Colour = vec.Colour;
const HitRecord = hittable.HitRecord;
const Hittable = hittable.Hittable;
const HittableList = hittable.HittableList;
const Ray = @import("Ray.zig");

pub const Material = union(enum) {
    lambertian: Colour,
    metal: Colour,

    pub fn scatter(self: Material, ray_in: *Ray, rec: *HitRecord, scattered: *Ray) bool {
        return switch (self) {
            .lambertian => |_| lambertianScatter(ray_in, rec, scattered),
            .metal => |_| metalScatter(ray_in, rec, scattered),
        };
    }

    pub fn lambertianScatter(ray_in: *Ray, rec: *HitRecord, scattered_ray: *Ray) bool {
        _ = ray_in;

        var scatter_dir: Vec3 = rec.normal + vec.randomUnitVec();
        // Catch degenerate scatter direction.
        if (vec.nearZero(scatter_dir))
            scatter_dir = rec.normal;

        scattered_ray.* = .init(rec.p, scatter_dir);
        return true;
    }

    pub fn metalScatter(ray_in: *Ray, rec: *HitRecord, scattered_ray: *Ray) bool {
        scattered_ray.* = .init(rec.p, vec.reflect(ray_in.dir, rec.normal));
        return true;
    }
};
