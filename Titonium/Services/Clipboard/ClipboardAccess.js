.pragma library

function unavailable(error) {
    return { available: false, error: "clipboard.error.unavailable", detail: String(error) };
}

function observe(readText) {
    try {
        const value = readText();
        return { available: true, error: "", detail: "",
            text: typeof value === "string" ? value : "" };
    } catch (error) {
        const failure = unavailable(error);
        failure.text = "";
        return failure;
    }
}

function copy(text, writeText) {
    try {
        writeText(text);
        return { accepted: true, available: true, error: "", detail: "" };
    } catch (error) {
        const failure = unavailable(error);
        failure.accepted = false;
        return failure;
    }
}
