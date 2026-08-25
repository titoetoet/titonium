#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const vm = require("vm");

const sourcePath = path.join(__dirname, "..", "Titonium", "Modules", "MenuBar", "Clock", "LunarCalendar.js");
const context = { Math };
vm.createContext(context);
vm.runInContext(fs.readFileSync(sourcePath, "utf8"), context, { filename: sourcePath });

const fixtures = [
    [2024, 2, 10, 1, 1, 2024],
    [2025, 1, 29, 1, 1, 2025],
    [2026, 2, 17, 1, 1, 2026],
    [2023, 9, 29, 15, 8, 2023]
];

for (const [year, month, day, lunarDay, lunarMonth, lunarYear] of fixtures) {
    const actual = context.convertSolarToLunar(day, month, year, 7);
    const expected = `${lunarDay}/${lunarMonth}/${lunarYear}`;
    const received = `${actual.day}/${actual.month}/${actual.year}`;
    if (received !== expected) {
        console.error(`FAIL lunar ${year}-${month}-${day}: expected ${expected}, received ${received}`);
        process.exit(1);
    }
}

console.log(`PASS lunar fixtures (${fixtures.length})`);
