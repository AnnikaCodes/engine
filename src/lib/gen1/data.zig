const std = @import("std");
const build_options = @import("build_options");
const builtin = @import("builtin");

const data = @import("../common/data.zig");
const protocol = @import("../common/protocol.zig");
const rng = @import("../common/rng.zig");

const moves = @import("data/moves.zig");
const species = @import("data/species.zig");
const types = @import("data/types.zig");

const mechanics = @import("mechanics.zig");

const assert = std.debug.assert;
const expectEqual = std.testing.expectEqual;
const expect = std.testing.expect;

const showdown = build_options.showdown;

pub const MAX_OPTIONS_SIZE = 9;
pub const MAX_LOG_SIZE = 100; // TODO

pub const Choice = data.Choice;
pub const Player = data.Player;
pub const Result = data.Result;

pub const Random = rng.Random(1);

pub fn Battle(comptime RNG: anytype) align(64) type {
    return extern struct {
        const Self = @This();

        sides: [2]Side,
        turn: u16 = 0,
        last_damage: u16 = 0,
        _: uX = 0,
        rng: RNG,

        pub inline fn side(self: *Self, player: Player) *Side {
            return &self.sides[@enumToInt(player)];
        }

        pub inline fn foe(self: *Self, player: Player) *Side {
            return &self.sides[@enumToInt(player.foe())];
        }

        pub fn update(self: *Self, c1: Choice, c2: Choice, log: anytype) !Result {
            return mechanics.update(self, c1, c2, switch (@typeInfo(@TypeOf(log))) {
                .Null => protocol.NULL,
                .Optional => log orelse protocol.NULL,
                else => log,
            });
        }

        pub fn choices(self: *Self, player: Player, request: Choice.Type, out: []Choice) u8 {
            return mechanics.choices(self, player, request, out);
        }
    };
}

const uX = if (showdown) u32 else u8;

test "Battle" {
    try expectEqual(384, @sizeOf(Battle(Random)));
}

pub const Side = extern struct {
    pokemon: [6]Pokemon = [_]Pokemon{.{}} ** 6,
    active: ActivePokemon = .{},
    order: [6]u8 = [_]u8{0} ** 6,
    last_selected_move: Move = .None,
    last_used_move: Move = .None,

    comptime {
        assert(@sizeOf(Side) == 184);
    }

    pub inline fn get(self: *Side, slot: u8) *Pokemon {
        assert(slot > 0 and slot <= 6);
        const id = self.order[slot - 1];
        assert(id > 0 and id <= 6);
        return &self.pokemon[id - 1];
    }

    pub inline fn stored(self: *Side) *Pokemon {
        return self.get(1);
    }
};

pub const ActivePokemon = extern struct {
    stats: Stats(u16) = .{},
    species: Species = .None,
    types: Types = .{},
    boosts: Boosts = .{},
    volatiles: Volatiles = .{},
    moves: [4]MoveSlot = [_]MoveSlot{.{}} ** 4,

    comptime {
        assert(@sizeOf(ActivePokemon) == 32);
    }

    pub inline fn ident(self: *ActivePokemon, side: *const Side, player: Player) u8 {
        _ = self;
        return player.ident(side.order[0]);
    }

    pub inline fn move(self: *ActivePokemon, mslot: u8) *MoveSlot {
        assert(mslot > 0 and mslot <= 4);
        return &self.moves[mslot - 1];
    }
};

pub const Pokemon = extern struct {
    stats: Stats(u16) = .{},
    moves: [4]MoveSlot = [_]MoveSlot{.{}} ** 4,
    hp: u16 = 0,
    status: u8 = 0,
    species: Species = .None,
    types: Types = .{},
    level: u8 = 100,

    comptime {
        assert(@sizeOf(Pokemon) == 24);
    }

    pub inline fn move(self: *Pokemon, mslot: u8) *MoveSlot {
        assert(mslot > 0 and mslot <= 4);
        return &self.moves[mslot - 1];
    }
};

pub const MoveSlot = extern struct {
    id: Move = .None,
    pp: u8 = 0,

    comptime {
        assert(@sizeOf(MoveSlot) == @sizeOf(u16));
    }
};

pub const Status = enum(u8) {
    // 0 and 1 bits are also used for SLP
    SLP = 2,
    PSN = 3,
    BRN = 4,
    FRZ = 5,
    PAR = 6,
    // NB: Gen 1 uses Volatiles.Toxic instead
    TOX = 7,

    const SLP = 0b111;
    const PSN = 0b10001000;

    pub inline fn is(num: u8, status: Status) bool {
        if (status == .SLP) return Status.duration(num) > 0;
        return ((num >> @intCast(u3, @enumToInt(status))) & 1) != 0;
    }

    pub inline fn init(status: Status) u8 {
        assert(status != .SLP);
        return @as(u8, 1) << @intCast(u3, @enumToInt(status));
    }

    pub inline fn slp(dur: u3) u8 {
        assert(dur > 0);
        return @as(u8, dur);
    }

    pub inline fn duration(num: u8) u3 {
        return @intCast(u3, num & SLP);
    }

    pub inline fn psn(num: u8) bool {
        return num & PSN != 0;
    }

    pub inline fn any(num: u8) bool {
        return num > 0;
    }
};

test "Status" {
    try expect(Status.is(Status.init(.PSN), .PSN));
    try expect(!Status.is(Status.init(.PSN), .PAR));
    try expect(Status.is(Status.init(.BRN), .BRN));
    try expect(!Status.is(Status.init(.FRZ), .SLP));
    try expect(Status.is(Status.init(.FRZ), .FRZ));
    try expect(Status.is(Status.init(.TOX), .TOX));

    try expect(!Status.is(0, .SLP));
    try expect(Status.is(Status.slp(5), .SLP));
    try expect(!Status.is(Status.slp(7), .PSN));
    try expectEqual(@as(u3, 5), Status.duration(Status.slp(5)));

    try expect(!Status.psn(Status.init(.BRN)));
    try expect(Status.psn(Status.init(.PSN)));
    try expect(Status.psn(Status.init(.TOX)));

    try expect(!Status.any(0));
    try expect(Status.any(Status.init(.TOX)));
}

pub const Volatiles = packed struct {
    Bide: bool = false,
    Thrashing: bool = false,
    MultiHit: bool = false,
    Flinch: bool = false,
    Charging: bool = false,
    Trapping: bool = false,
    Invulnerable: bool = false,
    Confusion: bool = false,

    Mist: bool = false,
    FocusEnergy: bool = false,
    Substitute: bool = false,
    Recharging: bool = false,
    Rage: bool = false,
    LeechSeed: bool = false,
    Toxic: bool = false,
    LightScreen: bool = false,

    Reflect: bool = false,
    Transform: bool = false,

    _: u2 = 0,

    attacks: u4 = 0,

    // NB: used for both bide and accuracy overwriting!
    state: u16 = 0,
    substitute: u8 = 0,
    disabled: Disabled = .{},
    confusion: u4 = 0,
    toxic: u4 = 0,

    const Disabled = packed struct {
        move: u4 = 0,
        duration: u4 = 0,
    };

    comptime {
        assert(@sizeOf(Volatiles) == 8);
    }
};

test "Volatiles" {
    if (!build_options.patched) return error.SkipZigTest;

    var volatiles = Volatiles{};
    volatiles.Confusion = true;
    volatiles.confusion = 2;
    volatiles.Thrashing = true;
    volatiles.state = 235;
    volatiles.attacks = 3;
    volatiles.Substitute = true;
    volatiles.substitute = 42;
    volatiles.toxic = 4;
    volatiles.disabled = .{ .move = 2, .duration = 4 };

    try expect(volatiles.Confusion);
    try expect(volatiles.Thrashing);
    try expect(volatiles.Substitute);
    try expect(!volatiles.Recharging);
    try expect(!volatiles.Transform);
    try expect(!volatiles.MultiHit);

    try expectEqual(@as(u16, 235), volatiles.state);
    try expectEqual(@as(u8, 42), volatiles.substitute);
    try expectEqual(@as(u4, 2), volatiles.disabled.move);
    try expectEqual(@as(u4, 4), volatiles.disabled.duration);
    try expectEqual(@as(u4, 2), volatiles.confusion);
    try expectEqual(@as(u4, 4), volatiles.toxic);
    try expectEqual(@as(u4, 3), volatiles.attacks);
}

// @test-only
pub const Stat = enum { hp, atk, def, spe, spc };

pub fn Stats(comptime T: type) type {
    return extern struct {
        hp: T = 0,
        atk: T = 0,
        def: T = 0,
        spe: T = 0,
        spc: T = 0,

        // @test-only
        pub fn calc(comptime stat: []const u8, base: T, dv: u4, exp: u16, level: u8) T {
            assert(level > 0 and level <= 100);
            const factor = if (std.mem.eql(u8, stat, "hp")) level + 10 else 5;
            return @truncate(T, (@as(u16, base) + dv) * 2 + @as(u16, (std.math.sqrt(exp) / 4)) * level / 100 + factor);
        }
    };
}

test "Stats" {
    try expectEqual(5, @sizeOf(Stats(u8)));
    const stats = Stats(u16){ .atk = 2, .spe = 3 };
    try expectEqual(2, stats.atk);
    try expectEqual(0, stats.def);
}

pub const Boosts = packed struct {
    atk: i4 = 0,
    def: i4 = 0,
    spe: i4 = 0,
    spc: i4 = 0,
    accuracy: i4 = 0,
    evasion: i4 = 0,

    // really belongs in Volatiles :(
    transform: u8 = 0,

    comptime {
        assert(@sizeOf(Boosts) == 4);
    }
};

test "Boosts" {
    const boosts = Boosts{ .spc = -6 };
    try expectEqual(0, boosts.atk);
    try expectEqual(-6, boosts.spc);
}

pub const Move = moves.Move;

test "Move" {
    try expectEqual(2, @enumToInt(Move.KarateChop));
    const move = Move.get(.Fissure);
    try expectEqual(Move.Effect.OHKO, move.effect);
    try expectEqual(@as(u8, 30), move.accuracy());
    try expectEqual(Type.Ground, move.type);

    try expect(!Move.Effect.residual1(.None));
    try expect(Move.Effect.residual1(.Confusion));
    try expect(Move.Effect.residual1(.Transform));
    try expect(!Move.Effect.residual1(.AccuracyDown1));

    try expect(!Move.Effect.residual2(.Transform));
    try expect(Move.Effect.residual2(.AccuracyDown1));
    try expect(Move.Effect.residual2(.SpeedUp2));
    try expect(!Move.Effect.residual2(.Charge));

    try expect(!Move.Effect.special(.SpeedUp2));
    try expect(Move.Effect.special(.Charge));
    try expect(Move.Effect.special(.Trapping));
    try expect(!Move.Effect.special(.AttackDownChance));
}

pub const Species = species.Species;

test "Species" {
    try expectEqual(2, @enumToInt(Species.Ivysaur));
    try expectEqual(@as(u8, 100), Species.get(.Mew).stats.def);
}

pub const Type = types.Type;
pub const Types = types.Types;

pub const Effectiveness = enum(u8) {
    Immune = 0,
    Resisted = 5,
    Neutral = 10,
    Super = 20,

    comptime {
        assert(@bitSizeOf(Effectiveness) == 8);
    }
};

test "Types" {
    try expectEqual(14, @enumToInt(Type.Dragon));
    try expectEqual(20, @enumToInt(Effectiveness.Super));

    try expect(!Type.Ghost.special());
    try expect(Type.Dragon.special());

    try expectEqual(Effectiveness.Immune, Type.effectiveness(.Ghost, .Psychic));
    try expectEqual(Effectiveness.Super, Type.Water.effectiveness(.Fire));
    try expectEqual(Effectiveness.Resisted, Type.effectiveness(.Fire, .Water));
    try expectEqual(Effectiveness.Neutral, Type.effectiveness(.Normal, .Grass));

    const t: Types = .{ .type1 = .Rock, .type2 = .Ground };
    try expect(!t.immune(.Grass));
    try expect(t.immune(.Electric));

    try expect(!t.includes(.Fire));
    try expect(t.includes(.Rock));
}

// @test-only
pub const DVs = struct {
    atk: u4 = 15,
    def: u4 = 15,
    spe: u4 = 15,
    spc: u4 = 15,

    pub fn hp(self: DVs) u4 {
        return (self.atk & 1) << 3 | (self.def & 1) << 2 | (self.spe & 1) << 1 | (self.spc & 1);
    }

    pub fn random(rand: *rng.PRNG(6)) DVs {
        return .{
            .atk = if (rand.chance(u8, 1, 5)) rand.range(u4, 1, 15 + 1) else 15,
            .def = if (rand.chance(u8, 1, 5)) rand.range(u4, 1, 15 + 1) else 15,
            .spe = if (rand.chance(u8, 1, 5)) rand.range(u4, 1, 15 + 1) else 15,
            .spc = if (rand.chance(u8, 1, 5)) rand.range(u4, 1, 15 + 1) else 15,
        };
    }
};

test "DVs" {
    var dvs = DVs{ .spc = 15, .spe = 15 };
    try expectEqual(@as(u4, 15), dvs.hp());
    dvs = DVs{
        .atk = 5,
        .def = 15,
        .spe = 13,
        .spc = 13,
    };
    try expectEqual(@as(u4, 15), dvs.hp());
    dvs = DVs{
        .def = 3,
        .spe = 10,
        .spc = 11,
    };
    try expectEqual(@as(u4, 13), dvs.hp());
}

// TODO DEBUG
comptime {
    std.testing.refAllDecls(@This());
}
