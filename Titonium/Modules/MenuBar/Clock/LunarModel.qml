pragma Singleton

import QtQuick
import "LunarCalendar.js" as Lunar

QtObject {
    readonly property var stems: ["Giáp", "Ất", "Bính", "Đinh", "Mậu", "Kỷ", "Canh", "Tân", "Nhâm", "Quý"]
    readonly property var branches: ["Tý", "Sửu", "Dần", "Mão", "Thìn", "Tỵ", "Ngọ", "Mùi", "Thân", "Dậu", "Tuất", "Hợi"]

    function forDate(date: date): var {
        const result = Lunar.convertSolarToLunar(date.getDate(), date.getMonth() + 1, date.getFullYear(), 7);
        result.yearName = stems[(result.year + 6) % 10] + " " + branches[(result.year + 8) % 12];
        return result;
    }
}
