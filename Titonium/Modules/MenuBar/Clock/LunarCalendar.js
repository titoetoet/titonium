// Pure astronomical conversion. Months passed to and returned from this file are 1-based.
// The default timezone is Vietnam (UTC+7). No runtime I/O or mutable state is used.

function integer(value) {
    return Math.floor(value);
}

function julianDayFromDate(day, month, year) {
    var a = integer((14 - month) / 12);
    var y = year + 4800 - a;
    var m = month + 12 * a - 3;
    var jd = day + integer((153 * m + 2) / 5) + 365 * y
        + integer(y / 4) - integer(y / 100) + integer(y / 400) - 32045;
    if (jd < 2299161)
        jd = day + integer((153 * m + 2) / 5) + 365 * y + integer(y / 4) - 32083;
    return jd;
}

function newMoonDay(k, timezone) {
    var t = k / 1236.85;
    var t2 = t * t;
    var t3 = t2 * t;
    var dr = Math.PI / 180;
    var jd1 = 2415020.75933 + 29.53058868 * k + 0.0001178 * t2 - 0.000000155 * t3;
    jd1 += 0.00033 * Math.sin((166.56 + 132.87 * t - 0.009173 * t2) * dr);
    var m = 359.2242 + 29.10535608 * k - 0.0000333 * t2 - 0.00000347 * t3;
    var mpr = 306.0253 + 385.81691806 * k + 0.0107306 * t2 + 0.00001236 * t3;
    var f = 21.2964 + 390.67050646 * k - 0.0016528 * t2 - 0.00000239 * t3;
    var c1 = (0.1734 - 0.000393 * t) * Math.sin(m * dr) + 0.0021 * Math.sin(2 * m * dr);
    c1 -= 0.4068 * Math.sin(mpr * dr) + 0.0161 * Math.sin(2 * mpr * dr);
    c1 -= 0.0004 * Math.sin(3 * mpr * dr);
    c1 += 0.0104 * Math.sin(2 * f * dr) - 0.0051 * Math.sin((m + mpr) * dr);
    c1 -= 0.0074 * Math.sin((m - mpr) * dr) + 0.0004 * Math.sin((2 * f + m) * dr);
    c1 -= 0.0004 * Math.sin((2 * f - m) * dr) - 0.0006 * Math.sin((2 * f + mpr) * dr);
    c1 += 0.0010 * Math.sin((2 * f - mpr) * dr) + 0.0005 * Math.sin((2 * mpr + m) * dr);
    var deltaT = t < -11
        ? 0.001 + 0.000839 * t + 0.0002261 * t2 - 0.00000845 * t3 - 0.000000081 * t * t3
        : -0.000278 + 0.000265 * t + 0.000262 * t2;
    return integer(jd1 + c1 - deltaT + 0.5 + timezone / 24);
}

function sunLongitude(jdn, timezone) {
    var t = (jdn - 2451545.5 - timezone / 24) / 36525;
    var t2 = t * t;
    var dr = Math.PI / 180;
    var m = 357.52910 + 35999.05030 * t - 0.0001559 * t2 - 0.00000048 * t * t2;
    var l0 = 280.46645 + 36000.76983 * t + 0.0003032 * t2;
    var dl = (1.914600 - 0.004817 * t - 0.000014 * t2) * Math.sin(dr * m);
    dl += (0.019993 - 0.000101 * t) * Math.sin(2 * dr * m) + 0.000290 * Math.sin(3 * dr * m);
    var longitude = (l0 + dl) * dr;
    longitude -= Math.PI * 2 * integer(longitude / (Math.PI * 2));
    return integer(longitude / Math.PI * 6);
}

function lunarMonth11(year, timezone) {
    var off = julianDayFromDate(31, 12, year) - 2415021;
    var k = integer(off / 29.530588853);
    var nm = newMoonDay(k, timezone);
    if (sunLongitude(nm, timezone) >= 9)
        nm = newMoonDay(k - 1, timezone);
    return nm;
}

function leapMonthOffset(a11, timezone) {
    var k = integer((a11 - 2415021.076998695) / 29.530588853 + 0.5);
    var last = 0;
    var i = 1;
    var arc = sunLongitude(newMoonDay(k + i, timezone), timezone);
    do {
        last = arc;
        i += 1;
        arc = sunLongitude(newMoonDay(k + i, timezone), timezone);
    } while (arc !== last && i < 14);
    return i - 1;
}

function convertSolarToLunar(day, month, year, timezone) {
    var zone = timezone === undefined ? 7 : timezone;
    var dayNumber = julianDayFromDate(day, month, year);
    var k = integer((dayNumber - 2415021.076998695) / 29.530588853);
    var monthStart = newMoonDay(k + 1, zone);
    if (monthStart > dayNumber)
        monthStart = newMoonDay(k, zone);
    var a11 = lunarMonth11(year, zone);
    var b11 = a11;
    var lunarYear;
    if (a11 >= monthStart) {
        lunarYear = year;
        a11 = lunarMonth11(year - 1, zone);
    } else {
        lunarYear = year + 1;
        b11 = lunarMonth11(year + 1, zone);
    }
    var lunarDay = dayNumber - monthStart + 1;
    var diff = integer((monthStart - a11) / 29);
    var lunarLeap = false;
    var lunarMonth = diff + 11;
    if (b11 - a11 > 365) {
        var leapDiff = leapMonthOffset(a11, zone);
        if (diff >= leapDiff) {
            lunarMonth = diff + 10;
            if (diff === leapDiff)
                lunarLeap = true;
        }
    }
    if (lunarMonth > 12)
        lunarMonth -= 12;
    if (lunarMonth >= 11 && diff < 4)
        lunarYear -= 1;
    return {
        day: lunarDay,
        month: lunarMonth,
        year: lunarYear,
        leap: lunarLeap
    };
}
