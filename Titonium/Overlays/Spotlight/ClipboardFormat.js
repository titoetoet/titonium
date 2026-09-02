.pragma library

function md5(string) {
    if (typeof string !== "string" || string.length === 0)
        return "d41d8cd98f00b204e9800998ecf8427e";

    function rotateLeft(lValue, iShiftBits) {
        return (lValue << iShiftBits) | (lValue >>> (32 - iShiftBits));
    }
    function addUnsigned(lX, lY) {
        var lX4 = lX & 0x40000000, lY4 = lY & 0x40000000;
        var lX8 = lX & 0x80000000, lY8 = lY & 0x80000000;
        var lResult = (lX & 0x3FFFFFFF) + (lY & 0x3FFFFFFF);
        if (lX4 & lY4) return lResult ^ 0x80000000 ^ lX8 ^ lY8;
        if (lX4 | lY4) {
            if (lResult & 0x40000000) return lResult ^ 0xC0000000 ^ lX8 ^ lY8;
            return lResult ^ 0x40000000 ^ lX8 ^ lY8;
        }
        return lResult ^ lX8 ^ lY8;
    }
    function F(x, y, z) { return (x & y) | ((~x) & z); }
    function G(x, y, z) { return (x & z) | (y & (~z)); }
    function H(x, y, z) { return x ^ y ^ z; }
    function I(x, y, z) { return y ^ (x | (~z)); }
    function FF(a, b, c, d, x, s, ac) {
        a = addUnsigned(a, addUnsigned(addUnsigned(F(b, c, d), x), ac));
        return addUnsigned(rotateLeft(a, s), b);
    }
    function GG(a, b, c, d, x, s, ac) {
        a = addUnsigned(a, addUnsigned(addUnsigned(G(b, c, d), x), ac));
        return addUnsigned(rotateLeft(a, s), b);
    }
    function HH(a, b, c, d, x, s, ac) {
        a = addUnsigned(a, addUnsigned(addUnsigned(H(b, c, d), x), ac));
        return addUnsigned(rotateLeft(a, s), b);
    }
    function II(a, b, c, d, x, s, ac) {
        a = addUnsigned(a, addUnsigned(addUnsigned(I(b, c, d), x), ac));
        return addUnsigned(rotateLeft(a, s), b);
    }
    function convertToWordArray(str) {
        var lWordCount;
        var lMessageLength = str.length;
        var lNumberOfWordsTemp1 = lMessageLength + 8;
        var lNumberOfWordsTemp2 = (lNumberOfWordsTemp1 - (lNumberOfWordsTemp1 % 64)) / 64;
        var lNumberOfWords = (lNumberOfWordsTemp2 + 1) * 16;
        var lWordArray = Array(lNumberOfWords - 1);
        for (var i = 0; i < lNumberOfWords; i++) lWordArray[i] = 0;
        var lBytePosition = 0;
        var lByteCount = 0;
        while (lByteCount < lMessageLength) {
            lWordCount = (lByteCount - (lByteCount % 4)) / 4;
            lBytePosition = (lByteCount % 4) * 8;
            lWordArray[lWordCount] = (lWordArray[lWordCount] | (str.charCodeAt(lByteCount) << lBytePosition));
            lByteCount++;
        }
        lWordCount = (lByteCount - (lByteCount % 4)) / 4;
        lBytePosition = (lByteCount % 4) * 8;
        lWordArray[lWordCount] = lWordArray[lWordCount] | (0x80 << lBytePosition);
        lWordArray[lNumberOfWords - 2] = lMessageLength << 3;
        lWordArray[lNumberOfWords - 1] = lMessageLength >>> 29;
        return lWordArray;
    }
    function wordToHex(lValue) {
        var wordToHexValue = "", wordToHexValueTemp = "", lByte, lCount;
        for (lCount = 0; lCount <= 3; lCount++) {
            lByte = (lValue >>> (lCount * 8)) & 255;
            wordToHexValueTemp = "0" + lByte.toString(16);
            wordToHexValue = wordToHexValue + wordToHexValueTemp.substr(wordToHexValueTemp.length - 2, 2);
        }
        return wordToHexValue;
    }
    function utf8Encode(str) {
        str = str.replace(/\r\n/g, "\n");
        var utftext = "";
        for (var n = 0; n < str.length; n++) {
            var c = str.charCodeAt(n);
            if (c < 128) {
                utftext += String.fromCharCode(c);
            } else if (c > 127 && c < 2048) {
                utftext += String.fromCharCode((c >> 6) | 192);
                utftext += String.fromCharCode((c & 63) | 128);
            } else {
                utftext += String.fromCharCode((c >> 12) | 224);
                utftext += String.fromCharCode(((c >> 6) & 63) | 128);
                utftext += String.fromCharCode((c & 63) | 128);
            }
        }
        return utftext;
    }

    var encoded = utf8Encode(string);
    var x = convertToWordArray(encoded);
    var a = 0x67452301, b = 0xEFCDAB89, c = 0x98BADCFE, d = 0x10325476;
    var S11 = 7, S12 = 12, S13 = 17, S14 = 22;
    var S21 = 5, S22 = 9, S23 = 14, S24 = 20;
    var S31 = 4, S32 = 11, S33 = 16, S34 = 23;
    var S41 = 6, S42 = 10, S43 = 15, S44 = 21;

    for (var k = 0; k < x.length; k += 16) {
        var AA = a, BB = b, CC = c, DD = d;
        a = FF(a, b, c, d, x[k + 0], S11, 0xD76AA478);
        d = FF(d, a, b, c, x[k + 1], S12, 0xE8C7B756);
        c = FF(c, d, a, b, x[k + 2], S13, 0x242070DB);
        b = FF(b, c, d, a, x[k + 3], S14, 0xC1BDCEEE);
        a = FF(a, b, c, d, x[k + 4], S11, 0xF57C0FAF);
        d = FF(d, a, b, c, x[k + 5], S12, 0x4787C62A);
        c = FF(c, d, a, b, x[k + 6], S13, 0xA8304613);
        b = FF(b, c, d, a, x[k + 7], S14, 0xFD469501);
        a = FF(a, b, c, d, x[k + 8], S11, 0x698098D8);
        d = FF(d, a, b, c, x[k + 9], S12, 0x8B44F7AF);
        c = FF(c, d, a, b, x[k + 10], S13, 0xFFFF5BB1);
        b = FF(b, c, d, a, x[k + 11], S14, 0x895CD7BE);
        a = FF(a, b, c, d, x[k + 12], S11, 0x6B901122);
        d = FF(d, a, b, c, x[k + 13], S12, 0xFD987193);
        c = FF(c, d, a, b, x[k + 14], S13, 0xA679438E);
        b = FF(b, c, d, a, x[k + 15], S14, 0x49B40821);
        a = GG(a, b, c, d, x[k + 1], S21, 0xF61E2562);
        d = GG(d, a, b, c, x[k + 6], S22, 0xC040B340);
        c = GG(c, d, a, b, x[k + 11], S23, 0x265E5A51);
        b = GG(b, c, d, a, x[k + 0], S24, 0xE9B6C7AA);
        a = GG(a, b, c, d, x[k + 5], S21, 0xD62F105D);
        d = GG(d, a, b, c, x[k + 10], S22, 0x02441453);
        c = GG(c, d, a, b, x[k + 15], S23, 0xD8A1E681);
        b = GG(b, c, d, a, x[k + 4], S24, 0xE7D3FBC8);
        a = GG(a, b, c, d, x[k + 9], S21, 0x21E1CDE6);
        d = GG(d, a, b, c, x[k + 14], S22, 0xC33707D6);
        c = GG(c, d, a, b, x[k + 3], S23, 0xF4D50D87);
        b = GG(b, c, d, a, x[k + 8], S24, 0x455A14ED);
        a = GG(a, b, c, d, x[k + 13], S21, 0xA9E3E905);
        d = GG(d, a, b, c, x[k + 2], S22, 0xFCEFA3F8);
        c = GG(c, d, a, b, x[k + 7], S23, 0x676F02D9);
        b = GG(b, c, d, a, x[k + 12], S24, 0x8D2A4C8A);
        a = HH(a, b, c, d, x[k + 5], S31, 0xFFFA3942);
        d = HH(d, a, b, c, x[k + 8], S32, 0x8771F681);
        c = HH(c, d, a, b, x[k + 11], S33, 0x6D9D6122);
        b = HH(b, c, d, a, x[k + 14], S34, 0xFDE5380C);
        a = HH(a, b, c, d, x[k + 1], S31, 0xA4BEEA44);
        d = HH(d, a, b, c, x[k + 4], S32, 0x4BDECFA9);
        c = HH(c, d, a, b, x[k + 7], S33, 0xF6BB4B60);
        b = HH(b, c, d, a, x[k + 10], S34, 0xBEBFBC70);
        a = HH(a, b, c, d, x[k + 13], S31, 0x289B7EC6);
        d = HH(d, a, b, c, x[k + 0], S32, 0xEAA127FA);
        c = HH(c, d, a, b, x[k + 3], S33, 0xD4EF3085);
        b = HH(b, c, d, a, x[k + 6], S34, 0x04881D05);
        a = HH(a, b, c, d, x[k + 9], S31, 0xD9D4D039);
        d = HH(d, a, b, c, x[k + 12], S32, 0xE6DB99E5);
        c = HH(c, d, a, b, x[k + 15], S33, 0x1FA27CF8);
        b = HH(b, c, d, a, x[k + 2], S34, 0xC4AC5665);
        a = II(a, b, c, d, x[k + 0], S41, 0xF4292244);
        d = II(d, a, b, c, x[k + 7], S42, 0x432AFF97);
        c = II(c, d, a, b, x[k + 14], S43, 0xAB9423A7);
        b = II(b, c, d, a, x[k + 5], S44, 0xFC93A039);
        a = II(a, b, c, d, x[k + 12], S41, 0x655B59C3);
        d = II(d, a, b, c, x[k + 3], S42, 0x8F0CCC92);
        c = II(c, d, a, b, x[k + 10], S43, 0xFFEFF47D);
        b = II(b, c, d, a, x[k + 1], S44, 0x85845DD1);
        a = II(a, b, c, d, x[k + 8], S41, 0x6FA87E4F);
        d = II(d, a, b, c, x[k + 15], S42, 0xFE2CE6E0);
        c = II(c, d, a, b, x[k + 6], S43, 0xA3014314);
        b = II(b, c, d, a, x[k + 13], S44, 0x4E0811A1);
        a = II(a, b, c, d, x[k + 4], S41, 0xF7537E82);
        d = II(d, a, b, c, x[k + 11], S42, 0xBD3AF235);
        c = II(c, d, a, b, x[k + 2], S43, 0x2AD7D2BB);
        b = II(b, c, d, a, x[k + 9], S44, 0xEB86D391);
        a = addUnsigned(a, AA); b = addUnsigned(b, BB); c = addUnsigned(c, CC); d = addUnsigned(d, DD);
    }
    return (wordToHex(a) + wordToHex(b) + wordToHex(c) + wordToHex(d)).toLowerCase();
}

function copiedAt(timestamp) {
    if (typeof timestamp !== "number" || !isFinite(timestamp))
        return "Unknown";
    var date = new Date(timestamp);
    var days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    var pad = function(num) { return num < 10 ? "0" + num : "" + num; };
    return days[date.getDay()] + " " + months[date.getMonth()] + " " + pad(date.getDate()) + " "
        + pad(date.getHours()) + ":" + pad(date.getMinutes()) + ":" + pad(date.getSeconds()) + " "
        + date.getFullYear();
}

function relativeTime(timestamp, now) {
    if (typeof timestamp !== "number" || !isFinite(timestamp))
        return "";
    var current = typeof now === "number" && isFinite(now) ? now : Date.now();
    var deltaSeconds = Math.max(0, Math.floor((current - timestamp) / 1000));

    if (deltaSeconds < 60)
        return "just now";
    var minutes = Math.floor(deltaSeconds / 60);
    if (minutes === 1)
        return "1 minute ago";
    if (minutes < 60)
        return minutes + " minutes ago";
    var hours = Math.floor(minutes / 60);
    if (hours === 1)
        return "1 hour ago";
    if (hours < 24)
        return hours + " hours ago";
    var days = Math.floor(hours / 24);
    if (days === 1)
        return "1 day ago";
    return days + " days ago";
}

function sizeLabel(item) {
    if (!item) return "0 bytes";
    var bytes = 0;
    if (typeof item.bytes === "number" && isFinite(item.bytes) && item.bytes > 0) {
        bytes = item.bytes;
    } else if (typeof item.text === "string") {
        try {
            bytes = encodeURIComponent(item.text).replace(/%[A-F\d]{2}/g, "U").length;
        } catch (e) {
            bytes = item.text.length;
        }
    } else if (typeof item.chars === "number") {
        bytes = item.chars;
    }
    if (bytes < 1024)
        return bytes + " " + (bytes === 1 ? "byte" : "bytes");
    if (bytes < 1024 * 1024)
        return (bytes / 1024).toFixed(1) + " KB";
    return (bytes / (1024 * 1024)).toFixed(1) + " MB";
}

function typeLabel(item) {
    if (!item) return "Text";
    if (item.kind === "image") return "Image";
    return "Text";
}

function label(key) {
    var map = {
        type: "Type",
        size: "Size",
        copied_at: "Copied at",
        md5: "MD5",
        source: "Source",
        path: "Path"
    };
    return map[key] || key;
}

function sourceName(item) {
    if (!item) return "Clipboard";
    var app = (item.sourceApp || "").trim().toLowerCase();
    var title = (item.sourceTitle || "").trim().toLowerCase();

    if (title.indexOf("chatgpt") >= 0 || app.indexOf("chatgpt") >= 0)
        return "ChatGPT";
    if (title.indexOf("claude") >= 0 || app.indexOf("claude") >= 0)
        return "Claude";
    if (title.indexOf("gemini") >= 0 || app.indexOf("gemini") >= 0)
        return "Gemini";
    if (title.indexOf("copilot") >= 0 || app.indexOf("copilot") >= 0)
        return "Copilot";
    if (title.indexOf("deepseek") >= 0 || app.indexOf("deepseek") >= 0)
        return "DeepSeek";

    if (app.indexOf("antigravity") >= 0 || title.indexOf("antigravity") >= 0)
        return "Antigravity";

    if (app === "kitty") return "Kitty";
    if (app === "alacritty") return "Alacritty";
    if (/foot|wezterm|konsole|terminal|xterm/.test(app))
        return "Terminal";

    if (/code|cursor/.test(app))
        return "VS Code";
    if (/nvim|vim/.test(app))
        return "Neovim";

    if (/firefox|chrome|chromium|brave|edge|zen|vivaldi|opera/.test(app)) {
        if (title.indexOf("github") >= 0) return "GitHub";
        if (title.indexOf("gitlab") >= 0) return "GitLab";
        if (title.indexOf("youtube") >= 0) return "YouTube";
        if (title.indexOf("stackoverflow") >= 0) return "StackOverflow";
        if (item.sourceTitle) {
            var cleanTitle = item.sourceTitle.replace(/\s*[-—–]\s*(Mozilla Firefox|Firefox|Google Chrome|Chromium|Brave|Microsoft Edge|Zen Browser).*$/i, "").trim();
            if (cleanTitle) return cleanTitle;
        }
        return "Web";
    }

    if (item.sourceApp) {
        var rawApp = item.sourceApp.trim();
        return rawApp.charAt(0).toUpperCase() + rawApp.slice(1);
    }
    if (item.kind === "image")
        return "Screenshot";
    if (item.kind === "url")
        return "Web";
    if (item.kind === "code")
        return "Editor";
    if (typeof item.text === "string") {
        if (/\b(cd|git|ls|sudo|pacman|cargo|node|python|ssh)\b/.test(item.text)
                || /^[A-Za-z0-9_.-]+~/.test(item.text))
            return "Terminal";
    }
    return "Clipboard";
}

function sourceIcon(item) {
    if (!item) return "content_paste";
    var app = (item.sourceApp || "").toLowerCase();
    var title = (item.sourceTitle || "").toLowerCase();

    if (title.indexOf("chatgpt") >= 0 || app.indexOf("chatgpt") >= 0
            || title.indexOf("claude") >= 0 || title.indexOf("gemini") >= 0
            || title.indexOf("copilot") >= 0 || title.indexOf("deepseek") >= 0)
        return "chat_bubble";

    if (app.indexOf("antigravity") >= 0 || title.indexOf("antigravity") >= 0)
        return "rocket_launch";

    if (/kitty|alacritty|foot|wezterm|konsole|terminal|xterm/.test(app))
        return "terminal";

    if (/code|nvim|vim|emacs|sublime|cursor/.test(app))
        return "code";

    if (/discord|slack|telegram/.test(app))
        return "forum";

    if (/firefox|chrome|chromium|brave|edge|zen|vivaldi|opera/.test(app)) {
        if (title.indexOf("github") >= 0 || title.indexOf("gitlab") >= 0)
            return "code";
        if (title.indexOf("discord") >= 0 || title.indexOf("slack") >= 0 || title.indexOf("telegram") >= 0)
            return "forum";
        return "language";
    }

    if (item.kind === "image")
        return "image";
    if (item.kind === "url")
        return "link";
    if (item.kind === "code")
        return "code";
    if (typeof item.text === "string") {
        if (/\b(cd|git|ls|sudo|pacman|cargo|node|python|ssh)\b/.test(item.text)
                || /^[A-Za-z0-9_.-]+~/.test(item.text))
            return "terminal";
    }
    return "content_paste";
}

function itemPath(item) {
    if (!item) return "";
    if (item.kind === "image" && item.imagePath)
        return item.imagePath;
    if (typeof item.text !== "string")
        return "";
    var trimmed = item.text.trim();
    var urlMatch = trimmed.match(/^https?:\/\/[^\s]+/);
    if (urlMatch) return urlMatch[0];
    var gitMatch = trimmed.match(/^git@[^\s]+/);
    if (gitMatch) return gitMatch[0];
    var directPath = trimmed.match(/^(?:\/|~\/|\.\/)[^\s]*/);
    if (directPath) return directPath[0];
    var cdMatch = trimmed.match(/\bcd\s+([^\s]+)/);
    if (cdMatch) return cdMatch[1];
    return "";
}

function itemIcon(item) {
    if (!item) return "title";
    if (item.kind === "image") return "image";
    if (item.kind === "color") return "palette";

    var sIcon = sourceIcon(item);
    if (sIcon !== "content_paste") return sIcon;
    if (item.kind === "url") return "link";
    if (item.kind === "code") return "code";
    return "title";
}

function appIconSource(item) {
    if (!item) return "";
    if (item.kind === "image" || item.kind === "color") return "";

    var app = (item.sourceApp || "").trim().toLowerCase();
    var title = (item.sourceTitle || "").trim().toLowerCase();

    if (title.indexOf("chatgpt") >= 0 || app.indexOf("chatgpt") >= 0) {
        return "/usr/share/pixmaps/chatgpt.png";
    }

    if (app.indexOf("antigravity") >= 0 || title.indexOf("antigravity") >= 0) {
        return "/usr/share/pixmaps/antigravity-ide.png";
    }

    if (app === "google-chrome" || app === "chrome") return "google-chrome";
    if (app === "firefox") return "firefox";
    if (app === "kitty") return "kitty";
    if (app === "alacritty") return "alacritty";
    if (/code|cursor/.test(app)) return "code";

    if (item.sourceApp) return item.sourceApp;
    return "";
}
