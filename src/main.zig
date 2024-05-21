const std = @import("std");

pub fn main() !void {
    const stdout_file = std.io.getStdOut();
    var bw = std.io.bufferedWriter(stdout_file.writer());
    const stdout = bw.writer();

    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const board = try allocator.alloc([]bool, 20);
    defer allocator.free(board);
    for (board) |*line| {
        line.* = try allocator.alloc(bool, 20);
    }
    defer {
        for (board) |line| allocator.free(line);
    }

    var r = std.rand.DefaultPrng.init(@abs(std.time.microTimestamp()));
    const rand = r.random();

    // initialize
    for (board) |row| {
        for (row) |*cell| {
            cell.* = rand.boolean();
        }
    }

    while (true) {
        const string = stringFromBoard(board);
        var clear = std.process.Child.init(&.{"clear"}, allocator);
        _ = try clear.spawnAndWait();
        for (&string) |*line| {
            try stdout.print("{s}\n", .{line});
        }
        try bw.flush();
        var new: [20][20]bool = undefined;
        for (0..board.len) |x| {
            for (0..board.len) |y| {
                const count = countNeighbors(board, @intCast(x), @intCast(y)).?;
                new[x][y] = next(board[x][y], count);
            }
        }
        for (board, 0..) |line, i| {
            @memcpy(line, &new[i]);
        }
        std.time.sleep(std.time.ns_per_s);
    }
}

const alive = "👽";
const dead = "💀";

fn stringFromBoard(board: []const []const bool) [20][20 * 4]u8 {
    var output: [20][20 * 4]u8 = undefined;
    for (board, &output) |row, *board_row| {
        for (row, 0..) |cell, i| {
            @memcpy(board_row[4 * i ..][0..4], if (cell) alive else dead);
        }
    }
    return output;
}

fn countNeighbors(board: []const []const bool, x_idx: i32, y_idx: i32) ?u8 {
    if (x_idx >= @as(i32, @intCast(board.len)) or x_idx < 0) return null;
    if (y_idx >= @as(i32, @intCast(board[@intCast(x_idx)].len)) or y_idx < 0) return null;
    const offsets: [8][2]i32 = .{
        .{ -1, -1 }, .{ -1, 0 }, .{ -1, 1 },
        .{ 0, -1 },  .{ 0, 1 },  .{ 1, -1 },
        .{ 1, 0 },   .{ 1, 1 },
    };
    var ret: u8 = 0;
    for (offsets) |offset| {
        const check_x = x_idx + offset[0];
        const check_y = y_idx + offset[1];
        if (check_x >= @as(i32, @intCast(board.len)) or check_x < 0) continue;
        if (check_y >= @as(i32, @intCast(board[@intCast(x_idx)].len)) or check_y < 0) continue;
        if (board[@intCast(check_x)][@intCast(check_y)]) ret += 1;
    }
    return ret;
}

test "countNeighbors" {
    const board: []const []const bool = &.{
        &.{ true, false, false },
        &.{ false, true, false },
        &.{ false, false, true },
    };
    const counts: []const []const u8 = &.{
        &.{ 1, 2, 1 },
        &.{ 2, 2, 2 },
        &.{ 1, 2, 1 },
    };
    for (0..board.len, counts) |x, counts_inner| {
        for (0..board[x].len, counts_inner) |y, expected| {
            const count = countNeighbors(board, @intCast(x), @intCast(y)).?;
            try std.testing.expectEqual(expected, count);
        }
    }
}

fn next(state: bool, neighbors_count: u8) bool {
    if (neighbors_count < 2) return false;
    if (neighbors_count == 3) return true;
    if (neighbors_count > 3) return false;
    return state;
}
