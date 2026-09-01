#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const root = path.join(__dirname, "..");
const rulesPath = path.join(root, "Titonium", "Services", "Weather", "WeatherRules.js");

if (!fs.existsSync(rulesPath)) {
    console.error("FAIL missing Titonium/Services/Weather/WeatherRules.js");
    process.exit(1);
}

const source = fs.readFileSync(rulesPath, "utf8").replace(/^\.pragma library\s*\n/, "");
const rules = vm.createContext({});
vm.runInContext(source, rules, { filename: rulesPath });

assert.equal(rules.kindForCode(113), "clear");
assert.equal(rules.kindForCode(116), "clouds");
assert.equal(rules.kindForCode(248), "fog");
assert.equal(rules.kindForCode(308), "rain");
assert.equal(rules.kindForCode(395), "snow");
assert.equal(rules.kindForCode(389), "thunderstorm");
console.log("PASS weather condition normalization");

const payload = {
    current_condition: [{
        temp_C: "31", FeelsLikeC: "35", humidity: "72", weatherCode: "116",
        windspeedKmph: "14", precipMM: "0.2",
    }],
    nearest_area: [{ areaName: [{ value: "Ho Chi Minh City" }] }],
};
const snapshot = rules.parse(payload, 14);
assert.equal(snapshot.available, true);
assert.equal(snapshot.temperatureC, 31);
assert.equal(snapshot.feelsLikeC, 35);
assert.equal(snapshot.humidity, 72);
assert.equal(snapshot.location, "Ho Chi Minh City");
assert.equal(snapshot.kind, "clouds");
assert.equal(snapshot.isDay, true);
assert.equal(snapshot.icon, "partly_cloudy_day");
console.log("PASS compact current-weather projection");

const unavailable = rules.parse({}, 2);
assert.equal(unavailable.available, false);
assert.equal(unavailable.kind, "unavailable");
assert.equal(unavailable.isDay, false);
console.log("PASS weather failure projection");
