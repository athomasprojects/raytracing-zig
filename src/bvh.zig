const std = @import("std");
const hittable = @import("hittable.zig");

const Aabb = @import("AxisAlignedBoundingBox.zig");
const Allocator = std.mem.Allocator;
const BoundedList = @import("util.zig").BoundedList;
const HitRecord = hittable.HitRecord;
const Interval = @import("Interval.zig");
const Primitive = hittable.Primitive;
const Ray = @import("Ray.zig");

const Link = struct {
    left: ?*Link = null,
    right: ?*Link = null,
};

pub const Node = struct {
    data: ?u32 = null,
    bbox: Aabb = .empty,
    link: Link,
};

pub const Bvh = struct {
    nodes: BoundedList(Node),
    root: ?*Link = null,

    pub fn init(buf: []Node) Bvh {
        return .{ .nodes = .init(buf) };
    }

    pub fn initCapacity(gpa: Allocator, capacity: usize) !Bvh {
        return .{
            .nodes = try .initCapacity(gpa, capacity),
        };
    }

    pub fn deinit(self: *Bvh, gpa: Allocator) void {
        self.nodes.deinit(gpa);
    }

    /// Returns the bounding volume hierarchy.
    ///
    /// The node buffer determines the tree capacity. Nodes and object primitive
    /// indices are stored in externally initialized and managed memory.
    pub fn build(node_buf: []Node, primitives: []const Primitive, index_buf: []u32) !Bvh {
        // We can never have more than 2N - 1 nodes, where N is the number of object primitives.
        var bvh: Bvh = .init(node_buf);
        if (primitives.len == 0) return bvh;

        if (index_buf.len < primitives.len) return error.OutOfMemory;
        for (0..index_buf.len) |idx| index_buf[idx] = @intCast(idx);

        bvh.root = try bvh.buildRange(primitives, index_buf, 0, primitives.len, 0);
        return bvh;
    }

    /// Returns the bounding volume hierarchy.
    ///
    /// Nodes are stored in externally-managed memory, but initialized internally.
    /// The length of the primitives slice determines the tree capacity.
    pub fn buildAllocating(gpa: Allocator, primitives: []const Primitive) !Bvh {
        // We can never have more than 2N - 1 nodes, where N is the number of primitives primitives.
        var bvh: Bvh = try .initCapacity(gpa, 2 * primitives.len - 1);

        if (primitives.len == 0) return bvh;

        var indices = try gpa.alloc(u32, primitives.len);
        defer gpa.free(indices);

        for (0..indices.len) |idx| indices[idx] = @intCast(idx);

        // // Debug: Visualize tree traversal during formation.
        // std.debug.print("depth, (start, end), nodes:\n", .{});
        // std.debug.print("===========================\n", .{});

        bvh.root = try bvh.buildRange(primitives, indices, 0, primitives.len, 0);

        // // Debug:
        // const nodes = bvh.nodes.list;
        // var leaves: u32 = 0;
        // for (nodes.items) |node| {
        //     if (node.data) |_| {
        //         leaves += 1;
        //     }
        // }
        // std.debug.print("\nTotal nodes: {d}\n", .{nodes.items.len});
        // std.debug.print("Total leaves: {d}\n", .{leaves});

        return bvh;
    }

    fn buildRange(self: *Bvh, primitives: []const Primitive, indices: []u32, start: usize, end: usize, depth: u32) !*Link {
        const span = end - start;

        // Append leaf.
        if (span == 1) {
            try self.nodes.list.appendBounded(.{
                .data = indices[start],
                .bbox = primitives[indices[start]].bbox(),
                .link = .{},
            });

            // // Debug:
            // std.debug.print("leaf index {d}! ==> {d}, ({d}, {d}), {d}\n", .{ indices[start], depth, start, end, nodes.items.len });

            return &self.nodes.list.items[self.nodes.list.items.len - 1].link;
        }

        // Build the bounding box for the span of all the scene primitives in this range.
        var node_bbox: Aabb = .empty;
        for (indices[start..end]) |idx| node_bbox = .fromEnclosedBoxes(
            node_bbox,
            primitives[idx].bbox(),
        );

        // Split over the longest bounding box axis.
        const axis = node_bbox.longestAxis();

        // Sort slice of object array indices along the chosen axis.
        const Context = struct { axis: usize, primitives: []const Primitive };
        std.mem.sort(
            u32,
            indices[start..end],
            Context{
                .axis = axis,
                .primitives = primitives,
            },
            struct {
                fn lessThan(ctx: Context, a: u32, b: u32) bool {
                    return ctx.primitives[a].bbox().axisInterval(ctx.axis).min < ctx.primitives[b].bbox().axisInterval(ctx.axis).min;
                }
            }.lessThan,
        );

        // // Debug:
        // std.debug.print("{d}, ({d}, {d}), {d}\n", .{ depth, start, end, nodes.items.len });

        const mid = start + span / 2;
        const left_link = try self.buildRange(primitives, indices, start, mid, depth + 1);
        const right_link = try self.buildRange(primitives, indices, mid, end, depth + 1);

        // Append internal node.
        try self.nodes.list.appendBounded(.{
            .bbox = node_bbox,
            .link = .{ .left = left_link, .right = right_link },
        });

        // // Debug:
        // std.debug.print("internal node => {d}, ({d}, {d}), {d}\n", .{ depth, start, end, nodes.items.len });

        return &self.nodes.list.items[self.nodes.list.items.len - 1].link;
    }

    pub fn hit(self: *Bvh, primitives: []const Primitive, ray: Ray, ray_interval: Interval) ?HitRecord {
        if (self.root == null) return null;
        return hitNode(self.root.?, primitives, ray, ray_interval);
    }
};

fn hitNode(link: *Link, primitives: []const Primitive, ray: Ray, ray_interval: Interval) ?HitRecord {
    const node_ptr: *Node = @fieldParentPtr("link", link);

    if (!node_ptr.bbox.hit(ray, ray_interval)) return null;

    // Check if the ray hits the primitive.
    if (node_ptr.data) |idx| return primitives[idx].hit(ray, ray_interval);

    var closest_hit: ?HitRecord = null;
    var closest_so_far = ray_interval.max;

    // Check if the ray intersects a node in the left or right sub-trees.
    const link_fields = @typeInfo(Link).@"struct".fields;
    inline for (link_fields) |link_field| {
        const child_link: ?*Link = @field(link.*, link_field.name);
        if (child_link) |child| {
            if (hitNode(child, primitives, ray, .{ .min = ray_interval.min, .max = closest_so_far })) |hit| {
                closest_hit = hit;
                closest_so_far = hit.t;
            }
        }
    }
    return closest_hit;
}
