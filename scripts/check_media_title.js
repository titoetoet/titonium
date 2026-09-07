const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const rules=vm.createContext({});
vm.runInContext(fs.readFileSync('Titonium/Bar/center/MediaTitleRules.js','utf8').replace(/^\.pragma library\s*/,''),rules);
for(const [raw,channel,want] of [
 ['Andre Rieu - The Second Waltz','','Andre Rieu - The Second Waltz'],
 ['The Second Waltz - Andre Rieu','Andre Rieu - Topic','The Second Waltz - Andre Rieu'],
 ['[Vietsub/Pinyin] Tay Trái Chỉ Trăng','','Tay Trái Chỉ Trăng'],
 ["(I Can't Get No) Satisfaction",'Rolling Stones',"(I Can't Get No) Satisfaction - Rolling Stones"],
 ['Song (Lively) [Anything]','','Song (Lively) [Anything]'],
 ['Song [Official MV] (Lyrics) #music','Artist Official','Song - Artist'],
 ['Song [HD] (Cover) 【Pinyin】','','Song'],
 ['Song - Part Two - Finale','Artist','Song - Part Two - Finale'],
 ['Xin làm người hát rong_Trần Long Ẩn','Trần Long Ẩn','Xin làm người hát rong - Trần Long Ẩn'],
 ['Song','Artist - Topic','Song - Artist'],
 ['Song','Official','Song'],
 ['[Official MV]','Artist',''],[null,'Artist',''],
 ['AC-DC - Thunderstruck','','AC-DC - Thunderstruck'],
 ['“Song”','Artist','Song - Artist']
])assert.equal(rules.formatSongDisplay(raw,channel),want,JSON.stringify([raw,channel]));
console.log('PASS metadata-aware song formatting');
