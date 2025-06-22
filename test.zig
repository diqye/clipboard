const std = @import("std");

pub fn main() !void {
}

test "tranlsate" {
    var buffer : [@sizeOf(u16)] u8 = undefined;
    std.mem.writePackedInt(u16, &buffer,0, 7888, .big);
    std.debug.print("{any}\n", .{buffer});
    const v_usize = std.mem.readPackedInt(u16, &buffer,0, .big);
    std.debug.print("{}", .{v_usize});
}
