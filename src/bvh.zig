const Link = struct {
    left: ?*Link = null,
    right: ?*Link = null,
};

pub const Node = struct {
    data: ?u32 = null, // Index into an array of primitives.
    bbox: Aabb = .empty,
    link: Link,
};

pub const Bvh = struct {
    nodes: util.BoundedList(Node),
    root: ?*Link = null,

    // DEBUG:
    const DebugStats = struct {
        max_depth: u32 = 0,
        running_depth: u32 = 0,
    };
    var dbg_stats: DebugStats = .{};

    fn initBuffer(buf: []Node) Bvh {
        return .{ .nodes = .init(buf) };
    }

    fn initCapacity(gpa: std.mem.Allocator, capacity: usize) !Bvh {
        return .{
            .nodes = try .initCapacity(gpa, capacity),
        };
    }

    pub fn deinit(self: *Bvh, gpa: std.mem.Allocator) void {
        self.nodes.deinit(gpa);
    }

    /// Returns the bounding volume hierarchy of `primitives`.
    ///
    /// The `node_buf` determines the tree capacity. Nodes and primitive
    /// indices are stored in externally initialized and managed memory.
    ///
    /// `scratch` is a buffer used to store intermediate node bounding box
    /// values during tree construction. It should have a maximum capacity of
    /// (2N - 1).
    pub fn build(node_buf: []Node, primitives: []const Primitive, indices: []u32, scratch: []Aabb) !Bvh {
        var bvh: Bvh = .initBuffer(node_buf);
        if (primitives.len == 0) return bvh;

        if (indices.len < primitives.len) return error.OutOfMemory;
        for (0..indices.len) |idx| indices[idx] = @intCast(idx);

        // DEBUG: Visualize tree traversal during formation.
        // std.debug.print("depth, (start, end), nodes:\n", .{});
        // std.debug.print("===========================\n", .{});

        bvh.root = try bvh.buildRange(
            primitives,
            indices,
            0,
            primitives.len,
            0,
            scratch[0..primitives.len],
            scratch[primitives.len..],
        );

        // DEBUG:
        const nodes = bvh.nodes.list;
        var num_leaves: u32 = 0;
        for (nodes.items) |node| {
            if (node.data) |_| {
                num_leaves += 1;
            }
        }
        std.debug.print("\nBVH Summary\n===========\n", .{});
        std.debug.print("Total nodes: {d}\n", .{nodes.items.len});
        std.debug.print("Total leaves: {d}\n", .{num_leaves});
        std.debug.print("Total internal nodes: {d}\n", .{nodes.items.len - num_leaves});
        std.debug.print("Max subtree depth: {d}\n", .{dbg_stats.max_depth});
        std.debug.print(
            "Avg subtree depth: {d}\n",
            .{@as(f32, @floatFromInt(dbg_stats.running_depth)) / @as(f32, @floatFromInt(nodes.items.len))},
        );

        return bvh;
    }

    /// Returns the bounding volume hierarchy of `primitives`.
    ///
    /// Nodes are stored in externally-managed memory, but initialized
    /// internally. The length of `primitives` determines the tree capacity. We
    /// can never have more than (2N - 1) nodes, where N is the number of
    /// primitives.
    ///
    /// Our current implementation always produces tree with the maximum
    /// possible number of nodes.
    ///
    /// Primitive indices are stored in a temporary heap-allocated buffer that
    /// is deallocated at function exit.
    ///
    /// During construction intermediate node bounding box values are stored in
    /// a temporary heap-allocated scratch buffer that is deallocated at
    /// function exit.
    pub fn buildAllocating(gpa: std.mem.Allocator, primitives: []const Primitive) !Bvh {
        var bvh: Bvh = try .initCapacity(gpa, 2 * primitives.len - 1);

        if (primitives.len == 0) return bvh;

        var indices = try gpa.alloc(u32, primitives.len);
        var scratch = try gpa.alloc(Aabb, 2 * primitives.len);
        defer {
            gpa.free(indices);
            gpa.free(scratch);
        }

        for (0..indices.len) |idx| indices[idx] = @intCast(idx);

        // DEBUG: Visualize tree traversal during formation.
        // std.debug.print("depth, (start, end), nodes:\n", .{});
        // std.debug.print("===========================\n", .{});

        bvh.root = try bvh.buildRange(
            primitives,
            indices,
            0,
            primitives.len,
            0,
            scratch[0..primitives.len],
            scratch[primitives.len..],
        );

        // DEBUG:
        const nodes = bvh.nodes.list;
        var num_leaves: u32 = 0;
        for (nodes.items) |node| {
            if (node.data) |_| {
                num_leaves += 1;
            }
        }
        std.debug.print("\nBVH Summary\n===========\n", .{});
        std.debug.print("Total nodes: {d}\n", .{nodes.items.len});
        std.debug.print("Total leaves: {d}\n", .{num_leaves});
        std.debug.print("Total internal nodes: {d}\n", .{nodes.items.len - num_leaves});
        std.debug.print("Max subtree depth: {d}\n", .{dbg_stats.max_depth});
        std.debug.print(
            "Avg subtree depth: {d}\n\n",
            .{@as(f32, @floatFromInt(dbg_stats.running_depth)) / @as(f32, @floatFromInt(nodes.items.len))},
        );

        return bvh;
    }

    fn buildRange(
        self: *Bvh,
        primitives: []const Primitive,
        indices: []u32,
        start: usize,
        end: usize,
        depth: u32,
        scratch_left: []Aabb,
        scratch_right: []Aabb,
    ) !*Link {
        // DEBUG:
        dbg_stats.max_depth = @max(dbg_stats.max_depth, depth);
        dbg_stats.running_depth += depth;

        const span = end - start;
        // std.debug.assert(scratch_left.list.capacity - scratch_left.list.items.len < span);
        // std.debug.assert(scratch_right.list.capacity - scratch_right.list.items.len < span);
        // if (scratch_left.list.capacity - scratch_left.list.items.len < span) @panic("scratch_left out of memory");
        // if (scratch_right.list.capacity - scratch_right.list.items.len < span) @panic("scratch_right out of memory");
        if (scratch_left.len < span) @panic("scratch_left out of memory");
        if (scratch_right.len < span) @panic("scratch_right out of memory");

        // Append leaf.
        if (span == 1) {
            try self.nodes.list.appendBounded(.{
                .data = indices[start],
                .bbox = primitives[indices[start]].bbox(),
                .link = .{},
            });

            // DEBUG:
            // std.debug.print("leaf index {d}! ==> {d}, ({d}, {d}), {d}\n", .{ indices[start], depth, start, end, self.nodes.list.items.len });

            return &self.nodes.list.items[self.nodes.list.items.len - 1].link;
        }

        // Compute the bounding box enclosing all the scene primitives in this node.
        var node_bbox: Aabb = .empty;
        for (indices[start..end]) |idx| node_bbox = .fromEnclosedBoxes(
            node_bbox,
            primitives[idx].bbox(),
        );

        // Sort slice of scene primitive indices by the primitives' bounding
        // box centroids, along the node bounding box's longest axis.
        const SortContext = struct { split_axis: usize, primitives: []const Primitive };
        std.mem.sort(
            u32,
            indices[start..end],
            SortContext{ .split_axis = node_bbox.longestAxis(), .primitives = primitives },
            struct {
                fn lessThan(ctx: SortContext, a: u32, b: u32) bool {
                    const centroid_a = ctx.primitives[a].bbox().centroid()[ctx.split_axis];
                    const centroid_b = ctx.primitives[b].bbox().centroid()[ctx.split_axis];
                    return centroid_a < centroid_b;
                }
            }.lessThan,
        );

        // DEBUG:
        // std.debug.print("{d}, ({d}, {d}), {d}\n", .{ depth, start, end, self.nodes.list.items.len });

        // Prefix sweep (left to right).
        var candidate_partition_bbox: Aabb = .empty;
        for (0..span) |i| {
            candidate_partition_bbox = .fromEnclosedBoxes(candidate_partition_bbox, primitives[indices[start + i]].bbox());
            scratch_left[i] = candidate_partition_bbox;
        }

        // Suffix sweep (right to left).
        var right_sweep_idx: usize = span;
        candidate_partition_bbox = .empty;
        while (right_sweep_idx > 0) : (right_sweep_idx -= 1) {
            candidate_partition_bbox = .fromEnclosedBoxes(
                candidate_partition_bbox,
                primitives[indices[start + right_sweep_idx - 1]].bbox(),
            );
            scratch_right[right_sweep_idx - 1] = candidate_partition_bbox;
        }

        // Evaluate surface area heuristic (SAH) split cost for each partition.
        const reciprocal_parent_area: f64 = 1.0 / node_bbox.surfaceArea();
        var best_split_cost: f64 = vec.infinity;
        var best_split_index: usize = 0;
        for (1..span) |i| {
            const left_partition_area: f64 = scratch_left[i - 1].surfaceArea();
            const right_partition_area: f64 = scratch_right[i].surfaceArea();
            const curr_split_cost: f64 = 1.0 + (left_partition_area * @as(f64, @floatFromInt(i)) + right_partition_area * @as(f64, @floatFromInt(span - i))) * reciprocal_parent_area;

            if (curr_split_cost < best_split_cost) {
                best_split_cost = curr_split_cost;
                best_split_index = i;
            }
            // DEBUG:
            // std.debug.print("\tleft SA: {e:.4}\n", .{left_partition_area});
            // std.debug.print("\tright SA: {e:.4}\n", .{right_partition_area});
            // std.debug.print("\tcurrent cost => best cost: {d:.4} => {d:.4}\n", .{ cost, best_cost });
            // std.debug.print("\tcurrent idx, best idx: {d}, {d}\n", .{ i, best_index });
        }

        // Fallback to a split at the median on the largest axis.
        if (best_split_index == 0) best_split_index = span / 2;
        const split_index = start + best_split_index; // start + span / 2;

        const left_link = try self.buildRange(primitives, indices, start, split_index, depth + 1, scratch_left, scratch_right);
        const right_link = try self.buildRange(primitives, indices, split_index, end, depth + 1, scratch_left, scratch_right);

        // Append internal node.
        try self.nodes.list.appendBounded(.{
            .bbox = node_bbox,
            .link = .{ .left = left_link, .right = right_link },
        });

        // DEBUG:
        // std.debug.print("internal node => {d}, ({d}, {d}), {d}\n", .{ depth, start, end, self.nodes.list.items.len });

        return &self.nodes.list.items[self.nodes.list.items.len - 1].link;
    }

    // We avoid recursive tree traversal using an iterative stack traversal.
    // This approach leverages the fact that nodes are stored in depth-first
    // order, and are thus adjacent in memory.
    //
    // Depending on the ray's direction along the split axis, we sort left and
    // right children according to the most likely child to be hit.
    //
    // NOTE: For a binary BVH, the maximum depth is ~2*log2(N) for N
    // primitives.
    //
    // For 1_000_000 primitives, the maximum BVH depth is ~40, so a stack size
    // of 128 is usually safe. We can choose a safety factor of 4-5x to make
    // stack overflow highly unlikely.
    pub fn stackHit(self: *Bvh, rng: *std.Random, primitives: []const Primitive, ray: Ray, ray_interval: Interval) !?HitRecord {
        if (self.root == null) return null;

        var buf: [32]*Link = undefined;
        var stack: util.BoundedList(*Link) = .init(&buf);
        try stack.list.appendBounded(self.root.?);

        var closest_hit: ?HitRecord = null;
        var closest_dist_so_far = ray_interval.max;

        while (stack.list.pop()) |link| {
            const node: *Node = @fieldParentPtr("link", link);

            if (!node.bbox.hit(ray, .{ .min = ray_interval.min, .max = closest_dist_so_far })) continue;

            if (node.data) |prim_idx| {
                if (primitives[prim_idx].hit(rng, ray, .{ .min = ray_interval.min, .max = closest_dist_so_far })) |h| {
                    closest_hit = h;
                    closest_dist_so_far = h.t;
                }
            } else {
                // Internal node: determine the likely-hit child.
                if (link.left) |left_link| {
                    if (link.right) |right_link| {
                        var near_child: *Link = left_link;
                        var far_child: *Link = right_link;

                        const split_axis = node.bbox.longestAxis();

                        // Only swap if both children exist and the ray direction is negative.
                        if (ray.direction[split_axis] < 0.0) {
                            near_child = right_link;
                            far_child = left_link;
                        }

                        // Push _far_ then _near_ child, so the nearest child is popped next.
                        try stack.list.appendBounded(far_child);
                        try stack.list.appendBounded(near_child);
                    } else {
                        // Only the left child exists - push the existing child.
                        try stack.list.appendBounded(left_link);
                    }
                } else if (link.right) |right_link| {
                    // Only the right child exists - push the existing child.
                    try stack.list.appendBounded(right_link);
                }
            }
        }

        return closest_hit;
    }

    pub fn recursiveHit(self: *Bvh, rng: *std.Random, primitives: []const Primitive, ray: Ray, ray_interval: Interval) ?HitRecord {
        if (self.root == null) return null;
        return hitNode(rng, self.root.?, primitives, ray, ray_interval);
    }

    fn hitNode(rng: *std.Random, link: *Link, primitives: []const Primitive, ray: Ray, ray_interval: Interval) ?HitRecord {
        const node_ptr: *Node = @fieldParentPtr("link", link);

        if (!node_ptr.bbox.hit(ray, ray_interval)) return null;

        if (node_ptr.data) |idx| return primitives[idx].hit(rng, ray, ray_interval);

        var closest_hit: ?HitRecord = null;
        var closest_dist_so_far = ray_interval.max;

        // Check if the ray intersects a node bounding box in the left or right sub-trees.
        const link_fields = @typeInfo(Link).@"struct".fields;
        inline for (link_fields) |link_field| {
            const child_link: ?*Link = @field(link.*, link_field.name);
            if (child_link) |child| {
                if (hitNode(rng, child, primitives, ray, .{ .min = ray_interval.min, .max = closest_dist_so_far })) |h| {
                    closest_hit = h;
                    closest_dist_so_far = h.t;
                }
            }
        }
        return closest_hit;
    }
};

const std = @import("std");

const Aabb = @import("AxisAlignedBoundingBox.zig");
const hittable = @import("hittable.zig");
const HitRecord = hittable.HitRecord;
const Primitive = hittable.Primitive;
const Interval = @import("Interval.zig");
const Ray = @import("Ray.zig");
const util = @import("util.zig");
const vec = @import("vec.zig");
const Vec3 = vec.Vec3;
