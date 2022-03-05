const std = @import("std");
const build_options = @import("build_options");

const protocol = @import("../common/protocol.zig");

const trace = build_options.trace;

pub const Activate = protocol.Activate;
pub const ArgType = protocol.ArgType;
pub const Cant = protocol.Cant;
pub const End = protocol.End;
pub const Start = protocol.Start;
pub const expectLog = protocol.expectLog;

// FIXME
pub fn Log(comptime Writer: type) type {
    return struct {
        const Self = @This();

        writer: Writer,

        pub fn cant(self: *Self, ident: u8, reason: Cant) !void {
            if (!trace) return;
            try self.writer.writeAll(&[_]u8{ @enumToInt(ArgType.Cant), ident, @enumToInt(reason) });
        }

        pub fn disabled(self: *Self, ident: u8, mslot: u8) !void {
            if (!trace) return;
            try self.writer.writeAll(&[_]u8{
                @enumToInt(ArgType.Cant),
                ident,
                @enumToInt(Cant.Disable),
                mslot,
            });
        }

        pub fn activate(self: *Self, ident: u8, reason: Activate) !void {
            if (!trace) return;
            try self.writer.writeAll(&[_]u8{
                @enumToInt(ArgType.Activate),
                ident,
                @enumToInt(reason),
            });
        }

        pub fn fieldactivate(self: *Self) !void {
            if (!trace) return;
            try self.writer.writeAll(&[_]u8{@enumToInt(ArgType.FieldActivate)});
        }

        pub fn start(self: *Self, ident: u8, reason: Start, silent: bool) !void {
            if (!trace) return;
            try self.writer.writeAll(&[_]u8{
                @enumToInt(ArgType.Start),
                ident,
                @enumToInt(reason),
                @boolToInt(silent),
            });
        }

        pub fn end(self: *Self, ident: u8, reason: End, silent: bool) !void {
            if (!trace) return;
            try self.writer.writeAll(&[_]u8{
                @enumToInt(ArgType.End),
                ident,
                @enumToInt(reason),
                @boolToInt(silent),
            });
        }

        pub fn fail(self: *Self, ident: u8, still: bool) !void {
            if (!trace) return;
            try self.writer.writeAll(&[_]u8{ @enumToInt(ArgType.Fail), ident, still });
        }

        pub fn immune(self: *Self, ident: u8) !void {
            if (!trace) return;
            try self.writer.writeAll(&[_]u8{ @enumToInt(ArgType.Immune), ident });
        }

        pub fn switched(self: *Self, ident: u8) !void {
            if (!trace) return;
            try self.writer.writeAll(&[_]u8{ @enumToInt(ArgType.Switch), ident });
        }

        pub fn turn(self: *Self, num: u16) !void {
            if (!trace) return;
            try self.writer.writeByte(@enumToInt(ArgType.Turn));
            try self.writer.writeIntNative(u16, num);
        }

        pub fn miss(self: *Self, source: u8, target: u8) !void {
            if (!trace) return;
            try self.writer.writeAll(&[_]u8{ @enumToInt(ArgType.Miss), source, target });
        }

        pub fn typechange(self: *Self, ident: u8, types: u8) !void {
            if (!trace) return;
            try self.writer.writeAll(&[_]u8{ @enumToInt(ArgType.Start), ident, types });
        }

        pub fn curestatus(self: *Self, ident: u8, status: u8, silent: bool) !void {
            if (!trace) return;
            try self.writer.writeAll(&[_]u8{
                @enumToInt(ArgType.CureStatus),
                ident,
                status,
                @boolToInt(silent),
            });
        }
    };
}

test "Log" {
    var buf = [_]u8{0} ** 3;
    var log: Log(std.io.FixedBufferStream([]u8).Writer) = .{
        .writer = std.io.fixedBufferStream(&buf).writer(),
    };

    try log.cant(1, .PartialTrap);

    try expectLog(
        &[_]u8{ @enumToInt(ArgType.Cant), 1, @enumToInt(Cant.PartialTrap) },
        &buf,
    );
}
