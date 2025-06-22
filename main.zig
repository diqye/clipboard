const std = @import("std");
const argsParser = @import("args");

extern fn getClipboardText() ?[*:0]const u8;
extern fn setClipboardText(text: [*:0]const u8) void;

const Entry = struct {
    data: std.StringArrayHashMap([] const u8),
    file: std.fs.File,
    arena: std.heap.ArenaAllocator,


    const Self = @This();
    pub fn init(a:std.mem.Allocator)!Self {
        const app_path = try std.fs.getAppDataDir(a, "d-clipboard/.bin");
        defer a.free(app_path);
        std.fs.makeDirAbsolute(std.fs.path.dirname(app_path).?) catch {};
        return .{
            .arena = std.heap.ArenaAllocator.init(a),
            .file = std.fs.openFileAbsolute(app_path, .{ 
                .mode = .read_write
            }) catch |err| switch (err) {
                error.FileNotFound => try std.fs.createFileAbsolute(app_path, .{ .truncate = true}) ,
                else => return err,
            },
            .data = .init(a),
        };
    }

    pub fn deinit(self:*Self) void {
        self.file.close();
        self.data.deinit();
        self.arena.deinit();
    }

    fn readAll(self: *Self) !void {
        while (try self.readData()) |data| {
            try self.data.put(data.@"0", data.@"1");
        }
    }
    /// 读取数据赋值给self.data,回收原有data的内存
    fn readData(self: *Self) !?struct {[]u8,[]u8} {
        const end = try self.file.getEndPos();
        const current = try self.file.getPos();
        const allocator = self.arena.allocator();
        if(current == end) {
            return null;
        }
        var name:[]  u8 = undefined;
        var value:[] u8 = undefined;
        {
            var buffer : [2]u8  = undefined;
            _ = try self.file.readAll(&buffer);
            const len : u16 = std.mem.readPackedInt(u16, &buffer, 0, .big);
            name = try allocator.alloc(u8, len);
            _ = try self.file.readAll(name);
        }
        {
            var buffer : [2]u8  = undefined;
            _ = try self.file.readAll(&buffer);
            const len : u16 = std.mem.readPackedInt(u16, &buffer, 0, .big);
            value = try allocator.alloc(u8, len);
            _ = try self.file.readAll(value);
        }
        return .{name,value};
    }
    /// 写入文件
    pub fn writeAll(self:*Self)!void {
        const allocator = self.arena.allocator();
        try self.file.setEndPos(0);
        try self.file.seekFromEnd(0);
        var iterator = self.data.iterator();
        while (iterator.next()) |entry| {
            const key = entry.key_ptr.*;
            const value = entry.value_ptr.*;
            const name_len = key.len;
            const value_len = value.len;
            const total = name_len + value_len + 4;
            const buffer = try allocator.alloc(u8, total);
            defer allocator.free(buffer);
            var name_len_buffer: [2] u8 = undefined;
            std.mem.writePackedInt(u16, &name_len_buffer, 0, @intCast(name_len), .big);
            var value_len_buffer: [2] u8 = undefined;
            std.mem.writePackedInt(u16, &value_len_buffer, 0, @intCast(value_len), .big);
            @memcpy(buffer[0..2], &name_len_buffer);
            @memcpy(buffer[2..2+name_len], key);
            @memcpy(buffer[2+name_len..2+2+name_len], &value_len_buffer);
            @memcpy(buffer[2+2+name_len..], value);
            try self.file.writeAll(buffer);
        }
     }

};

test Entry {
    const act = std.testing.allocator;
    var entry = try Entry.init(act);
    defer entry.deinit();

    try entry.readAll();
    try entry.data.put("key: []const u8", "value: []u8");
    try entry.writeAll();
    
    std.debug.print("{s}\n", .{entry.data.get("key: []const u8").?});
}
fn errHanding(err: argsParser.Error) anyerror!void {
    std.debug.print("{}",.{err});
}
pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const options = argsParser.parseForCurrentProcess(struct {
        print: bool = false,
        write: [] const u8 = "",
        key: [] const u8 = "",
        value: [] const u8 = "",
        delete: bool = false,

        // This declares short-hand options for single hyphen
        pub const shorthands = .{
            .P = "print",
            .W = "write",
            .K = "key",
            .V = "value",
            .D = "delete"
        };
    }, allocator, .{
        .forward = errHanding,
    }) catch |e| return e;
    defer options.deinit();


    if(options.positionals.len != 0) {
        const help = \\{?s}:
        \\ --print  [-p]        打印当前剪切板文本
        \\ --write  [-W] text   写入内容到剪切板
        \\ --key    [-K] key    读取已经存储的内容到剪切板
        \\ --value  [-V] text   存储到本地和--key同时使用
        \\ --delete [-D]        删除key和--key同时使用
        \\
        ;
        std.debug.print(help, .{options.executable_name});
        std.process.exit(0);
    } else if(options.options.print){
        const text = getClipboardText() orelse "";
        std.debug.print("{s}\n", .{text});
    } else if(options.options.write.len != 0) {
        const c_str = try allocator.dupeZ(u8, options.options.write);
        defer allocator.free(c_str);
        setClipboardText(c_str.ptr);
    } else if(options.options.key.len != 0) {
        var entry = try Entry.init(allocator);
        defer entry.deinit();
        try entry.readAll();

        if(options.options.value.len != 0) {
            try entry.data.put(options.options.key, options.options.value);
        } else if(options.options.delete) {
            _ = entry.data.orderedRemove(options.options.key);
        } else {
            const text = entry.data.get(options.options.key) orelse @panic("没有这个key");
            const c_text = try allocator.dupeZ(u8, text);
            defer allocator.free(c_text);
            setClipboardText(c_text);
        }
        
        try entry.writeAll();
    }
}


