.pragma library

function finiteNumber(value, fallback) {
    var parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : fallback;
}

function text(value) {
    return typeof value === "string" ? value.replace(/\s+/g, " ").trim() : "";
}

function kindForCode(value) {
    var code = Math.round(finiteNumber(value, -1));
    if ([200, 386, 389, 392].indexOf(code) >= 0)
        return "thunderstorm";
    if ([179, 182, 185, 227, 230, 281, 284, 311, 314, 317, 320,
            323, 326, 329, 332, 335, 338, 350, 362, 365, 368, 371,
            374, 377, 395].indexOf(code) >= 0)
        return "snow";
    if ([176, 263, 266, 293, 296, 299, 302, 305, 308, 353, 356,
            359].indexOf(code) >= 0)
        return "rain";
    if ([143, 248, 260].indexOf(code) >= 0)
        return "fog";
    if ([116, 119, 122].indexOf(code) >= 0)
        return "clouds";
    if (code === 113)
        return "clear";
    return "clouds";
}

function iconFor(kind, isDay) {
    if (kind === "clear")
        return isDay ? "sunny" : "clear_night";
    if (kind === "clouds")
        return isDay ? "partly_cloudy_day" : "partly_cloudy_night";
    if (kind === "rain")
        return "rainy";
    if (kind === "fog")
        return "mist";
    if (kind === "snow")
        return "weather_snowy";
    if (kind === "thunderstorm")
        return "thunderstorm";
    return "cloud_off";
}

function unavailable(hour) {
    var normalizedHour = finiteNumber(hour, 12);
    var day = normalizedHour >= 6 && normalizedHour < 18;
    return Object.freeze({
        available: false,
        temperatureC: 0,
        feelsLikeC: 0,
        humidity: 0,
        windKph: 0,
        precipitationMm: 0,
        location: "",
        kind: "unavailable",
        icon: "cloud_off",
        isDay: day,
    });
}

function nestedValue(root, firstKey, secondKey) {
    var first = root && Array.isArray(root[firstKey]) ? root[firstKey][0] : null;
    var second = first && Array.isArray(first[secondKey]) ? first[secondKey][0] : null;
    return text(second && second.value);
}

function parse(payload, hour) {
    var current = payload && Array.isArray(payload.current_condition)
        ? payload.current_condition[0] : null;
    if (!current)
        return unavailable(hour);
    var normalizedHour = finiteNumber(hour, 12);
    var day = normalizedHour >= 6 && normalizedHour < 18;
    var kind = kindForCode(current.weatherCode);
    return Object.freeze({
        available: true,
        temperatureC: finiteNumber(current.temp_C, 0),
        feelsLikeC: finiteNumber(current.FeelsLikeC, 0),
        humidity: Math.max(0, Math.min(100, finiteNumber(current.humidity, 0))),
        windKph: Math.max(0, finiteNumber(current.windspeedKmph, 0)),
        precipitationMm: Math.max(0, finiteNumber(current.precipMM, 0)),
        location: nestedValue(payload, "nearest_area", "areaName"),
        kind: kind,
        icon: iconFor(kind, day),
        isDay: day,
    });
}
