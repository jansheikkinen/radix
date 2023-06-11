// main.zig

const std = @import("std");

pub const RadixInteger = struct {
  // NOTE: for consistency, base 64 does NOT match the standards
  const DIGIT_CHARS = "0123456789" ++
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ" ++
    "abcdefghijklmnopqrstuvwxyz+/";

  radix: u8 = 10,
  value: isize,

  pub fn init(radix: u8, value: isize) !RadixInteger {
    if (radix < 2 or radix > 64) return error.InvalidRadix;
    return RadixInteger { .radix = radix, .value = value };
  }

  pub fn initValue(value: isize) RadixInteger {
    return RadixInteger { .value = value };
  }



  fn isDelimiter(c: u8) bool {
    return c == 'r';
  }

  fn isNumeric(c: u8) bool {
    return c >= '0' and c <= '9';
  }

  fn isValidDigit(c: u8, radix: u8) bool {
    var index: usize = 0;
    return while (index < radix) : (index += 1) {
      if (c == DIGIT_CHARS[index]) return true;
    } else false;
  }

  fn getDigitValue(digit: u8) !u8 {
    var index: u8 = 0;
    return while (index < DIGIT_CHARS.len) : (index += 1) {
      if (digit == DIGIT_CHARS[index]) return index;
    } else error.InvalidDigit;
  }

  fn parseRadix(string: []const u8) !u8 {
    var index: usize = 0;
    var radix: u8 = 0;
    while (index < string.len) : (index += 1) {
      if (!isNumeric(string[index])) return error.InvalidDigit;

      radix *= 10;
      radix += string[index] - 48;
    }

    return radix;
  }

  fn parseValue(string: []const u8, radix: u8) !isize {
    var index: usize = 0;
    var value: isize = 0;
    while (index < string.len) : (index += 1) {
      if (!isValidDigit(string[index], radix)) return error.InvalidDigit;

      value *= radix;
      value += try getDigitValue(string[index]);
    }

    return value;
  }

  // syntax rules are as follows:
  // NUMBER = [ "-" ] [ RADIX "r" ] VALUE
  // RADIX = "0" .. "9"
  // VALUE = "0" .. "9", "A" .. "Z", "a" .. "z"
  pub fn fromString(string: []const u8) !RadixInteger {
    if (string.len < 1) return error.EmptyString;
    if (string[string.len - 1] == 'r') return error.MissingValue;
    var index: usize = 0;

    var isPositive: bool = undefined;
    if (string[index] == '-') {
      index += 1;
      isPositive = false;
    } else {
      isPositive = true;
    }

    const delimiter = while (index < string.len) : (index += 1) {
      if (isDelimiter(string[index])) break index;
    } else null;

    if (delimiter) |dindex| {
      if ( isPositive and string[0] == 'r') return error.MissingRadix;
      if (!isPositive and string[1] == 'r') return error.MissingRadix;

      const radix = try parseRadix(string[if (isPositive) 0 else 1..dindex]);
      const value = try parseValue(string[dindex + 1..], radix);
      return init(radix, if (isPositive) value else -value);
    } else {
      const value = try parseValue(string, 10);
      return initValue(if (isPositive) value else -value);
    }
  }


  pub fn toString(self: *const RadixInteger, allocator: std.mem.Allocator) ![]u8 {
    var digits = std.ArrayList(u8).init(allocator);
    defer digits.deinit();

    const isPositive = self.value >= 0;
    var remainder: usize = std.math.absCast(self.value);
    while (remainder > 0) {
      try digits.append(DIGIT_CHARS[@rem(remainder, self.radix)]);
      remainder /= self.radix;
    }

    try digits.append('r');

    remainder = self.radix;
    while (remainder > 0) {
      try digits.append(DIGIT_CHARS[@rem(remainder, 10)]);
      remainder /= 10;
    }

    if (!isPositive) try digits.append('-');

    std.mem.reverse(u8, digits.items);
    return digits.toOwnedSlice();
  }
};


const testing = std.testing;

test "Radix Out of Bound" {
  try testing.expectError(error.InvalidRadix, RadixInteger.init(1, 0));
  try testing.expectError(error.InvalidRadix, RadixInteger.init(65, 0));
}


test "fromString -- Empty String" {
  try testing.expectError(error.EmptyString, RadixInteger.fromString(""));
}

test "fromString -- Invalid Digit for Given Radix" {
  try testing.expectError(error.InvalidDigit, RadixInteger.fromString("2r2"));
}

test "fromString -- Missing Value" {
  try testing.expectError(error.MissingValue, RadixInteger.fromString("10r"));
}

test "fromString -- Missing Radix" {
  try testing.expectError(error.MissingRadix, RadixInteger.fromString("r69"));
  try testing.expectError(error.MissingRadix, RadixInteger.fromString("-r69"));
}

test "fromString -- Radix Digit Counts" {
  try testing.expectEqual((try RadixInteger.fromString("9r8")).value, 8);
  try testing.expectEqual((try RadixInteger.fromString("10r9")).value, 9);
}

test "fromString -- Value Digit Counts" {
  try testing.expectEqual((try RadixInteger.fromString("16rA")).value, 10);
  try testing.expectEqual((try RadixInteger.fromString("16rAB")).value, 171);
  try testing.expectEqual((try RadixInteger.fromString("16rABC")).value, 2748);
}

test "fromString -- Smallest and Largest Radix" {
  try testing.expectEqual((try RadixInteger.fromString("2r1000101")).value, 69);
  try testing.expectEqual((try RadixInteger.fromString("64rz+/")).value, 253887);
}

test "fromString -- Implicit Radix" {
  try testing.expectEqual((try RadixInteger.fromString("69")).value, 69);
}

test "fromString -- Explicit Radix" {
  try testing.expectEqual((try RadixInteger.fromString("10r69")).value, 69);
}

test "fromString -- Negative" {
  try testing.expectEqual((try RadixInteger.fromString("-10r69")).value, -69);
}

test "fromString -- Leading Zeroes" {
  try testing.expectEqual((try RadixInteger.fromString("10r01")).value, 1);
  try testing.expectEqual((try RadixInteger.fromString("10r000001")).value, 1);
}

test "toString -- Smallest and Largest Radix" {
  var number = try RadixInteger.init(2, 69);
  var string = try number.toString(testing.allocator);
  try testing.expectEqualStrings(string, "2r1000101");
  testing.allocator.free(string);

  number = try RadixInteger.init(64, 253887);
  string = try number.toString(testing.allocator);
  try testing.expectEqualStrings(string, "64rz+/");
  testing.allocator.free(string);
}

test "toString -- Negative" {
  const number = try RadixInteger.init(10, -420);
  const string = try number.toString(testing.allocator);
  try testing.expectEqualStrings(string, "-10r420");
  testing.allocator.free(string);
}
